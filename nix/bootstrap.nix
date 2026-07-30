# 新しいマシンで vault を使える状態にするまでの対話スクリプト(`nix run` の既定 app)。
#
# 設計方針:
#   - 進捗ファイルを持たない。各ステップは実物(.git / .obsidian / rclone remote / 設定ファイル /
#     bisync の記録)を見て、済んでいれば自分で skip する。途中で中断しても再実行すれば続きから進む。
#   - 外部サービスの認証は「確かめて、駄目なら本来のツールに渡す」(probe, don't provision)。
#     rclone は `rclone about` を試し、駄目なら `rclone config` を起動して人間に渡すだけ。
#     GitHub には一切触らない——remote との接続は各自の領分で、我々は成立しているかも知らない。
#   - 自分が起こした変更以外を元に戻さない。既にあるもの(.obsidian・設定ファイル)は確認なしに
#     上書きしない。
#
# seed と同期は専用スクリプトを呼ぶ(ロジックを二重に持たない)。設定ファイルの書式は
# nix/vault-config.nix が読み書きの両方を持つ。
{ pkgs, seedObsidian, syncScript }:

let
  vaultConfig = import ./vault-config.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "zettelkasten-bootstrap";
  runtimeInputs = vaultConfig.runtimeInputs ++ [ pkgs.rclone pkgs.gnugrep pkgs.diffutils ];
  text = ''
    ${vaultConfig.text}

    say() { echo "$*" >&2; }
    die() { echo "$*" >&2; exit 1; }

    # 対話が前提なので、パイプや systemd から呼ばれたら黙って進めず落とす。
    if [ ! -t 0 ]; then
      die "zettelkasten-bootstrap は対話的に実行してください(標準入力が端末ではありません)。"
    fi

    ask() {
      local prompt="$1" default="''${2:-}" reply
      if [ -n "$default" ]; then
        printf '%s [%s]: ' "$prompt" "$default" >&2
      else
        printf '%s: ' "$prompt" >&2
      fi
      if ! IFS= read -r reply; then
        echo >&2
        die "入力を読み取れませんでした。中断します。"
      fi
      echo "''${reply:-$default}"
    }

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

    # 打ちやすさのために ~ と相対パスを受け付ける。以降は絶対パスだけを扱う。
    abspath() {
      local p="$1"
      if [ "$p" = "~" ]; then
        p="$HOME"
      elif [ "''${p#\~/}" != "$p" ]; then
        p="$HOME/''${p#\~/}"
      fi
      case "$p" in
        /*) ;;
        *) p="$PWD/$p" ;;
      esac
      echo "$p"
    }

    cat >&2 <<'EOF'
    === zettelkasten bootstrap ===

    この先で行うこと:
      1. vault(ノートを置くフォルダ)の用意
      2. Obsidian 設定の配置
      3. Google Drive との接続確認(rclone)
      4. 同期先の設定を vault に保存
      5. 初回同期

    途中で止めても、もう一度実行すれば済んだところは飛ばします。

    EOF

    # ---- 1. vault ----
    vault="$(abspath "$(ask "vault(ノートを置くフォルダ)のパス" "$HOME/zettelkasten")")"

    if [ -e "$vault" ] && [ ! -d "$vault" ]; then
      die "そこはフォルダではありません: $vault"
    fi

    # 別のリポジトリの中に vault を置くと、そちらの commit に巻き込まれる。作る前に見る
    # ——作ってから中止すると、我々が作った空フォルダだけが残る。
    if [ -d "$vault" ]; then
      vault="$( cd "$vault" && pwd -P )"
      toplevel="$(git -C "$vault" rev-parse --show-toplevel 2>/dev/null || true)"
    else
      parent="$vault"
      while [ ! -d "$parent" ] && [ "$parent" != "/" ]; do
        parent="$(dirname "$parent")"
      done
      toplevel="$(git -C "$parent" rev-parse --show-toplevel 2>/dev/null || true)"
    fi

    if [ -n "$toplevel" ] && [ "$toplevel" != "$vault" ]; then
      say "そこは別の git リポジトリの中です: $toplevel"
      die "  → 巻き込み事故を避けるため中断します。リポジトリの外を vault にしてください。"
    fi

    if [ ! -d "$vault" ]; then
      confirm "$vault はまだありません。作成しますか" y || die "中断しました。"
      mkdir -p "$vault"
      vault="$( cd "$vault" && pwd -P )"
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

    # ---- 2. Obsidian 設定 ----
    say ""
    ${pkgs.lib.getExe seedObsidian} "$vault"

    # ---- 3. rclone ----
    say ""
    cat >&2 <<'EOF'
    添付ファイルと文献 PDF は git ではなく Google Drive で同期します。
    その接続は rclone が持ちます(この repo は認証情報を持ちません)。
    EOF

    remote="$(ask "rclone の remote 名" "gdrive")"
    while true; do
      if rclone listremotes | grep -qx "$remote:" && rclone about "$remote:" >/dev/null; then
        say "remote '$remote' に接続できました。"
        break
      fi
      say ""
      say "remote '$remote' に接続できませんでした。"
      confirm "rclone config を起動して設定しますか" y \
        || die "中断しました。rclone config で remote を用意してから再実行してください。"
      rclone config
      remote="$(ask "rclone の remote 名" "$remote")"
    done

    # ---- 4. 設定ファイル ----
    say ""
    cat >&2 <<'EOF'
    Drive 側のフォルダ名を決めます(無ければ初回同期で作られます)。
    vault 側は attachments/ と references/ で固定です。
    EOF

    attachments_folder="$(ask "添付を置く Drive のフォルダ名" "zettelkasten-attachments")"

    papis_sync=0
    papis_folder=""
    if confirm "papis(文献管理)のライブラリも同期しますか" n; then
      papis_sync=1
      papis_folder="$(ask "papis ライブラリを置く Drive のフォルダ名" "papis-library")"
    fi

    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    zk_cfg_write "$tmp" "$remote" "$attachments_folder" "$papis_sync" "$papis_folder"

    cfg="$vault/$ZK_CONFIG_BASENAME"
    write_cfg=1
    if [ -f "$cfg" ]; then
      if cmp -s "$cfg" "$tmp/$ZK_CONFIG_BASENAME"; then
        say "設定ファイルは既に同じ内容です: $cfg"
        write_cfg=0
      else
        say ""
        say "既にある設定ファイルと内容が違います: $cfg"
        diff -u --label "現在" "$cfg" --label "これから書く" "$tmp/$ZK_CONFIG_BASENAME" >&2 || true
        confirm "上書きしますか" y || write_cfg=0
      fi
    fi

    if [ "$write_cfg" = 1 ]; then
      mv "$tmp/$ZK_CONFIG_BASENAME" "$cfg"
      say "設定を保存しました: $cfg"
    else
      say "設定ファイルはそのままにします。"
    fi

    # ---- 5. 初回同期 ----
    say ""
    if confirm "初回の同期を実行しますか" y; then
      if ! ${pkgs.lib.getExe syncScript} "$vault"; then
        say ""
        say "同期に失敗しました。上の rclone のメッセージが理由です。"
        say "  → 「両側に中身があり、どちらを正とするか決められない」場合は、"
        say "    中身を確認したうえで次を実行してください:"
        say "      ZK_FORCE_RESYNC=1 zettelkasten-sync '$vault' --resync"
      fi
    else
      say "同期は行いませんでした。あとで vault の中で zettelkasten-sync を実行してください。"
    fi

    # ---- 残る手作業 ----
    say ""
    cat >&2 <<'EOF'
    === ここまでで自動化できる分は終わりです ===

    残りは手作業です:
      * Obsidian を起動する
          nix run github:khimoo/zettelkasten-workflow#obsidian
        初回だけ「このプラグインの製作者を信用しますか」を聞かれます(信用すると有効になります)。
      * Claude を使うプラグインを動かすなら、一度ログインする
          claude
      * vault を別のマシンにも持っていくなら、自分で git remote を足して push する
          git -C VAULT remote add origin <URL>
          git -C VAULT push -u origin main
        設定ファイル(.zettelkasten.json)も一緒に届くので、2台目では clone してから
        このコマンドを実行するだけで済みます。

    日常の同期は vault の中で:
      nix run github:khimoo/zettelkasten-workflow#sync
    EOF
    say ""
    say "vault: $vault"
  '';
}
