{ pkgs, ... }:

{
  imports = [
    ./neovim.nix
  ];

  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    claude-code
  ];
}
