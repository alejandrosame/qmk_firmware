{
  description = "QMK firmware dirty flake expression";

  # Consume inputs from Niv and make them compatible with outputs args usage.
  inputs = let
    packageSources = import ./sources.nix {};
  in {
    flake-utils = import packageSources.flake-utils.outPath;
    nixpkgs = packageSources.nixpkgs.outPath;
    poetry2nix = import packageSources.poetry2nix.outPath;
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    poetry2nix,
    ...
  }:
    {
      pythonOverlay = import ./python-overlay.nix;
    }
    // flake-utils.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          overlays = [self.pythonOverlay];
          inherit system;
        };
      in {
        devShells.default = pkgs.callPackage ../../shell.nix {inherit pkgs poetry2nix;};
      }
    );
}
