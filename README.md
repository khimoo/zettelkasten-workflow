# zettelkasten-workflow

Zettelkasten（Obsidian vault）を複数マシンで再現するための **Nix mechanism と Obsidian 設定**
を切り出した public repo。**Nix さえ入っていれば**（非 NixOS・非 home-manager でも）動くことを
目指す。ノート本文は別の private repo にあり、ここには含まれない。

## 提供するもの

- `homeManagerModules.zettelkasten` — vault 添付フォルダの rclone bisync・papis ライブラリ同期
  （`services.zettelkasten.{attachments,papis}`）と、`.obsidian` 設定の seed-once 配置
  （`services.zettelkasten.obsidian.enable`）を行う home-manager モジュール。
- `packages.<system>.{zettelkasten-sync, papis-sync, seed-obsidian}` / `apps` — home-manager
  非対応環境でも `nix run` で同じ実体を実行できる。HM モジュールとスクリプトを共有する。
- `.obsidian/`（＋ `packages.obsidian-config`）— sanitize 済みの Obsidian 設定と community
  plugin 本体。`seed-obsidian` がこれを vault に非破壊コピーする。private なパス（bookmark・
  レイアウトに開いていたノート・`workspace.json`）は除外/空化済み。
- `secrets/rclone.yaml` — rclone 設定を sops で暗号化した暗号文。復号は同期スクリプトが
  実行時に行う（`nix/with-rclone-secret.nix`）。復号鍵は各マシンのユーザー SSH 鍵
  （ssh-to-age で age 鍵に変換）。公開されるのは受信者（age 公開鍵）と暗号文のみで、
  平文の設定は載らない。

## なぜ mechanism を分離したか

元は private な vault repo に同居していた。flake の input として `git+ssh` で取得すると
**評価時に SSH 鍵が必須**になり、「鍵ゼロからの環境復元」を阻む。mechanism を public 化し
`github:` で取得することで、消費側 flake の eval が SSH 鍵に依存しなくなる。

## 消費側

home-manager / NixOS から（flake input として取り込む）:

```nix
inputs.zettelkasten.url = "github:khimoo/zettelkasten-workflow";
# services.zettelkasten.enable = true; obsidian.enable = true; zettelkastenRoot = "…";
```

Nix さえあれば（非 NixOS・非 home-manager）、ノートの private repo を clone した後に:

```sh
# vault に .obsidian(設定 + plugin)を配置。既存があれば非破壊で skip。
nix run github:khimoo/zettelkasten-workflow#seed-obsidian -- /path/to/vault
# 添付/papis の同期をワンショット実行
nix run github:khimoo/zettelkasten-workflow#zettelkasten-sync
```
