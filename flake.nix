{
  description = "QMK dependencies and dev shell";

  inputs.pre-commit-hooks = {
    url = "github:cachix/pre-commit-hooks.nix";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    pre-commit-hooks,
  }:
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {inherit system;};

      # We specify sources via Niv: use "niv update nixpkgs" to update nixpkgs, for example.
      sources = import ./util/nix/sources.nix {};

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

      self.checks.${system} = {
        pre-commit-check = pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            alejandra.enable = true;
          };
        };
      };
    in {
      packages = flake-utils.lib.flattenTree {
        hello = pkgs.hello;
      };

      devShells.default = pkgs.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
      };
    });
}
