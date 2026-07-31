---
created: 2026-07-10 01:00:26
modified: 2026-07-10 01:00:26
---
AIが生成・執筆した知識ノートの一覧。frontmatterの `ai_generated` プロパティをdataviewが自動収集する。

**使い方**: 下の一覧からノートを開き、手動で再調査して自分の言葉で書き直す。終わったらそのノートの `ai_generated` プロパティを削除する → この一覧から自動で消える。本文中の `⚠️未検証:` の目印は、AIが一次情報を確認できなかった記述。

```dataview
TABLE ai_generated AS 生成日
WHERE ai_generated AND !contains(file.path, "Reading/")
SORT ai_generated ASC
```

運用ルールの詳細は CLAUDE.md を参照。
