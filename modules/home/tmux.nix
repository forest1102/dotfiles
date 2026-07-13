{ ... }:

{
  programs.tmux = {
    enable = true;
    mouse = true;

    extraConfig = ''
      set -g status 2
      set -g status-position top
      set -g status-style "fg=default,bg=default"
      set -g status-right ' %Y-%m-%d %H:%M '

      setw -g window-status-format ' #I:#W '
      setw -g window-status-current-format ' #I:#W '
      setw -g window-status-style default
      setw -g window-status-current-style 'reverse,bold'
      set -g window-status-separator ""

      set -g 'status-format[0]' '#[align=left]#{S/n:#[range=session|#{session_id}]#{?#{==:#{session_name},#{client_session}},#[reverse]#[bold],#[default]} #{session_name} #[default]#[norange]}#[align=right]#{T:status-right}'
      set -g 'status-format[1]' '#[align=left list=on]#[list=left-marker]<#[list=right-marker]>#[list=on]#{W:#[range=window|#{window_index} #{E:window-status-style}]#{T:window-status-format}#[norange],#[range=window|#{window_index} list=focus #{E:window-status-current-style}]#{T:window-status-current-format}#[norange]}#[nolist]'
    '';
  };
}
