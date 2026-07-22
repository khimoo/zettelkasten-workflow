# sanitize 済み .obsidian(Obsidian 設定 + community plugin 本体)を store path として提供する。
# seed-obsidian(app / HM activation)がこれを vault にコピーして「clone してそのまま動く」状態を作る。
# ここに含まれるのは再現に必要な設定・プラグインのみで、ノート本文や private なパス(workspace.json /
# bookmark / レイアウトに開いていたノート)は上流で除外/空化済み。
{ pkgs }:

pkgs.runCommandLocal "obsidian-config" { } ''
  cp -r ${../.obsidian} $out
''
