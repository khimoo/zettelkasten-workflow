# vault の添付フォルダと papis ライブラリを Google Drive へ双方向同期する単一コマンド。
#
# 対象ごとにコマンドを分けない。日常の操作は「vault の中で zettelkasten-sync を打つ」の1つで、
# 何が同期されるか(papis を含むか)は vault の設定ファイルが決める。home-manager の各 unit だけは
# 監視対象ごとに起動されるので --only で片方に絞る。
#
# 同期パラメータは実行時に vault の .zettelkasten.json から読む(nix/vault-config.nix)。
# 同期の本体は nix/bisync-lib.nix。ここは「引数と設定を解決して bisync を対象ぶん呼ぶ」層。
{ pkgs }:

let
  vaultConfig = import ./vault-config.nix { inherit pkgs; };
  bisync = import ./bisync-lib.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "zettelkasten-sync";
  runtimeInputs = vaultConfig.runtimeInputs ++ bisync.runtimeInputs;
  text = ''
    ${vaultConfig.text}
    ${bisync.text}

    usage() {
      cat >&2 <<'EOF'
    使い方: zettelkasten-sync [vault のパス] [--only attachments|papis] [rclone bisync への追加引数...]

      vault のパスは省略できる(vault の中で実行するか ZETTELKASTEN_ROOT で渡した場合)。
      同期先(rclone remote と Drive のフォルダ名)は vault の .zettelkasten.json が持つ。

    例:
      zettelkasten-sync                      vault の中で、設定どおり全部同期する
      zettelkasten-sync ~/zettelkasten       vault を明示する
      zettelkasten-sync --only papis         papis ライブラリだけ同期する
      zettelkasten-sync --dry-run            rclone に渡す引数はそのまま素通しする
    EOF
    }

    only=""
    vault_arg=""
    rclone_args=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --only)
          only="''${2:-}"
          if [ -z "$only" ]; then
            echo "--only には attachments か papis を指定してください。" >&2
            exit 1
          fi
          shift 2
          ;;
        --vault)
          vault_arg="''${2:-}"
          if [ -z "$vault_arg" ]; then
            echo "--vault には vault の絶対パスを指定してください。" >&2
            exit 1
          fi
          shift 2
          ;;
        -h | --help)
          usage
          exit 0
          ;;
        # 上記以外のオプションは rclone bisync へ素通しする(--dry-run, --resync など)。
        -*)
          rclone_args+=("$1")
          shift
          ;;
        *)
          if [ -z "$vault_arg" ]; then
            vault_arg="$1"
          else
            rclone_args+=("$1")
          fi
          shift
          ;;
      esac
    done

    case "$only" in
      "" | attachments | papis) ;;
      *)
        echo "--only には attachments か papis を指定してください: $only" >&2
        exit 1
        ;;
    esac

    vault="$(zk_vault_root "$vault_arg")"
    zk_cfg_load "$vault"

    zk_rclone_init
    zk_rclone_check "$ZK_RCLONE_REMOTE"

    # 片方が失敗しても相方は試す(どちらが落ちたかを両方見せる)。最後に失敗があれば非ゼロで終わる。
    status=0

    if [ -z "$only" ] || [ "$only" = attachments ]; then
      echo "==> 添付: $ZK_ATTACHMENTS_DIR <-> $ZK_ATTACHMENTS_REMOTE" >&2
      zk_bisync "添付" "$ZK_ATTACHMENTS_DIR" "$ZK_ATTACHMENTS_REMOTE" \
        bisync-zettelkasten "''${rclone_args[@]}" || status=1
    fi

    if [ -z "$only" ] || [ "$only" = papis ]; then
      if [ "$ZK_PAPIS_SYNC" = "1" ]; then
        echo "==> papis: $ZK_PAPIS_DIR <-> $ZK_PAPIS_REMOTE" >&2
        zk_bisync "papis" "$ZK_PAPIS_DIR" "$ZK_PAPIS_REMOTE" \
          bisync-papis "''${rclone_args[@]}" || status=1
      elif [ "$only" = papis ]; then
        # 明示的に papis を指定されたのに無効なのは、設定の取り違えなので黙って成功にしない。
        echo "papis の同期は設定で無効です($ZK_VAULT/$ZK_CONFIG_BASENAME の papis.sync)。" >&2
        status=1
      fi
    fi

    exit "$status"
  '';
}
