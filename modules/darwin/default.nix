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
  ];

  system.stateVersion = 6;
}
