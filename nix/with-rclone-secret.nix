# 同期スクリプトに「rclone 認証情報の実行時復号」を被せるラッパー(全環境の唯一の入口)。
# sops-nix(activation 時復号)には依存しないため、NixOS / home-manager / 素の環境のどれでも
# 同じ経路で動く: 鍵発見 → flake 内の暗号文(secrets/rclone.yaml)を tmpfs へ復号 →
# RCLONE_CONFIG を向けて同期本体を実行 → 終了時に平文を削除。
#
# 同期本体(bisync-lib)は sops を知らないまま(RCLONE_CONFIG string シーム)。復号の責務は
# このラッパーだけが持つ(逐次的凝集: 復号の出力が同期の入力)。
#
# 設定と鍵の解決順序(秘密鍵は常に環境側にあり、この flake は暗号文と受信者一覧しか持たない):
#   1. RCLONE_CONFIG が既に指定されていれば復号せずそのまま実行(escape hatch。
#      fork 利用者・平文 rclone.conf 運用・sops を使わない環境向け)
#   2. SOPS_AGE_KEY / SOPS_AGE_KEY_FILE(Bitwarden 等から持ち込む age 鍵)
#   3. ~/.ssh/id_ed25519 を ssh-to-age で age 鍵に変換(自分のマシンの既定経路)
{ pkgs }:

syncScript:

let
  name = syncScript.meta.mainProgram;
  runSync = pkgs.lib.getExe syncScript;
in
pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [ pkgs.coreutils pkgs.sops pkgs.ssh-to-age ];
  text = ''
    if [ -n "''${RCLONE_CONFIG:-}" ]; then
      exec ${runSync} "$@"
    fi

    # ---- 鍵発見(層3 preflight: 無ければ復旧手順つきで loud に落とす) ----
    if [ -z "''${SOPS_AGE_KEY:-}" ] && [ -z "''${SOPS_AGE_KEY_FILE:-}" ]; then
      ssh_key="$HOME/.ssh/id_ed25519"
      if [ ! -f "$ssh_key" ]; then
        echo "${name}: rclone.conf の復号鍵が見つかりません。" >&2
        echo "  次のいずれかで鍵を用意してください:" >&2
        echo "   - このマシンの SSH 鍵を置く: ~/.ssh/id_ed25519 (.sops.yaml の受信者に登録済みのもの)" >&2
        echo "   - 持ち運び用 age 鍵を渡す:  export SOPS_AGE_KEY='AGE-SECRET-KEY-...' (Bitwarden 等から)" >&2
        echo "   - 復号せず既存の設定を使う: RCLONE_CONFIG=/path/to/rclone.conf ${name} ..." >&2
        exit 1
      fi
      if ! SOPS_AGE_KEY="$(ssh-to-age -private-key -i "$ssh_key")"; then
        echo "${name}: SSH 鍵を age 鍵に変換できませんでした: $ssh_key" >&2
        echo "  → パスフレーズ付き鍵は変換できません。SOPS_AGE_KEY で age 鍵を直接渡してください。" >&2
        exit 1
      fi
      export SOPS_AGE_KEY
    fi

    # ---- tmpfs へ復号し、終了時に平文を必ず消す ----
    plain="$(mktemp "''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/rclone-conf.XXXXXX")"
    trap 'rm -f "$plain"' EXIT

    if ! sops --decrypt --extract '["rclone_conf"]' ${../secrets/rclone.yaml} > "$plain"; then
      echo "${name}: rclone.conf の復号に失敗しました。" >&2
      echo "  → この鍵が .sops.yaml の受信者に未登録の可能性があります:" >&2
      echo "     1. 公開鍵を確認:  ssh-to-age < ~/.ssh/id_ed25519.pub" >&2
      echo "     2. vault repo の .sops.yaml に追記して:  sops updatekeys secrets/rclone.yaml" >&2
      echo "  → sops を使わない場合は RCLONE_CONFIG で既存の rclone.conf を指してください。" >&2
      exit 1
    fi

    RCLONE_CONFIG="$plain" ${runSync} "$@"
  '';
}
