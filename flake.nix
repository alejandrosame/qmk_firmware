{
  description = "QMK firmware";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c0e881852006b132236cbf0301bd1939bb50867e";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    {
      # We specify sources via Niv: use "niv update nixpkgs" to update nixpkgs, for example.
      sources = import ./util/nix/sources.nix {};

      pythonOverlay = import ./util/nix/python-overlay.nix;
    }
    // flake-utils.lib.eachSystem ["x86_64-linux"] (
      system: let
        pkgs = import nixpkgs {
          overlays = [self.pythonOverlay];
          inherit system;
        };

        poetry2nix = pkgs.callPackage (import self.sources.poetry2nix) {};
      in {
        devShells.default = pkgs.callPackage ./shell.nix {inherit pkgs poetry2nix;};
      }
    );
}
