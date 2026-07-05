{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshDirectory = "${config.home.homeDirectory}/.ssh";
  privateKey = "${sshDirectory}/id_ed25519";
  publicKey = "${privateKey}.pub";
in
{
  home.activation.generateInitialSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ssh_dir=${lib.escapeShellArg sshDirectory}
    private_key=${lib.escapeShellArg privateKey}
    public_key=${lib.escapeShellArg publicKey}
    public_key_tmp="$public_key.tmp"

    ${pkgs.coreutils}/bin/mkdir -p "$ssh_dir"
    ${pkgs.coreutils}/bin/chmod 700 "$ssh_dir"

    if [ ! -e "$private_key" ]; then
      ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -C "github" -f "$private_key"
    fi

    if [ -f "$private_key" ]; then
      ${pkgs.coreutils}/bin/chmod 600 "$private_key"

      if [ ! -e "$public_key" ]; then
        if SSH_ASKPASS=/bin/false SSH_ASKPASS_REQUIRE=never \
          ${pkgs.openssh}/bin/ssh-keygen -y -f "$private_key" < /dev/null > "$public_key_tmp"; then
          ${pkgs.coreutils}/bin/mv "$public_key_tmp" "$public_key"
        else
          ${pkgs.coreutils}/bin/rm -f "$public_key_tmp"
          echo "Could not derive $public_key from $private_key. If the key has a passphrase, create the public key manually with: ssh-keygen -y -f $private_key > $public_key"
        fi
      fi
    fi

    if [ -f "$public_key" ]; then
      ${pkgs.coreutils}/bin/chmod 644 "$public_key"
      echo "GitHub SSH public key ($public_key):"
      ${pkgs.coreutils}/bin/cat "$public_key"
    fi
  '';

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = privateKey;
      IdentitiesOnly = true;
    };
  };
}
