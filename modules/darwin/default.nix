{ pkgs, username, ... }:

let
  homeDirectory = "/Users/${username}";
in
{
  users.users.${username} = {
    home = homeDirectory;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    home-manager
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  system.stateVersion = 6;
}
