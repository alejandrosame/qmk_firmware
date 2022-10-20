# This Flake provides a dev environment to develop QMK configurations.
#
# Builds the python env based on nix/pyproject.toml and
# nix/poetry.lock Use the "poetry update --lock", "poetry add  --lock"
# etc. in the nix folder to adjust the contents of those
# files if the requirements*.txt files change
#
# Avoid using overlays as much as possible.
# Following advice from: https://zimbatm.com/notes/1000-instances-of-nixpkgs.
{
  description = "QMK firmware";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils/f7e004a55b120c02ecb6219596820fcd32ca8772";
    };

    nixpkgs = {
      url = "github:NixOS/nixpkgs/c0e881852006b132236cbf0301bd1939bb50867e";
    };

    poetry2nixFlake = {
      url = "github:nix-community/poetry2nix/11c0df8e348c0f169cd73a2e3d63f65c92baf666";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    poetry2nixFlake,
    pre-commit-hooks,
  }:
  # flake-utils.lib.eachDefaultSystem) # TODO: Filter properly
    (flake-utils.lib.eachSystem [
      "aarch64-linux"
      #"aarch64-darwin"
      #"i686-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ])
    (system: let
      # Define some extra utility variables
      nixpkgsLegacy = nixpkgs.legacyPackages.${system};
      pkgsCross = nixpkgs.legacyPackages.${system}.pkgsCross;
      lib = nixpkgs.legacyPackages.${system}.lib;
      poetry2nix = nixpkgsLegacy.callPackage poetry2nixFlake {}; # Why I cannot use poetry2nixFlake directly?

      # `tomlkit` >= 0.8.0 is required to build `jsonschema` >= 4.11.0 (older
      # version do not support some valid TOML syntax: sdispater/tomlkit#148).  The
      # updated `tomlkit` must be used by `makeRemoveSpecialDependenciesHook`
      # inside `poetry2nix`, therefore just providing the updated version through
      # our `nix/pyproject.toml` does not work, and we need to pass the overriden python
      # to mkPoetryEnv.
      python3 = nixpkgsLegacy.python3.override {
        packageOverrides = python-self: python-super: {
          tomlkit = python-super.tomlkit.overridePythonAttrs (old: let
            version = "0.11.4";
          in {
            src = python-super.fetchPypi {
              inherit (old) pname;
              inherit version;
              sha256 = "sha256-MjWpAQ+uVDI+cnw6wG+3IHUv5mNbNCbjedrsYPvUSoM=";
            };
          });
        };
      };

      avr = true;
      arm = true;
      teensy = true;

      avrlibc = pkgsCross.avr.libcCross;

      avr_incflags = [
        "-isystem ${avrlibc}/avr/include"
        "-B${avrlibc}/avr/lib/avr5"
        "-L${avrlibc}/avr/lib/avr5"
        "-B${avrlibc}/avr/lib/avr35"
        "-L${avrlibc}/avr/lib/avr35"
        "-B${avrlibc}/avr/lib/avr51"
        "-L${avrlibc}/avr/lib/avr51"
      ];

      pythonEnv = poetry2nix.mkPoetryEnv {
        projectDir = ./util/nix;
        #python = python3;
        overrides = poetry2nix.overrides.withDefaults (self: super: {
          pillow = super.pillow.overridePythonAttrs (old: {
            # Use preConfigure from nixpkgs to fix library detection issues and
            # impurities which can break the build process; this also requires
            # adding propagatedBuildInputs and buildInputs from the same source.
            propagatedBuildInputs = (old.buildInputs or []) ++ python3.pkgs.pillow.propagatedBuildInputs;
            buildInputs = (old.buildInputs or []) ++ python3.pkgs.pillow.buildInputs;
            preConfigure = old.preConfigure or "" + python3.pkgs.pillow.preConfigure;
          });
          qmk = super.qmk.overridePythonAttrs (old: {
            # Allow QMK CLI to run "qmk" as a subprocess (the wrapper changes
            # $PATH and breaks these invocations).
            dontWrapPythonPrograms = true;
          });
        });
      };

      self.checks.${system} = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
          };
        };
      };
    in {
      devShells.default = nixpkgsLegacy.mkShell {
        inherit (self.checks.${system}.pre-commit-check);

        buildInputs = with nixpkgsLegacy;
          [clang-tools dfu-programmer dfu-util diffutils git niv]
          #++ [pythonEnv]
          ++ lib.optional avr [
            pkgsCross.avr.buildPackages.binutils
            pkgsCross.avr.buildPackages.gcc8
            avrlibc
            nixpkgsLegacy.avrdude
          ]
          ++ lib.optional arm [nixpkgsLegacy.gcc-arm-embedded]
          ++ lib.optional teensy [nixpkgsLegacy.teensy-loader-cli];

        AVR_CFLAGS = lib.optional avr avr_incflags;
        AVR_ASFLAGS = lib.optional avr avr_incflags;

        shellHook =
          # self.shellHook # How to reference to inherit shellHook and update it
          ''
            # Prevent the avr-gcc wrapper from picking up host GCC flags
            # like -iframework, which is problematic on Darwin
            unset NIX_CFLAGS_COMPILE_FOR_TARGET
          '';
      };
    });
}
