{ pkgs, ... }:

let
  nvw = pkgs.rustPlatform.buildRustPackage {
    pname = "nvw";
    version = "0.1.0";

    src = ../../packages/nvw;
    cargoLock.lockFile = ../../packages/nvw/Cargo.lock;

    nativeBuildInputs = [
      pkgs.makeWrapper
    ];

    postInstall = ''
      wrapProgram "$out/bin/nvw" \
        --prefix PATH : ${
          pkgs.lib.makeBinPath [
            pkgs.bash
            pkgs.git
            pkgs.neovim
          ]
        }
    '';
  };
in
{
  xdg.configFile."nvim/lua/dotfiles".source = ./neovim/lua/dotfiles;

  home.packages =
    (with pkgs; [
      bash-language-server
      bat
      claude-code
      codex
      eslint_d
      fd
      fzf
      gh
      git
      lazygit
      lua-language-server
      marksman
      nixd
      nixfmt
      prettierd
      prisma
      prisma-engines
      ripgrep
      shellcheck
      shfmt
      stylua
      tailwindcss-language-server
      typescript-language-server
      volta
      vscode-langservers-extracted
    ])
    ++ [
      nvw
    ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;

    plugins = with pkgs.vimPlugins; [
      blink-cmp
      claudecode-nvim
      conform-nvim
      gitsigns-nvim
      lualine-nvim
      markview-nvim
      nvim-web-devicons
      snacks-nvim
      todo-comments-nvim
      trouble-nvim
      which-key-nvim
      nvim-lspconfig
      (nvim-treesitter.withPlugins (
        parsers: with parsers; [
          bash
          css
          html
          javascript
          json
          lua
          markdown
          markdown_inline
          nix
          toml
          tsx
          typescript
          vim
          vimdoc
          yaml
        ]
      ))
    ];

    initLua = builtins.readFile ./neovim/init.lua;
  };
}
