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

      git rev-parse --show-toplevel >/dev/null 2>&1 || {
        echo "nvim-worktree: not inside a git repository" >&2
        exit 1
      }

      git_common_dir=$(git rev-parse --path-format=absolute --git-common-dir)
      main_root=$(dirname "$git_common_dir")
      safe_name=$(printf '%s' "$branch" | tr '/[:space:]' '-' | tr -c 'A-Za-z0-9._-' '-' | tr -s '-')
      worktree_dir="$main_root/.worktree"
      worktree_path="$worktree_dir/$safe_name"
      init_script="$worktree_dir/init.sh"

      mkdir -p "$worktree_dir"

      if [ -e "$worktree_path" ]; then
        exec nvim "$worktree_path"
      fi

      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$worktree_path" "$branch"
      else
        git worktree add -b "$branch" "$worktree_path" "$base"
      fi

      if [ -f "$init_script" ]; then
        (
          cd "$worktree_path"
          export WORKTREE_MAIN_ROOT="$main_root"
          export WORKTREE_PATH="$worktree_path"
          export WORKTREE_BRANCH="$branch"
          export WORKTREE_BASE="$base"
          sh "$init_script"
        ) || {
          status=$?
          echo "nvim-worktree: warning: .worktree/init.sh failed with exit status $status" >&2
        }
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
