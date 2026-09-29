{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;

    settings = {
      font-family = "FiraCode Nerd Font";
      font-size = 12;
    };
  };
}
