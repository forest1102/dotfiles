# dotfiles

macOS 用の Nix / nix-darwin / Home Manager 設定です。

この flake は `USER` / `SUDO_USER` / `HOSTNAME` / `SYSTEM` を評価時に参照するため、コマンドには `--impure` を付けます。flake 出力は基本的に `.#default` を使います。

## Nix のインストール

macOS では公式の multi-user installer を使います。

```sh
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | sh
```

インストール後はターミナルを開き直して、Nix が使えることを確認します。

```sh
nix --version
```

## 初回セットアップ

`darwin-rebuild` がまだ PATH にない場合は、`nix run` で nix-darwin を実行して初回適用します。

```sh
sudo nix --extra-experimental-features "nix-command flakes" run github:nix-darwin/nix-darwin/master#darwin-rebuild -- switch --flake .#default --impure
```

## 設定の反映

macOS 全体の設定と Home Manager の設定をまとめて反映します。

```sh
sudo darwin-rebuild switch --flake .#default --impure
```

反映前にビルドだけ確認する場合は次を使います。

```sh
darwin-rebuild build --flake .#default --impure
```

Home Manager だけを反映したい場合は次を使います。

```sh
home-manager switch --flake .#default --impure
```

## Nix の基本操作

flake の出力を確認します。

```sh
nix flake show --impure
```

依存関係を更新します。

```sh
nix flake update
```

Nix ファイルを整形します。

```sh
nix fmt
```

## フォント設定

フォントは `modules/darwin/default.nix` の `fonts.packages` で管理します。現在は FiraCode Nerd Font を入れています。

```nix
fonts.packages = with pkgs; [
  nerd-fonts.fira-code
];
```

フォントを追加したい場合は、このリストに package を追加してから `darwin-rebuild switch` を実行します。

Nix でフォントをインストールした後、実際に使うフォントは各アプリ側で選びます。macOS 標準機能ではシステム UI 全体のフォント変更は扱いません。

```text
Terminal.app:
設定 > プロファイル > テキスト > フォント > 変更 > FiraCode Nerd Font

iTerm2:
Settings > Profiles > Text > Font > FiraCode Nerd Font

VS Code:
Settings > Editor: Font Family に 'FiraCode Nerd Font' を追加
```

## 参考

- [Nix download](https://nixos.org/download/)
- [nix-darwin README](https://github.com/nix-darwin/nix-darwin)
