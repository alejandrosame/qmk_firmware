{
  description = "QMK firmware";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c0e881852006b132236cbf0301bd1939bb50867e";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
  # flake-utils.lib.eachDefaultSystem # TODO: Make explicit filtering
    flake-utils.lib.eachSystem [
      "aarch64-linux"
      #"aarch64-darwin"
      #"i686-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ]
    (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.${system}.default = pkgs.callPackage ./shell.nix {inherit pkgs;};
      }
    );
}
