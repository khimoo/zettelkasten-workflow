# zettelkasten-workflow

Zettelkasten（Obsidian vault）を複数マシンで再現するための **Nix mechanism** を
切り出した public repo。ノート本文は別の private repo にあり、ここには含まれない。

## 提供するもの

- `homeManagerModules.zettelkasten` — vault 添付フォルダの rclone bisync と papis
  ライブラリ同期を行う home-manager モジュール（`services.zettelkasten`）。
- `packages.<system>.{zettelkasten-sync, papis-sync}` / `apps` — 同期を手動実行する
  スクリプト。HM モジュールと同じ実体を共有する。
- `secrets/rclone.yaml` — rclone 設定を sops で暗号化した暗号文。復号は同期スクリプトが
  実行時に行う（`nix/with-rclone-secret.nix`）。復号鍵は各マシンのユーザー SSH 鍵
  （ssh-to-age で age 鍵に変換）。公開されるのは受信者（age 公開鍵）と暗号文のみで、
  平文の設定は載らない。

## なぜ mechanism を分離したか

元は private な vault repo に同居していた。flake の input として `git+ssh` で取得すると
**評価時に SSH 鍵が必須**になり、「鍵ゼロからの環境復元」を阻む。mechanism を public 化し
`github:` で取得することで、消費側 flake の eval が SSH 鍵に依存しなくなる。

## 消費側

```nix
inputs.zettelkasten.url = "github:khimoo/zettelkasten-workflow";
```
