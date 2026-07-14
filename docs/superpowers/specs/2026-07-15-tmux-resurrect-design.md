# tmux-resurrect 導入設計

## 目的

Home Manager 管理の tmux に `tmux-resurrect` を追加し、tmux セッションを手動で保存・復元できるようにする。

## 構成

- `modules/home/tmux.nix` を追加する。
- `programs.tmux.enable` を有効化する。
- `programs.tmux.plugins` に Nixpkgs 提供の `tmux-resurrect` を追加する。
- `modules/home/default.nix` から新しいモジュールを import する。

## 利用方法

tmux-resurrect の標準キーバインドを使う。

- `prefix + Ctrl-s`: セッションを保存する。
- `prefix + Ctrl-r`: セッションを復元する。

`tmux-continuum` は追加しないため、自動保存・自動復元は行わない。

## 検証

Nix 評価で Home Manager 設定が解決できることを確認する。tmux-resurrect がプラグイン一覧に含まれることも評価結果から確認する。
