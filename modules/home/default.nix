{ ... }:

{
  imports = [
    ./neovim.nix
  ];

  home.stateVersion = "26.05";
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    initContent = ''
      if [[ -o interactive ]]; then
        export VOLTA_HOME="''${VOLTA_HOME:-$HOME/.volta}"
        path=("$VOLTA_HOME/bin" ''${path:#$VOLTA_HOME/bin})

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
