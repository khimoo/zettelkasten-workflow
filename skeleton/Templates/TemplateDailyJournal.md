---
tags:
- "Daily-note"
---
```journal-nav
```

```dataviewjs
const d = moment(dv.current().file.name, "YYYY-MM-DD");
// 週次レビュー（月曜に実施。未実施の間は毎日催促）
const week = d.format("gggg-[W]ww");
const weekDone = dv.page(`Reviews/${week}`);
if (d.isoWeekday() === 1) {
  dv.paragraph(weekDone
    ? `✅ 週次レビュー済み → [[Reviews/${week}]]`
    : `📋 **今日は週次レビューの日** → [[Reviews/${week}]] を作る（先週分の実績列も締める）`);
} else if (!weekDone) {
  dv.paragraph(`⚠️ 今週の週次レビューが未実施 → [[Reviews/${week}]]`);
}
// 月次レビュー（月初に実施。未実施の間は毎日催促）
const month = d.format("YYYY-MM");
const monthDone = dv.page(`Reviews/${month}`);
if (d.date() === 1) {
  dv.paragraph(monthDone
    ? `✅ 月次レビュー済み → [[Reviews/${month}]]`
    : `📋 **今日は月次レビューの日** → [[Reviews/${month}]] を作る`);
} else if (!monthDone) {
  dv.paragraph(`⚠️ 今月の月次レビューが未実施 → [[Reviews/${month}]]`);
}
```

### 習慣
- [ ] メール,Discord,slack,manaba,twins,teams確認 #daily
- [ ] 数学 #daily

### [[Tasks]]

今日中
```tasks
not done
due on or before {{date:YYYY-MM-DD}}
ignore global query
```

締切りすぎてます
```tasks
not done
happens before {{date:YYYY-MM-DD}}
```

今日生えたやつ
```tasks
not done
(created on {{date:YYYY-MM-DD}}) OR (scheduled on {{date:YYYY-MM-DD}})
```

終わってないやつ
```tasks
not done
```

車使いたい
```tasks
ignore global query
not done
tags include 車
sort by created
```

### 関連ノート
#### バックリンク
```dataviewjs
const currentPath = dv.current().file.path;
const backlinkPages = dv.pages().where(p => 
  p.file.outlinks && p.file.outlinks.some(link => link.path === currentPath) && p.file.path !== currentPath
);

// YAMLなどで明示的に記載されたタグを取得（存在しない場合は空配列）
function getExplicitTags(page) {
  return Array.isArray(page.tags) ? page.tags : [];
}

// 任意の深さに対応した階層タグのフィルタリング関数
function filterHierarchicalTags(allTags, explicitTags) {
  // 重複を避けるためユニークな配列にする
  const uniqueTags = [...new Set(allTags)];
  return uniqueTags.filter(tag => {
    // 明示的に指定されていれば必ず表示
    if (explicitTags.includes(tag)) return true;
    // 明示的でない場合、同じタグを接頭辞に持つ子タグが存在すれば親タグは除外
    return !uniqueTags.some(other => other !== tag && other.startsWith(tag + "/"));
  });
}

if (backlinkPages.length === 0) {
  dv.paragraph("*No Backlink Found*");
} else {
  dv.table(
    ["タイトル", "タグ"],
    backlinkPages.map(p => {
      const explicit = getExplicitTags(p);
      const displayTags = Array.isArray(p.file.tags)
        ? filterHierarchicalTags(p.file.tags, explicit).join(", ")
        : (p.file.tags || "");
      return ["[[" + p.file.name + "]]", displayTags];
    })
  );
}
```
#### 作成されたページ
```dataviewjs
// Get current date from filename
const targetDate = moment(dv.current().file.name, "YYYY-MM-DD");

// Filter pages created on the target date (excluding current page)
const pagesCreatedToday = dv.pages().filter(p => {
  if (!p.created) return false;
  
  const createdDate = moment(p.created, ["YYYY-MM-DD HH:mm:ss", "YYYY-MM-DD"]);
  return createdDate.isValid() && 
         createdDate.isSame(targetDate, "day") && 
         p.file.path !== dv.current().file.path;
});


// YAMLなどで明示的に記載されたタグを取得（存在しない場合は空配列）
function getExplicitTags(page) {
  return Array.isArray(page.tags) ? page.tags : [];
}

// 任意の深さに対応した階層タグのフィルタリング関数
function filterHierarchicalTags(allTags, explicitTags) {
  // 重複を避けるためユニークな配列にする
  const uniqueTags = [...new Set(allTags)];
  return uniqueTags.filter(tag => {
    // 明示的に指定されていれば必ず表示
    if (explicitTags.includes(tag)) return true;
    // 明示的でない場合、同じタグを接頭辞に持つ子タグが存在すれば親タグは除外
    return !uniqueTags.some(other => other !== tag && other.startsWith(tag + "/"));
  });
}

// 表示処理
if (pagesCreatedToday.length === 0) {
  dv.paragraph("*No Page Created*");
} else {
  dv.table(
    ["タイトル", "タグ"],
    pagesCreatedToday.map(p => {
      const explicit = getExplicitTags(p);
      const displayTags = Array.isArray(p.file.tags)
        ? filterHierarchicalTags(p.file.tags, explicit).join(", ")
        : (p.file.tags || "");
      return ["[[" + p.file.name + "]]", displayTags];
    })
  );
}
```
#### 更新されたページ
```dataviewjs
// Get current date from filename
const targetDate = moment(dv.current().file.name, "YYYY-MM-DD");

// Filter pages modified on the target date (excluding current page)
const pagesModifiedToday = dv.pages().filter(p => {
  if (!p.modified) return false;
  
  const modifiedDate = moment(p.modified, ["YYYY-MM-DD HH:mm:ss", "YYYY-MM-DD"]);
  return modifiedDate.isValid() && 
         modifiedDate.isSame(targetDate, "day") && 
         p.file.path !== dv.current().file.path;
});

function getExplicitTags(page) {
  return Array.isArray(page.tags) ? page.tags : [];
}

// 任意の深さに対応した階層タグのフィルタリング関数
function filterHierarchicalTags(allTags, explicitTags) {
  // 重複を避けるためユニークな配列にする
  const uniqueTags = [...new Set(allTags)];
  return uniqueTags.filter(tag => {
    // 明示的に指定されていれば必ず表示
    if (explicitTags.includes(tag)) return true;
    // 明示的でない場合、同じタグを接頭辞に持つ子タグが存在すれば親タグは除外
    return !uniqueTags.some(other => other !== tag && other.startsWith(tag + "/"));
  });
}

// Display results
if (pagesModifiedToday.length === 0) {
  dv.paragraph("*No Page Modified*");
} else {
  dv.table(
    ["タイトル", "タグ"],
    pagesModifiedToday.map(p => {
      const explicit = getExplicitTags(p);
      const displayTags = Array.isArray(p.file.tags)
        ? filterHierarchicalTags(p.file.tags, explicit).join(", ")
        : (p.file.tags || "");
      return ["[[" + p.file.name + "]]", displayTags];
    })
  );
}
```
### 雑記
