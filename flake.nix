{
  description = "My macOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      env = import ./lib/env.nix;
      outputHelpers = import ./lib/outputs.nix { lib = nixpkgs.lib; };

      resolvedHostname =
        let
          value = env.envFirstOrNull [
            "HOSTNAME"
            "HOST"
          ];
        in
        if value == null then "default" else value;
      resolvedUsername = env.envFirstOrThrow [
        "SUDO_USER"
        "USER"
        "LOGNAME"
      ];
      targetSystem =
        let
          value = builtins.getEnv "SYSTEM";
        in
        if value != "" then
          value
        else if builtins ? currentSystem then
          builtins.currentSystem
        else
          "aarch64-darwin";
      userHomeDirectory = "/Users/${resolvedUsername}";
      sharedNixpkgsConfig = {
        allowUnfreePredicate =
          pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [
            "claude-code"
          ];
      };
      pkgs = import nixpkgs {
        system = targetSystem;
        config = sharedNixpkgsConfig;
      };
      formatter = pkgs.writeShellApplication {
        name = "dotfiles-nixfmt";
        runtimeInputs = [
          pkgs.findutils
          pkgs.nixfmt
        ];
        text = ''
          find . -name '*.nix' -not -path './.git/*' -print0 | xargs -0 nixfmt
        '';
      };
      homeConfiguration = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          {
            home = {
              username = resolvedUsername;
              homeDirectory = userHomeDirectory;
            };
          }
          ./modules/home
        ];
      };
      darwinConfiguration = nix-darwin.lib.darwinSystem {
        system = targetSystem;

        specialArgs = {
          username = resolvedUsername;
        };

        modules = [
          ./modules/darwin
          home-manager.darwinModules.home-manager

          {
            nixpkgs.config = sharedNixpkgsConfig;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";

            home-manager.users.${resolvedUsername} = import ./modules/home;
          }
        ];
      };
    in
    {
      darwinConfigurations = outputHelpers.withDefaultAlias resolvedHostname darwinConfiguration;
      formatter.${targetSystem} = formatter;
      homeConfigurations = outputHelpers.withDefaultAlias resolvedUsername homeConfiguration;
    };
}
