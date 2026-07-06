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
      cat > "$out/bin/nvw-rplugin" <<EOF
      #!${pkgs.bash}/bin/bash
      export NVW_RPLUGIN=1
      exec "$out/bin/nvw" "\$@"
      EOF
      chmod +x "$out/bin/nvw-rplugin"
    '';
  };
  nvwPluginSource = pkgs.runCommand "nvw-neovim-plugin-source" { } ''
    mkdir -p "$out/plugin"
    cat > "$out/plugin/nvw.vim" <<'EOF'
    if exists('g:loaded_nvw_rplugin')
      finish
    endif
    let g:loaded_nvw_rplugin = 1

    let s:nvw_rplugin = '${nvw}/bin/nvw-rplugin'

    function! s:NvwRequire(host_info) abort
      return jobstart([s:nvw_rplugin], {'rpc': v:true})
    endfunction

    call remote#host#Register('nvw', '*', function('s:NvwRequire'))
    call remote#host#RegisterPlugin('nvw', s:nvw_rplugin, [
          \ {'type': 'function', 'name': 'NvwEnsure', 'sync': 1, 'opts': {}},
          \ ])
    EOF
  '';
  nvwNeovimPlugin = pkgs.vimUtils.buildVimPlugin {
    pname = "nvw-rplugin";
    version = "0.1.0";
    src = nvwPluginSource;
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
      nvwNeovimPlugin
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
