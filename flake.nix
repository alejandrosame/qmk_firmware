{
  description = "QMK firmware";

  inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    pre-commit-hooks,
  }:
    flake-utils.lib.eachDefaultSystem
    (system: let
      # We specify sources via Niv: use "niv update nixpkgs" to update nixpkgs, for example.
      sources = import ./util/nix/sources.nix {};

      pkgs = let
        # `tomlkit` >= 0.8.0 is required to build `jsonschema` >= 4.11.0 (older
        # version do not support some valid TOML syntax: sdispater/tomlkit#148).  The
        # updated `tomlkit` must be used by `makeRemoveSpecialDependenciesHook`
        # inside `poetry2nix`, therefore just providing the updated version through
        # our `nix/pyproject.toml` does not work, and using an overlay is required.
        pythonOverlay = final: prev: {
          python3 = prev.python3.override {
            packageOverrides = self: super: {
              tomlkit = super.tomlkit.overridePythonAttrs (old: let
                version = "0.11.4";
              in {
                src = super.fetchPypi {
                  inherit (old) pname;
                  inherit version;
                  sha256 = "sha256-MjWpAQ+uVDI+cnw6wG+3IHUv5mNbNCbjedrsYPvUSoM=";
                };
              });
            };
          };
        };
      in
        import nixpkgs {
          inherit system;
          overlays = [pythonOverlay];
          legacyPackages = nixpkgs.legacyPackages;
        };
      # TODO: figure out why pkgs.legacyPackages doesn't exist but using nixpgs.legacyPackages works

      # Define some extra utility variables
      pkgsCross = nixpkgs.legacyPackages.${system}.pkgsCross;
      lib = nixpkgs.legacyPackages.${system}.lib;

      poetry2nix = pkgs.callPackage (import sources.poetry2nix) {};

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

      # Builds the python env based on nix/pyproject.toml and
      # nix/poetry.lock Use the "poetry update --lock", "poetry add
      # --lock" etc. in the nix folder to adjust the contents of those
      # files if the requirements*.txt files change
      pythonEnv = poetry2nix.mkPoetryEnv {
        projectDir = ./util/nix;
        overrides = poetry2nix.overrides.withDefaults (self: super: {
          pillow = super.pillow.overridePythonAttrs (old: {
            # Use preConfigure from nixpkgs to fix library detection issues and
            # impurities which can break the build process; this also requires
            # adding propagatedBuildInputs and buildInputs from the same source.
            propagatedBuildInputs = (old.buildInputs or []) ++ pkgs.python3.pkgs.pillow.propagatedBuildInputs;
            buildInputs = (old.buildInputs or []) ++ pkgs.python3.pkgs.pillow.buildInputs;
            preConfigure = (old.preConfigure or "") + pkgs.python3.pkgs.pillow.preConfigure;
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
      # We only use this Flake to provide a dev environment to develop QMK configurations
      devShells.default = pkgs.mkShell {
        inherit (self.checks.${system}.pre-commit-check); # shellHook; # TODO: figure out how to reintroduce this variable

        buildInputs = with pkgs;
          [clang-tools dfu-programmer dfu-util diffutils git niv]
          ++ [pythonEnv]
          ++ lib.optional avr [
            pkgsCross.avr.buildPackages.binutils
            pkgsCross.avr.buildPackages.gcc8
            avrlibc
            pkgs.avrdude
          ]
          ++ lib.optional arm [pkgs.gcc-arm-embedded]
          ++ lib.optional teensy [pkgs.teensy-loader-cli];

        AVR_CFLAGS = lib.optional avr avr_incflags;
        AVR_ASFLAGS = lib.optional avr avr_incflags;

        shellHook = ''
          # Prevent the avr-gcc wrapper from picking up host GCC flags
          # like -iframework, which is problematic on Darwin
          unset NIX_CFLAGS_COMPILE_FOR_TARGET
        '';
      };
    });
}
