# vault の添付フォルダと papis ライブラリを Google Drive へ双方向同期する単一コマンド。
#
# 対象ごとにコマンドを分けない。日常の操作は zettelkasten-sync の1つで、何が同期されるかは
# home-manager の options が eval 時に決める。unit だけは監視対象ごとに起動されるので
# --only で片方に絞る。
#
# 同期先(remote 名・Drive のフォルダ名・対象パス)はここに焼き込まれる。実行時に設定を読む層は
# 持たない——設定の source は flake ただ一つで、解決順を1段に保つ。有効でない対象は
# そもそもコードが生成されないので、papis を使わない環境に papis の分岐は存在しない。
#
# 同期の本体は nix/bisync-lib.nix。ここは「どの対象を、どこへ」だけを持つ層。
#
# attachments / papis は { dir, folder } か null。null なら その対象は生成しない。
{ pkgs
, rcloneRemote
, attachments ? null
, papis ? null
}:

let
  inherit (pkgs) lib;
  bisync = import ./bisync-lib.nix { inherit pkgs; };

  targets = lib.optional (attachments != null) "attachments"
    ++ lib.optional (papis != null) "papis";

  targetList = lib.concatStringsSep "|" targets;

  example = opt: desc:
    "  zettelkasten-sync ${opt}${lib.concatStrings (lib.genList (_: " ") (21 - lib.stringLength opt))}${desc}";

  usageText = lib.concatStringsSep "\n" ([
    "使い方: zettelkasten-sync [--only ${targetList}] [rclone bisync への追加引数...]"
    ""
    "  同期先は home-manager の services.zettelkasten が持つ。引数では変えられない。"
    ""
    "例:"
    (example "" "設定どおり全部同期する")
  ]
  # 対象が1つしかない環境で --only を勧めても意味がない。
  ++ lib.optional (lib.length targets > 1)
    (example "--only ${lib.last targets}" "${lib.last targets} だけ同期する")
  ++ [ (example "--dry-run" "rclone に渡す引数はそのまま素通しする") ]);

  # 対象ごとの同期ブロック。baseline(同期の記録)の名前は対象ごとに固定で、
  # 変えると既存マシンが「記録なし」と判定されて resync を要求される。
  syncBlock = { name, label, dir, folder, baseline }: ''
    if [ -z "$only" ] || [ "$only" = ${name} ]; then
      echo "==> ${label}: ${dir} <-> ${rcloneRemote}:${folder}" >&2
      zk_bisync ${lib.escapeShellArg label} ${lib.escapeShellArg dir} \
        ${lib.escapeShellArg "${rcloneRemote}:${folder}"} \
        ${baseline} "''${rclone_args[@]}" || status=1
    fi
  '';
in
pkgs.writeShellApplication {
  name = "zettelkasten-sync";
  runtimeInputs = bisync.runtimeInputs;
  text = ''
    ${bisync.text}

    usage() {
      cat >&2 <<'EOF'
    ${usageText}
    EOF
    }

    only=""
    rclone_args=()

    while [ $# -gt 0 ]; do
      case "$1" in
        --only)
          only="''${2:-}"
          if [ -z "$only" ]; then
            echo "--only には ${lib.concatStringsSep " か " targets} を指定してください。" >&2
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
          echo "解釈できない引数です: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    case "$only" in
      ${lib.concatStringsSep " | " ([ "\"\"" ] ++ targets)}) ;;
      *)
        echo "--only には ${lib.concatStringsSep " か " targets} を指定してください: ''${only:-(空)}" >&2
        exit 1
        ;;
    esac

    zk_rclone_init
    zk_rclone_check ${lib.escapeShellArg rcloneRemote}

    # 対象ごとに独立して試す(片方が落ちても相方を止めない)。1つでも失敗したら非ゼロで終わる。
    status=0

    ${lib.optionalString (attachments != null) (syncBlock {
      name = "attachments";
      label = "添付";
      inherit (attachments) dir folder;
      baseline = "bisync-zettelkasten";
    })}
    ${lib.optionalString (papis != null) (syncBlock {
      name = "papis";
      label = "papis";
      inherit (papis) dir folder;
      baseline = "bisync-papis";
    })}

    exit "$status"
  '';
}
