{
  config,
  pkgs,
  username,
  ...
}:

let
  homeDirectory = "/Users/${username}";
in
{
  users.users.${username} = {
    home = homeDirectory;
  };

  system.primaryUser = username;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  environment.systemPackages = with pkgs; [
    git
    home-manager
  ];

  homebrew = {
    enable = true;
    casks = [ "docker-desktop" ];
  };

  environment.systemPath = [ "${config.homebrew.prefix}/bin" ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
  ];

  system.stateVersion = 6;
}
