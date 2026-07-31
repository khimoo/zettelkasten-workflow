# 配布する vault の骨格。vault からの相対パスで列挙する。
#
# 使うのは mirror-vault だけ。seed-vault は skeleton/ の木をそのまま歩くので、この列挙を
# 参照しない(列挙が2箇所にあると必ずずれる)。skeleton/ は成果物で、ここはその作り方。
#
# denylist ではなく allowlist にしているのは、vault が tracked にしているものの大半
# (Zettel/ Dailies/ Goals/ …)が個人のノートで、足し忘れが「漏れる」方向に倒れるため。
# 配ると決めたものを列挙する側に倒す。
#
# .obsidian はここに含めない。あちらは `git ls-files .obsidian` の全 tracked から denylist を
# 引く別系統で、Obsidian が勝手に増やすファイルを追随する必要があるため。
{
  # 中身ごと配るファイル。vault に無ければ mirror は中止する(黙って落とすと repo から消える)。
  files = [
    "README.md"
    "IndexNote.md"
    "CLAUDE.md"

    "Templates/TemplateDailyJournal.md"
    "Templates/TemplateWeeklyReview.md"
    "Templates/TemplateMonthly.md"
    "Templates/TemplateResource.md"

    # 各フォルダの規約ノート。README は「どこに何があるか」までしか持たず、細目はこちらにある。
    "Tasks/タスク運用ルール.md"
    "Resources/README.md"
    "Reading/Reading運用ルール.md"
    "Reading/math/数学書精読ルール.md"

    # dataview クエリと運用ルールだけで、個人の内容を持たない。
    "Registry/AI下書き一覧.md"

    ".claude/skills/lint-zettel/SKILL.md"
  ];

  # 空で配るフォルダ(.gitkeep で git に載せる)。中身は各自のノートなので運ばない。
  # attachments と references は同期ジョブの ConditionPathIsDirectory が要求するため、
  # 空でも存在させる必要がある。
  dirs = [
    "Zettel"
    "Registry"
    "FleetingNote"
    "FleetingNote/未分類"
    "Reading"
    "Reading/math"
    "BufferNotes"
    "Drafts"
    "Dailies"
    "Reviews"
    "Goals"
    "Tasks"
    "Tasks/archive"
    "Clippings"
    "Resources"
    "Templates"
    "attachments"
    "references"
  ];
}
