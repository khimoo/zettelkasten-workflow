---
type: monthly-review
period: "{{date:YYYY-MM}}"
start: "{{start_date:YYYY-MM-DD}}"
end: "{{end_date:YYYY-MM-DD}}"
---

```journal-nav
```

# {{date:YYYY-MM}} 月次レビュー

## 各ゴールの状態（1行）
- [[数学セミナー]]:
- [[ゲーム制作]]:
- [[ピアノ・ジャズ]]:
- [[Zettelkasten整備]]:

## 今月の主役（WIP 1〜2ゴール）と脇役（維持のみ）
- 主役（wip中）: 
- 維持: 
- （※月次では決め直さない。主役の切替は Goals の wip フラグで随時。重点配分は週次で）

## 各ゴールの今月フォーカス（lag に近づく一歩）
- [[数学セミナー]]:
- [[ゲーム制作]]:
- [[ピアノ・ジャズ]]:
- [[Zettelkasten整備]]:

## 今月の週次レビュー
```dataview
LIST
FROM "Reviews"
WHERE type = "weekly-review" AND start >= "{{start_date:YYYY-MM-DD}}" AND start <= "{{end_date:YYYY-MM-DD}}"
SORT start ASC
```

## 来月へ
- 
