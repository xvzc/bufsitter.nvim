{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  packages = with pkgs; [
    stylua
    lua-language-server
    lua
    lemmy-help
  ];
  shellHook = # sh
    ''
      export name="nix:promdown.nvim"
      export NVIM_APPNAME="nvim"
    '';
}
