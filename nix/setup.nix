# 新しいマシンで vault を使える状態にするまでの対話スクリプト。
#
# home-manager が宣言的に片付けられない残りだけをここが持つ——vault フォルダの用意、
# rclone の OAuth、初回同期の曖昧ケース。同期先やパスは options が eval 時に焼き込むので
# 値は一切聞かない(聞くのは「作るか」「起動するか」の判断だけ)。
#
# 設計方針:
#   - 進捗ファイルを持たない。各ステップは実物(.git / .obsidian / rclone remote / bisync の記録)を
#     見て、済んでいれば skip する。途中で止めても再実行すれば続きから進む。
#   - 外部サービスの認証は「確かめて、駄目なら本来のツールに渡す」(probe, don't provision)。
#     GitHub には一切触らない——remote との接続は各自の領分。
#   - 自分が起こした変更以外を元に戻さない。既にあるものは確認なしに上書きしない。
#
# seed と同期は専用スクリプトを呼ぶ(ロジックを二重に持たない)。
{ pkgs
, vaultDir
, rcloneRemote
, seedObsidian ? null # null なら Obsidian 設定を配らない構成
, syncScript ? null # null なら同期対象がひとつも無い構成
}:

let
  inherit (pkgs) lib;

  steps = [ "vault(ノートを置くフォルダ)の用意" ]
    ++ lib.optional (seedObsidian != null) "Obsidian 設定の配置"
    ++ lib.optionals (syncScript != null) [
    "Google Drive との接続確認(rclone)"
    "初回同期"
  ];

  stepList = lib.concatStringsSep "\n"
    (lib.imap1 (i: s: "  ${toString i}. ${s}") steps);
