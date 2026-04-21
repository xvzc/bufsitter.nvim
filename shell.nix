{
  pkgs ? import <nixpkgs> { },
}:
let
  unstableTarball = builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz";
  unstablePkgs = import unstableTarball { };
in
pkgs.mkShell {
  packages = with pkgs; [
    stylua
    lua-language-server
    lua
    lemmy-help
    unstablePkgs.commitlint
  ];
  shellHook = # sh
    ''
      export name="nix:promdown.nvim"
      export NVIM_APPNAME="nvim"
    '';
}
