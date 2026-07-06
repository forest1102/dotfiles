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

## Claude / Codex 設定

Claude と Codex の移植可能な個人設定は Home Manager で管理します。

- 共通メモリ: `modules/home/ai-agents/shared-memory.md`
- Codex: `~/.codex/config.toml` と `~/.codex/AGENTS.md`
- Claude: `~/.claude/settings.json` と `~/.claude/CLAUDE.md`

共有するのはモデル、権限、プラグイン有効化、共通指示などの再生成できる設定だけです。認証情報、履歴、セッション、キャッシュ、SQLite DB、自動生成メモリは各 Mac のローカル状態として残します。

初回反映時に既存ファイルと衝突する場合は、先にバックアップします。`darwin-rebuild` 経由では `home-manager.backupFileExtension = "backup"` により既存ファイルが退避されます。Home Manager だけを使う場合はバックアップオプション付きで実行します。

```sh
home-manager switch --flake .#default --impure -b backup
```

プラグイン本体の初回インストールや Google / GitHub / Gmail / Slack などの外部サービス認証は各 Mac で実行します。

## nvw

`nvw` は git worktree を作成または開いて、そのディレクトリを Neovim で開くコマンドです。Home Manager の `home.packages` からインストールされます。

```sh
nvw <branch> [base-ref]
```

例:

```sh
nvw feature/example
nvw feature/example origin/main
```

`base-ref` を省略した場合は `HEAD` を使います。既に同名の worktree ディレクトリがある場合は作成せず、そのディレクトリをそのまま Neovim で開きます。

Neovim 内からは remote plugin 経由で同じ作成処理を呼び出せます。

```vim
:Nvw <branch> [base-ref]
:WorktreeCreate <branch>
```

`<leader>wc` も `:Nvw` と同じ Rust 実装を使います。remote plugin host は Home Manager が生成する `nvw-rplugin` から起動され、通常は直接実行しません。

worktree はメイン worktree の直下にある `.worktree` ディレクトリへ作成されます。branch 名の `/` や空白は `-` に置き換えられます。

```text
<main-worktree>/.worktree/<sanitized-branch>
```

branch が既に存在する場合:

```sh
git worktree add <worktree-path> <branch>
```

branch が存在しない場合:

```sh
git worktree add -b <branch> <worktree-path> <base-ref>
```

`.worktree/init.sh` がある場合は、worktree 作成後にそのディレクトリで実行します。init script には次の環境変数が渡されます。

```text
WORKTREE_MAIN_ROOT=<main-worktree>
WORKTREE_PATH=<worktree-path>
WORKTREE_BRANCH=<branch>
WORKTREE_BASE=<base-ref>
```

## GitHub SSH キー

Home Manager の activation 時に `~/.ssh/id_ed25519` が無ければ、GitHub 用の初期 SSH キーを生成します。既に `~/.ssh/id_ed25519` がある場合、その秘密鍵は上書きしません。

公開鍵は次のコマンドで確認できます。

```sh
cat ~/.ssh/id_ed25519.pub
```

表示された公開鍵を GitHub の SSH keys 設定に登録します。

```text
GitHub > Settings > SSH and GPG keys > New SSH key
```

登録後、接続確認は次のコマンドで行います。

```sh
ssh -T git@github.com
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