in
pkgs.writeShellApplication {
  name = "zettelkasten-setup";
  runtimeInputs = [ pkgs.coreutils pkgs.git ]
    ++ lib.optionals (syncScript != null) [ pkgs.rclone pkgs.gnugrep ];
  text = ''
    vault=${lib.escapeShellArg vaultDir}

    say() { echo "$*" >&2; }
    die() { echo "$*" >&2; exit 1; }

    # 対話が前提なので、パイプや systemd から呼ばれたら黙って進めず落とす。
    if [ ! -t 0 ]; then
      die "zettelkasten-setup は対話的に実行してください(標準入力が端末ではありません)。"
    fi

    confirm() {
      local prompt="$1" default="$2" reply hint
      if [ "$default" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi
      while true; do
        printf '%s %s: ' "$prompt" "$hint" >&2
        if ! IFS= read -r reply; then
          echo >&2
          die "入力を読み取れませんでした。中断します。"
        fi
        case "''${reply:-$default}" in
          y | Y | yes | YES) return 0 ;;
          n | N | no | NO) return 1 ;;
          *) say "y か n で答えてください。" ;;
        esac
      done
    }

    cat >&2 <<EOF
    === zettelkasten setup ===

    vault: $vault

    この先で行うこと:
    ${stepList}

    途中で止めても、もう一度実行すれば済んだところは飛ばします。

    EOF

    # ---- vault ----
    if [ -e "$vault" ] && [ ! -d "$vault" ]; then
      die "そこはフォルダではありません: $vault"
    fi

    # 別のリポジトリの中に vault があると、そちらの commit に巻き込まれる。作る前に見る
    # ——作ってから中止すると、我々が作った空フォルダだけが残る。
    # git は物理パスを返すので、比較する側も物理パスに揃える(symlink 越しの誤検知を避ける)。
    if [ -d "$vault" ]; then
      vault_real="$( cd "$vault" && pwd -P )"
      toplevel="$(git -C "$vault" rev-parse --show-toplevel 2>/dev/null || true)"
    else
      vault_real="$vault"
      parent="$vault"
      while [ ! -d "$parent" ] && [ "$parent" != "/" ]; do
        parent="$(dirname "$parent")"
      done
      toplevel="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null || true)"
    fi

    if [ -n "$toplevel" ] && [ "$toplevel" != "$vault_real" ]; then
      say "そこは別の git リポジトリの中です: $toplevel"
      die "  → 巻き込み事故を避けるため中断します。リポジトリの外を vault にしてください。"
    fi

    if [ ! -d "$vault" ]; then
      confirm "$vault はまだありません。作成しますか" y || die "中断しました。"
      mkdir -p "$vault"
      say "作成しました: $vault"
    fi

    is_repo=0
    if [ -n "$toplevel" ]; then
      is_repo=1
      say "git リポジトリとして認識しました: $vault"
    else
      cat >&2 <<'EOF'

    vault を git リポジトリにしておくと、ノートの履歴が残り、
    別のマシンに持っていく(clone する)こともできます。
    GitHub 等との接続はここでは扱いません(あとから自分で remote を足せます)。
    EOF
      if confirm "ここをローカル git リポジトリにしますか" y; then
        git -C "$vault" init -q
        is_repo=1
        say "git リポジトリにしました: $vault"
      else
        say "git は使わずに続けます。"
      fi
    fi

    # 同期フォルダと端末固有のファイルは git に入れない。既に .gitignore があれば触らない。
    if [ "$is_repo" = 1 ] && [ ! -e "$vault/.gitignore" ]; then
      cat > "$vault/.gitignore" <<'EOF'
    /.obsidian/workspace.json
    /.obsidian/workspace-mobile.json
    /attachments/
    /references/
    /.claudian/sessions/
    /.obsidian/plugins/realclaudian/data.json
    EOF
      say ".gitignore を作成しました: $vault/.gitignore"
    fi
    ${lib.optionalString (seedObsidian != null) ''

      # ---- Obsidian 設定 ----
      # home-manager の activation でも同じものが走るが、vault がまだ無い間は skip される。
      # ここで作った直後に呼ぶことで、switch のやり直しを不要にする。
      say ""
      ${lib.getExe seedObsidian} "$vault"
    ''}
    ${lib.optionalString (syncScript != null) ''

      # ---- rclone ----
      say ""
      cat >&2 <<'EOF'
      添付ファイルと文献 PDF は git ではなく Google Drive で同期します。
      その接続は rclone が持ちます(この repo は認証情報を持ちません)。
      EOF

      remote=${lib.escapeShellArg rcloneRemote}
      while ! { rclone listremotes | grep -qx "$remote:" && rclone about "$remote:" >/dev/null 2>&1; }; do
        say ""
        say "rclone の remote '$remote' に接続できませんでした。"
        say "  (未作成か、認証の期限が切れています)"
        confirm "rclone config を起動して設定しますか" y \
          || die "中断しました。remote '$remote' を用意してから再実行してください。"
        cat >&2 <<EOF

      rclone config が開きます。remote の名前は **$remote** にしてください
      (この名前は home-manager の設定と一致している必要があります)。
      種類は Google Drive を選び、あとは既定のまま進めて構いません。

      EOF
        rclone config
      done
      say "remote '$remote' に接続できました。"

      # ---- 初回同期 ----
      say ""
      if confirm "初回の同期を実行しますか" y; then
        if ! ${lib.getExe syncScript}; then
          say ""
          say "同期に失敗しました。上の rclone のメッセージが理由です。"
          say "  → 「このマシンには記録が無いのに Drive 側にデータがある」場合は、"
          say "    Drive の中身を確認したうえで次を実行してください:"
          say "      ZK_FORCE_RESYNC=1 zettelkasten-sync --resync"
        fi
      else
        say "同期は行いませんでした。あとで zettelkasten-sync を実行してください。"
      fi
    ''}

    # ---- 残る手作業 ----
    say ""
    cat >&2 <<'EOF'
    === ここまでで自動化できる分は終わりです ===

    残りは手作業です:
    EOF
    ${lib.optionalString (seedObsidian != null) ''
      cat >&2 <<'EOF'
        * Obsidian を起動して、vault として上のフォルダを開く
          初回だけ「このプラグインの製作者を信用しますか」を聞かれます(信用すると有効になります)。
        * Claude を使うプラグインを動かすなら、一度ログインする
              claude
      EOF
    ''}
    if [ "$is_repo" = 1 ]; then
      cat >&2 <<'EOF'
      * vault を別のマシンにも持っていくなら、自分で git remote を足して push する
            git remote add origin <URL>
            git push -u origin main
    EOF
    fi
    ${lib.optionalString (syncScript != null) ''
      cat >&2 <<'EOF'

      日常の同期は自動です(ファイルを変更すると走り、取りこぼしは定期実行が拾います)。
      手で走らせたいときは zettelkasten-sync を実行してください。
      EOF
    ''}
  '';
}
