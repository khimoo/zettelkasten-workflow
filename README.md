# zettelkasten-workflow

Zettelkasten（Obsidian vault）を複数マシンで再現するための **Nix mechanism と Obsidian 設定**
を切り出した public repo。**Nix さえ入っていれば**（非 NixOS・非 home-manager でも）動くことを
目指す。ノート本文は別の private repo にあり、ここには含まれない。

## 提供するもの

- `homeManagerModules.zettelkasten` — vault 添付フォルダの rclone bisync・papis ライブラリ同期
  （`services.zettelkasten.{attachments,papis}`）と、`.obsidian` 設定の seed-once 配置
  （`services.zettelkasten.obsidian.enable`）を行う home-manager モジュール。
- `apps.{sync, seed-obsidian, mirror-obsidian, obsidian}` — home-manager 非対応環境でも `nix run` で
  同じ実体を実行できる。HM モジュールとスクリプトを共有する。`sync` は添付と papis をまとめて
  同期する単一コマンドで、同期先（rclone remote と Drive のフォルダ名）は vault 直下の
  `.zettelkasten.json` が持つ（clone すれば2台目にも設定がそのまま届く）。
- `apps.obsidian` — Obsidian 本体を、配布する plugin が実行時に要求する外部コマンドごと配る
  （`obsidian-git` → `git`、`realclaudian` → `claude`）。unfree の許可もこちら持ちなので
  `NIXPKGS_ALLOW_UNFREE` は要らない。素の `nix run nixpkgs#obsidian` では両コマンドが PATH に
  無く、plugin が無言で動かない。
- `.obsidian/`（＋ `packages.obsidian-config`）— sanitize 済みの Obsidian 設定と community
  plugin 本体。`seed-obsidian` がこれを vault に非破壊コピーする。private なパス（bookmark・
  レイアウトに開いていたノート・`workspace.json`）は除外/空化済み。**typst plugin は配らない**
  — WSL の Obsidian を native assertion で落とし（JS 側で catch できない）、26MB の wasm を
  持ち込むうえ、上流が 2024 年から停滞しているため。`mirror-obsidian` も vault から持ち帰らない。
- `mirror-obsidian`（＋ `services.zettelkasten.obsidian.mirrorRepo`）— `seed-obsidian` の逆向き。
  vault の **tracked** `.obsidian`（＝各自の `.gitignore` が sanitize した集合）を、指定した
  config repo（この repo 自身や fork の repo）へコピーして commit する。config の live な
  source-of-truth は vault（`obsidian-git` が同期）で、この repo はそこからの派生スナップショット。
  変更が溜まったら手で `mirror-obsidian` を実行して派生を更新する（`--dry-run` / `--push` あり）。

この repo は rclone の認証情報を持たない。各マシンで `rclone config` が作った
`~/.config/rclone/rclone.conf` を rclone 自身が既定で解決する。

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
# Obsidian を起動(git と claude を PATH に載せた状態で)
nix run github:khimoo/zettelkasten-workflow#obsidian
# 添付と papis の同期をワンショット実行(vault の中で実行するか、パスを渡す)
nix run github:khimoo/zettelkasten-workflow#sync -- /path/to/vault
# vault の tracked .obsidian を config repo へミラーして commit(fork は自分の dest を渡す)
nix run github:khimoo/zettelkasten-workflow#mirror-obsidian -- /path/to/vault /path/to/config-repo
```
