{
  description = "QMK firmware";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c0e881852006b132236cbf0301bd1939bb50867e";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    devShells.${system}.default = pkgs.callPackage ./shell.nix {inherit pkgs;};
  };
}
