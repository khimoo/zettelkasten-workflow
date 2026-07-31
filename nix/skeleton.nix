# 新品の vault がどう見えるか——骨格一式を store path として提供する。
# seed-vault(HM activation)がこれを vault へ非破壊コピーして「switch してそのまま動く」状態を作る。
#
# 中身は2種類ある。.obsidian(Obsidian 設定 + community plugin 本体)と、ノートの分類フォルダ・
# 運用ドキュメント。どちらも上流の mirror-vault が sanitize 済みで、個人のノート本文・
# workspace.json・bookmark はその過程で落ちている。よってここは repo の skeleton/ を
# そのまま store に載せる。
{ pkgs }:

pkgs.runCommandLocal "vault-skeleton" { } ''
  cp -r ${../skeleton} $out
''
