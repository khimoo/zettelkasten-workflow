# sanitize 済み .obsidian(Obsidian 設定 + community plugin 本体)を store path として提供する。
# seed-obsidian(HM activation)がこれを vault にコピーして「clone してそのまま動く」状態を作る。
#
# ここに含まれるのは再現に必要な設定・プラグインのみ。sanitize は上流の mirror-obsidian が 2 段
# (vault の .gitignore + 配布境界での除去)で済ませており、ノート本文・workspace.json・bookmark・
# 名前付きレイアウトはその過程で落ちている。よってここは repo の .obsidian をそのまま store に載せる。
{ pkgs }:

pkgs.runCommandLocal "obsidian-config" { } ''
  cp -r ${../.obsidian} $out
''
