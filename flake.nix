{
  description = "QMK firmware";

  # Input dependencies are loaded on the dirty flake side via Niv.
  outputs = {self}: let
    dirtyFlake = import ./util/nix/dirty-flake.nix;
    dirtyFlakeInputs = dirtyFlake.inputs // {inherit self;};
  in
    dirtyFlake.outputs dirtyFlakeInputs;
}
