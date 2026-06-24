{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [
      lazy-nvim
    ];
  };
}
