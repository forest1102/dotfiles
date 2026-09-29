{ pkgs, ... }:

{
  imports = [
    ./ai-agents.nix
    ./ghostty.nix
    ./neovim.nix
    ./terminal-browser.nix
    ./tmux.nix
  ];

  home.stateVersion = "26.05";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
  home.packages = [
    pkgs.google-cloud-sdk
    pkgs.herdr
    pkgs.python3
  ];

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    initContent = ''
      if [[ -o interactive ]]; then
        export PROTO_HOME="''${PROTO_HOME:-$HOME/.proto}"
        path=("$PROTO_HOME/shims" "$PROTO_HOME/bin" ''${path:#$PROTO_HOME/(shims|bin)})

        typeset -g __last_dir_file="''${XDG_STATE_HOME:-$HOME/.local/state}/zsh/last-dir"

        __save_last_dir() {
          mkdir -p "''${__last_dir_file:h}"
          print -r -- "$PWD" >| "$__last_dir_file"
        }

        autoload -Uz add-zsh-hook
        add-zsh-hook chpwd __save_last_dir
        add-zsh-hook zshexit __save_last_dir

        if [[ "$PWD" == "$HOME" && -r "$__last_dir_file" ]]; then
          __last_dir="$(<"$__last_dir_file")"
          if [[ -n "$__last_dir" && -d "$__last_dir" ]]; then
            cd "$__last_dir"
          fi
          unset __last_dir
        fi

        __save_last_dir
      fi
    '';
  };
}
