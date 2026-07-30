# vault に .obsidian 設定を非破壊で配置(seed)するスクリプト。module の activation が呼ぶ。
# vault パスは第1引数か ZETTELKASTEN_ROOT で受け取る(依存性逆転)。
#
# 非破壊(seed-once)の契約:
#   - vault の .obsidian が既にあれば何もしない(既存の live 設定を上書きしない)
#   - vault ディレクトリ自体が無ければ warning を出して skip(まだノート repo を clone していない
#     fresh マシンでも switch を失敗させない。clone 後に再 switch すれば seed される)
{ pkgs, obsidianConfig }:

pkgs.writeShellApplication {
  name = "seed-obsidian";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    vault="''${1:-''${ZETTELKASTEN_ROOT:-}}"

    if [ -z "$vault" ]; then
      echo "seed-obsidian: vault パスが未指定です。" >&2
      echo "  → 第1引数か環境変数 ZETTELKASTEN_ROOT で vault(絶対パス)を渡してください。" >&2
      echo "    例: nix run github:khimoo/zettelkasten-workflow#seed-obsidian -- /path/to/vault" >&2
      exit 1
    fi

    if [ ! -d "$vault" ]; then
      echo "seed-obsidian: vault が未 clone です(skip): $vault" >&2
      echo "  → ノートの private repo を clone してから再実行すれば .obsidian を配置します。" >&2
      exit 0
    fi

    dest="$vault/.obsidian"
    if [ -e "$dest" ]; then
      echo "seed-obsidian: $dest は既に存在します(skip)。既存設定は上書きしません。" >&2
      exit 0
    fi

    cp -r ${obsidianConfig} "$dest"
    chmod -R u+w "$dest"
    echo "seed-obsidian: .obsidian を配置しました: $dest" >&2
  '';
}
