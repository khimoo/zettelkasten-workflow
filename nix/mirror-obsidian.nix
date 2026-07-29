# vault の tracked .obsidian を別リポジトリ(config repo)へミラーして commit する。
# home-manager(PATH)と `nix run`(ワンショット)が共有する 1 本のスクリプト。
#
# 責務: config の source-of-truth は vault(ノートの private repo。obsidian-git が live 同期する)。
# 共有/public repo はそこからの派生スナップショットで、このスクリプトが「たまに手動で」更新する。
# seed-obsidian が public→vault の配布なのに対し、mirror-obsidian は vault→public の逆向き。
#
# 依存性逆転: source(vault)と dest(config repo)は引数/環境変数で受け取り、owner をハードコード
# しない——fork した第三者は自分の dest を渡すだけで同じ機構を使える。
#
# sanitize = vault の .gitignore。ミラー対象は `git ls-files .obsidian`(vault が tracked にした
# 集合)だけなので、workspace.json や token を持つ data.json 等は各自の gitignore が除外する。
# tracked が空なら誤って dest の設定を消さないよう中止する(安全策)。
#
# excludedPlugins は「vault では使うが配らない」プラグイン。vault 側の .gitignore では表現できない
# (vault は自分用に tracked にしている)ので、配布の境界であるこの層で落とす。プラグイン本体と
# community-plugins.json の id の両方から除く——本体だけ消すと Obsidian が不在のプラグインを
# 読もうとする。
{ pkgs
, # typst: 26MB の wasm を持ち込むうえ、WSL の Obsidian を native assertion で落とす
  # (JS 側で catch できない)。上流は 2024 年から停滞。
  excludedPlugins ? [ "typst" ]
}:

pkgs.writeShellApplication {
  name = "mirror-obsidian";
  runtimeInputs = [ pkgs.coreutils pkgs.git pkgs.rsync pkgs.jq ];
  text = ''
    err() { echo "mirror-obsidian: $*" >&2; }

    show_help() {
      echo "mirror-obsidian: vault の tracked .obsidian を config repo へミラーして commit する。" >&2
      echo "" >&2
      echo "usage: mirror-obsidian [--dry-run] [--push] [VAULT] [DEST]" >&2
      echo "  VAULT  vault(ノート private repo の clone)の絶対パス(省略時 ZETTELKASTEN_ROOT)" >&2
      echo "  DEST   ミラー先 config repo の checkout 絶対パス(省略時 OBSIDIAN_CONFIG_REPO)" >&2
      echo "  --dry-run  commit せず差分のみ表示する" >&2
      echo "  --push     commit 後に push する(既定は push しない=人間ゲート)" >&2
    }

    dry_run=0
    push=0
    positional=()
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --dry-run) dry_run=1 ;;
        --push) push=1 ;;
        -h|--help) show_help; exit 0 ;;
        --) shift; while [ "$#" -gt 0 ]; do positional+=("$1"); shift; done; break ;;
        -*) err "不明なオプション: $1"; show_help; exit 1 ;;
        *) positional+=("$1") ;;
      esac
      shift
    done

    vault="''${positional[0]:-''${ZETTELKASTEN_ROOT:-}}"
    dest="''${positional[1]:-''${OBSIDIAN_CONFIG_REPO:-}}"

    # ---- preflight: 宣言的に用意できない前提(clone の有無・git repo か)を loud に落とす ----
    if [ -z "$vault" ]; then
      err "vault パスが未指定です。"
      err "  → 第1引数か環境変数 ZETTELKASTEN_ROOT で vault(絶対パス)を渡してください。"
      exit 1
    fi
    if [ ! -d "$vault" ]; then
      err "vault が見つかりません: $vault"
      exit 1
    fi
    if ! git -C "$vault" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      err "vault が git リポジトリではありません: $vault"
      exit 1
    fi
    if [ ! -d "$vault/.obsidian" ]; then
      err "vault に .obsidian がありません: $vault/.obsidian"
      err "  → Obsidian か seed-obsidian で設定を用意してから実行してください。"
      exit 1
    fi

    if [ -z "$dest" ]; then
      err "ミラー先 config repo が未指定です。"
      err "  → 第2引数か環境変数 OBSIDIAN_CONFIG_REPO で dest(絶対パス)を渡してください。"
      exit 1
    fi
    if [ ! -d "$dest" ]; then
      err "config repo が見つかりません: $dest"
      exit 1
    fi
    if ! git -C "$dest" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      err "config repo が git リポジトリではありません: $dest"
      exit 1
    fi

    # ---- ミラー対象 = vault が tracked にした .obsidian(sanitize は vault の .gitignore が担う) ----
    mapfile -d "" tracked < <(git -C "$vault" ls-files -z -- .obsidian)
    if [ "''${#tracked[@]}" -eq 0 ]; then
      err ".obsidian が vault で git tracked ではありません。ミラーを中止します。"
      err "  → 誤って dest の設定を消さないための安全策です。vault 側で .obsidian を add してください。"
      exit 1
    fi

    # 望ましい状態(tracked 集合)を tmp に組み立てる。dest には直接触れずここから反映する。
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    ( cd "$vault" && cp --parents -p -- "''${tracked[@]}" "$tmp/" )

    # ---- 配らないプラグインを落とす(本体と community-plugins.json の id の両方から) ----
    excluded=(${pkgs.lib.escapeShellArgs excludedPlugins})
    for plugin in "''${excluded[@]}"; do
      rm -rf "$tmp/.obsidian/plugins/$plugin"
    done

    enabled_json="$tmp/.obsidian/community-plugins.json"
    if [ -f "$enabled_json" ]; then
      jq --argjson excluded ${pkgs.lib.escapeShellArg (builtins.toJSON excludedPlugins)} \
        'map(select(IN($excluded[]) | not))' "$enabled_json" > "$enabled_json.new"
      mv "$enabled_json.new" "$enabled_json"
    fi

    if [ "$dry_run" -eq 1 ]; then
      err "--dry-run: $vault/.obsidian → $dest/.obsidian の差分"
      if git --no-pager diff --no-index --stat -- "$dest/.obsidian" "$tmp/.obsidian"; then
        err "(差分なし)"
      fi
      exit 0
    fi

    # dest/.obsidian を tmp の内容に一致させる(--delete で tracked から外れたファイルの削除も伝播)。
    rsync -a --delete "$tmp/.obsidian/" "$dest/.obsidian/"

    # .obsidian パスだけを stage/commit する。dest に別途 stage 済みの変更(flake 等)は巻き込まない。
    git -C "$dest" add -A -- .obsidian
    if git -C "$dest" diff --cached --quiet -- .obsidian; then
      err "差分なし。commit しません。"
      exit 0
    fi

    vault_rev="$(git -C "$vault" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    git -C "$dest" commit -q -m "obsidian: mirror .obsidian from vault @ $vault_rev" -- .obsidian
    err "commit しました: $dest"
    git -C "$dest" --no-pager show --stat --oneline HEAD >&2 || true

    if [ "$push" -eq 1 ]; then
      err "push します..."
      git -C "$dest" push
    else
      err "push は未実行です。確認後に 'git -C \"$dest\" push' するか --push を付けてください。"
    fi
  '';
}
