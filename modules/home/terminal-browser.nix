{ pkgs, ... }:

let
  version = "0.11.1";

  # 公式インストーラ（https://terminal-browser.sh/install）と同じリリース tarball を使う
  sources = {
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha256-myFynke8wH6WmRMiNwXOGuW8qo5JCU1slwXEzKgxHZA=";
    };
    x86_64-darwin = {
      target = "darwin-x64";
      hash = "sha256-lFSxRnQCBJ4NCNB6aet2tn6U88TGDKK4qt9BWMGTwPQ=";
    };
  };

  source =
    sources.${pkgs.stdenv.hostPlatform.system}
      or (throw "terminal-browser: unsupported system ${pkgs.stdenv.hostPlatform.system}");

  terminal-browser = pkgs.stdenvNoCC.mkDerivation {
    pname = "terminal-browser";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/zenbu-labs/terminal-browser/releases/download/v${version}/terminal-browser-${source.target}.tar.gz";
      inherit (source) hash;
    };

    # 同梱の Electron.app は署名済みなので、fixup で中身を書き換えない
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      # tarball に含まれる AppleDouble（._*）は GNU tar だと実ファイルとして展開され、
      # .app の封印が壊れて macOS に kill されるため取り除く
      find . -name '._*' -delete

      mkdir -p "$out/share/terminal-browser" "$out/bin"
      cp -R . "$out/share/terminal-browser"
      # bin/terminal-browser はシンボリックリンクを辿って配布ルートを解決する
      ln -s "$out/share/terminal-browser/bin/terminal-browser" "$out/bin/terminal-browser"

      runHook postInstall
    '';

    meta = {
      description = "A browser inside your terminal";
      homepage = "https://github.com/zenbu-labs/terminal-browser";
      mainProgram = "terminal-browser";
      platforms = builtins.attrNames sources;
    };
  };
in
{
  home.packages = [ terminal-browser ];
}
