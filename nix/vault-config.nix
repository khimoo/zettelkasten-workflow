# vault に同居する設定ファイル(.zettelkasten.json)の形式定義と読み取り。
#
# 設定の source-of-truth は vault(private repo)。clone すれば2台目にもそのまま届く。
# 同期対象のパスは設定項目にせず規約で固定する(vault 直下の attachments/ と references/)——
# systemd の PathModified や programs.papis は eval 時に具体的なパスを要求する一方、非 HM の
# sync は実行時に解決するため、可変にすると同じ値が2か所に存在して食い違う。
#
# 形式(version 1):
#   { "version": 1,
#     "rcloneRemote": "gdrive",
#     "attachments": { "folder": "zettelkasten-attachments" },
#     "papis": { "sync": true, "folder": "papis-library" } }
#
# rclone の認証情報はここには入らない(~/.config/rclone/rclone.conf の管轄)。
{ pkgs }:

{
  # 埋め込む側が writeShellApplication の runtimeInputs に足すもの。
  runtimeInputs = [ pkgs.jq pkgs.git pkgs.coreutils ];

  # 埋め込む側のスクリプト冒頭に展開して使う関数群。
  #   zk_vault_root [path]  … vault の絶対パスを stdout に返す
  #   zk_cfg_load <vault>   … 設定を読んで ZK_* 変数に載せる
  text = ''
    ZK_CONFIG_BASENAME=".zettelkasten.json"
    ZK_CONFIG_VERSION=1
    ZK_ATTACHMENTS_SUBDIR="attachments"
    ZK_PAPIS_SUBDIR="references"

    # vault の絶対パスを決める。引数 > ZETTELKASTEN_ROOT > cwd の git toplevel。
    zk_vault_root() {
      local candidate
      candidate="''${1:-''${ZETTELKASTEN_ROOT:-}}"

      if [ -z "$candidate" ]; then
        candidate="$(git rev-parse --show-toplevel 2>/dev/null || true)"
      fi

      if [ -z "$candidate" ]; then
        echo "vault が特定できません。" >&2
        echo "  → vault の中で実行するか、第1引数か環境変数 ZETTELKASTEN_ROOT で絶対パスを渡してください。" >&2
        return 1
      fi

      if [ ! -d "$candidate" ]; then
        echo "vault が存在しません: $candidate" >&2
        return 1
      fi

      ( cd "$candidate" && pwd -P )
    }

    # 設定を読み、以下を設定する:
    #   ZK_VAULT ZK_RCLONE_REMOTE
    #   ZK_ATTACHMENTS_DIR ZK_ATTACHMENTS_REMOTE
    #   ZK_PAPIS_SYNC(1/0) ZK_PAPIS_DIR ZK_PAPIS_REMOTE
    zk_cfg_load() {
      local vault cfg version
      vault="$1"
      cfg="$vault/$ZK_CONFIG_BASENAME"

      if [ ! -f "$cfg" ]; then
        echo "vault に設定ファイルがありません: $cfg" >&2
        echo "  → 初期設定を行ってください: nix run github:khimoo/zettelkasten-workflow" >&2
        return 1
      fi

      if ! jq -e . "$cfg" >/dev/null 2>&1; then
        echo "設定ファイルが JSON として読めません: $cfg" >&2
        return 1
      fi

      version="$(jq -r '.version // empty' "$cfg")"
      if [ "$version" != "$ZK_CONFIG_VERSION" ]; then
        echo "設定ファイルの version が想定と違います: $cfg" >&2
        echo "  (期待 $ZK_CONFIG_VERSION / 実際 ''${version:-なし})" >&2
        echo "  → この repo と vault の設定を同じ世代に揃えてください。" >&2
        return 1
      fi

      ZK_VAULT="$vault"
      ZK_RCLONE_REMOTE="$(jq -r '.rcloneRemote // empty' "$cfg")"
      ZK_ATTACHMENTS_FOLDER="$(jq -r '.attachments.folder // empty' "$cfg")"
      ZK_PAPIS_SYNC="$(jq -r 'if .papis.sync == true then "1" else "0" end' "$cfg")"
      ZK_PAPIS_FOLDER="$(jq -r '.papis.folder // empty' "$cfg")"

      if [ -z "$ZK_RCLONE_REMOTE" ]; then
        echo "設定ファイルに rcloneRemote がありません: $cfg" >&2
        return 1
      fi

      if [ -z "$ZK_ATTACHMENTS_FOLDER" ]; then
        echo "設定ファイルに attachments.folder がありません: $cfg" >&2
        return 1
      fi

      if [ "$ZK_PAPIS_SYNC" = "1" ] && [ -z "$ZK_PAPIS_FOLDER" ]; then
        echo "papis.sync が true なのに papis.folder がありません: $cfg" >&2
        return 1
      fi

      ZK_ATTACHMENTS_DIR="$vault/$ZK_ATTACHMENTS_SUBDIR"
      ZK_ATTACHMENTS_REMOTE="$ZK_RCLONE_REMOTE:$ZK_ATTACHMENTS_FOLDER"
      ZK_PAPIS_DIR="$vault/$ZK_PAPIS_SUBDIR"
      # folder 未設定(papis.sync=false)のとき "remote:" にすると Drive ルートを指してしまうので空にする。
      if [ -n "$ZK_PAPIS_FOLDER" ]; then
        ZK_PAPIS_REMOTE="$ZK_RCLONE_REMOTE:$ZK_PAPIS_FOLDER"
      else
        ZK_PAPIS_REMOTE=""
      fi
    }
  '';
}
