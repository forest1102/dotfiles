{ pkgs, ... }:

let
  nvimWorktree = pkgs.writeShellApplication {
    name = "nvim-worktree";
    runtimeInputs = with pkgs; [
      coreutils
      git
      neovim
    ];
    text = ''
      if [ "$#" -lt 1 ]; then
        echo "Usage: nvim-worktree <branch> [base-ref]" >&2
        exit 2
      fi

      branch="$1"
      if [ "$#" -ge 2 ]; then
        base="$2"
      else
        base="HEAD"
      fi

      root=$(git rev-parse --show-toplevel 2>/dev/null) || {
        echo "nvim-worktree: not inside a git repository" >&2
        exit 1
      }

      safe_name=$(printf '%s' "$branch" | tr '/[:space:]' '-' | tr -c 'A-Za-z0-9._-' '-' | tr -s '-')
      worktree_dir="$root/.worktree"
      worktree_path="$worktree_dir/$safe_name"

      mkdir -p "$worktree_dir"

      if [ -e "$worktree_path" ]; then
        exec nvim "$worktree_path"
      fi

      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$worktree_path" "$branch"
      else
        git worktree add -b "$branch" "$worktree_path" "$base"
      fi

      exec nvim "$worktree_path"
    '';
  };

  nvw = pkgs.writeShellApplication {
    name = "nvw";
    runtimeInputs = [
      nvimWorktree
    ];
    text = ''
      exec nvim-worktree "$@"
    '';
  };
in
{
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
      nvimWorktree
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
