# rclone bisync による双方向同期スクリプトの共通本体(添付同期・papis 同期が共有)。
# 両者はロジックが同一で、差分は「名前・env 変数名・baseline 名・既定 remote・メッセージ中の
# ラベル/例パス/作成ヒント」だけ。その差分を spec として受け取り、writeShellApplication を返す。
#
# 設定はハードコードせず実行時の環境変数から受け取る(依存性逆転):
#   <dirEnv>          (必須) 同期対象ディレクトリの絶対パス
#   <remoteEnv>       (任意) rclone remote:folder。既定は defaultRemote
#   RCLONE_CONFIG     (任意) rclone 設定ファイル。未指定なら rclone 既定解決
#   <forceResyncEnv>=1(任意) --resync ガードを意図的に外すとき
#
# 宣言的に用意できない要素(rclone の認証情報)は「層3 preflight」で実行前に検知し、
# 復旧手順つきで loud に落とす。サイレントに半端な同期をしない。baseline(bisync workdir)は
# 相方の同期と混ざらないよう baselineName 専用ディレクトリに隔離する。
{ pkgs }:

{ name              # 生成コマンド名(= メッセージの接頭辞)
, dirEnv            # 同期対象ディレクトリを渡す環境変数名
, remoteEnv         # remote 上書き用の環境変数名
, forceResyncEnv    # --resync ガードを外す環境変数名
, baselineName      # bisync workdir のディレクトリ名(相方と混ぜない)
, defaultRemote     # remoteEnv 未指定時に使う既定 remote:folder
, dirLabel          # メッセージ中の対象呼称(例: "添付フォルダ")
, exampleDir        # 使用例に出す絶対パス
, createHint        # 対象が無いときの作成手順ヒント
}:

pkgs.writeShellApplication {
  inherit name;
  runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.rclone ];
  text = ''
    sync_dir="''${${dirEnv}:-}"
    remote="''${${remoteEnv}:-${defaultRemote}}"

    # 相方の bisync と baseline を混ぜないよう専用 workdir に隔離する。
    baseline_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/rclone/${baselineName}"

    # rclone 設定パスの解決: RCLONE_CONFIG があれば明示 --config、無ければ rclone 既定。
    config_args=()
    if [ -n "''${RCLONE_CONFIG:-}" ]; then
      config_args=(--config "$RCLONE_CONFIG")
    fi

    # ---- 層3 preflight: 宣言的に用意できない要素の存在/有効性を検知する ----

    if [ -z "$sync_dir" ]; then
      echo "${name}: 同期対象ディレクトリが未指定です。" >&2
      echo "  → 環境変数 ${dirEnv} に ${dirLabel}(絶対パス)を設定してください。" >&2
      echo "    例: ${dirEnv}=\"${exampleDir}\" ${name} --resync" >&2
      exit 1
    fi

    if [ ! -d "$sync_dir" ]; then
      echo "${name}: ${dirLabel}が見つかりません: $sync_dir" >&2
      echo "  → ${createHint}" >&2
      exit 1
    fi

    # RCLONE_CONFIG を明示した場合のみ実在を厳密チェック(未指定時は rclone 既定に委ねる)。
    if [ -n "''${RCLONE_CONFIG:-}" ] && [ ! -f "$RCLONE_CONFIG" ]; then
      echo "${name}: rclone 設定ファイルが存在しません: $RCLONE_CONFIG" >&2
      echo "  → RCLONE_CONFIG の指し先を確認してください(rclone config で作成するか、正しいパスを指定)。" >&2
      exit 1
    fi

    # remote 名(コロンの手前)を取り出し、定義済みか確認する。
    remote_name="''${remote%%:*}"
    if ! rclone "''${config_args[@]}" listremotes | grep -qx "''${remote_name}:"; then
      echo "${name}: rclone remote '$remote_name' が未定義です(宣言的に生成できない認証部分)。" >&2
      echo "  → 次のいずれかで用意してください:" >&2
      echo "     - 対話取得:  rclone config   (remote 名 '$remote_name' / type drive)" >&2
      echo "     - 既存の rclone.conf を RCLONE_CONFIG で指す" >&2
      exit 1
    fi

    # 認証が実際に通るか(token 失効・権限不足の検知)。
    if ! rclone "''${config_args[@]}" about "''${remote_name}:" >/dev/null 2>&1; then
      echo "${name}: '$remote_name' の認証に失敗しました(token 失効の可能性)。" >&2
      echo "  → 再認証:  rclone config reconnect ''${remote_name}:" >&2
      exit 1
    fi

    # ---- 初回ブートストラップ判定(ベースライン .lst の有無で判定) ----
    # ベースラインが無ければこのペアの初回。remote が空/不在なら安全に自己初期化
    # (mkdir + --resync)する。remote にデータがあるのにベースラインが無い場合は
    # 「ベースライン喪失」か「既存 remote への新マシン合流」の曖昧ケースなので、
    # 誤同期を避けて明示の ${forceResyncEnv}=1 を要求する。
    shopt -s nullglob
    baseline_lsts=("$baseline_dir"/*.lst)
    first_run=false
    if [ "''${#baseline_lsts[@]}" -eq 0 ]; then
      first_run=true
    fi

    # ユーザが明示的に --resync を付けたか。
    resync=false
    for arg in "$@"; do
      if [ "$arg" = "--resync" ]; then
        resync=true
      fi
    done

    if [ "$first_run" = true ]; then
      if remote_listing="$(rclone "''${config_args[@]}" lsf "$remote" 2>/dev/null)" && [ -n "$remote_listing" ]; then
        # remote にデータあり + ローカルにベースライン無し = 曖昧ケース。
        if [ "''${${forceResyncEnv}:-}" != "1" ] && [ "$resync" != true ]; then
          echo "${name}: ローカルにベースラインが無いのに remote にデータがあります: $remote" >&2
          echo "  (ベースライン喪失、または既存 remote への新マシン合流のどちらか)" >&2
          echo "  → このマシンを合流させる場合のみ明示的に: ${forceResyncEnv}=1 ${name} --resync" >&2
          exit 1
        fi
        resync=true
      else
        # remote が空/不在 = 真の初回。remote を用意して --resync で初期化する。
        echo "${name}: 初回同期を検知しました(remote 空/不在)。remote を作成し --resync で初期化します。" >&2
        rclone "''${config_args[@]}" mkdir "$remote"
        resync=true
      fi
    fi

    # ---- --resync ガード(既存ベースラインの誤上書き防止) ----
    # 初回でない(ベースラインあり)のにユーザが --resync を付けた場合のみ、誤操作防止で止める。
    if [ "$resync" = true ] && [ "$first_run" != true ] && [ "''${${forceResyncEnv}:-}" != "1" ]; then
      echo "${name}: bisync のベースラインが既に存在します($baseline_dir)。" >&2
      echo "  誤操作による上書きを防ぐため --resync を中止しました。" >&2
      echo "  意図的にやり直す場合のみ ${forceResyncEnv}=1 を付けて再実行してください。" >&2
      exit 1
    fi

    # resync が必要でユーザ引数に無ければ付与(二重指定を避ける)。
    resync_args=()
    if [ "$resync" = true ]; then
      case " $* " in
        *" --resync "*) ;;
        *) resync_args=(--resync) ;;
      esac
    fi

    exec rclone "''${config_args[@]}" bisync \
      "$sync_dir" "$remote" \
      --workdir "$baseline_dir" \
      --conflict-resolve newer --resilient --verbose \
      "''${resync_args[@]}" "$@"
  '';
}
