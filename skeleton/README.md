---
created: 2026-07-19 01:34:33
modified: 2026-07-31 22:46:24
---
# スリップボックス運用ガイド

生涯にわたって育てる単一の **Zettelkasten（スリップボックス）**。方法論は
[zettelkasten.de](https://zettelkasten.de/introduction/) に準拠する。この vault は
**テキスト中心・軽量**に保ち、PDF などの資料実体は git に入れない（papis が持ち、
Google Drive へ同期する。後述）。

- **方法論そのもの**の入口は [[IndexNote]]（"Zettelkasten入門"）。
- この README は、その方法論を**この vault でどう操作・運用するか**を補う実務ガイド。

---

## 1. 全体構造（ディレクトリの役割）

| 場所 | 役割                                                                                                                           |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Zettel/` | **恒久ノート（原子ノート）**の平坦な置き場。1ノート＝1つの完結した考え。フォルダ分類はせず、`[[ノート名]]` の相互リンクと構造ノートで構造を与える。                                             |
| （構造ノート） | **ハブ（構造ノート）**＝Zettel を束ねた目次。専用フォルダは設けず、必要になったら `Zettel/` 内に他の Zettel と並べて1枚作る（カテゴリ／タグの代わりの"入口"）。                             |
| `IndexNote.md` | 最上位の入口。方法論と全体マップを兼ねる。                                                                                                        |
| `Registry/` | **台帳**。vault 全体に対して「これを正とする」一覧・取り決めの置き場（記法の取り決め、信頼する一次資料の登録簿、書き直し待ちの一覧）。個々の考えではなく、考えを書くときに参照する規約が入る。 |
| `FleetingNote/` | **インボックス**。思いつき・下書き・読書メモ・リスト等の未処理素材。処理して Zettel 化するか捨てる。                                                                     |
| `FleetingNote/未分類/` | **体系的な学習メモ**（Rust・環境設定など）の一時置き場。slip-box に入れる前段。価値ある断片を Zettel へ蒸留し、残りは素材として保持する。                                     |
| `Reading/` | 資料を読みながら手を動かす**作業場**。`Reading/<分野>/<書名>/…` に章メモ・行間埋め・演習を置く。Tasks と AI下書き一覧からは除外され、日常と archive を汚さない。運用は [[Reading/Reading運用ルール]]。 |
| `BufferNotes/` | 自分のノートに対する**リーディングリスト**。試験前・執筆前に必要な要素を先に集めておく一時ノート。                                                                          |
| `Drafts/` | **外に出す原稿**。`Zettel/` へ蒸留するための素材（`FleetingNote/`）ではなく、それ自体を完成させて公開・提出する長文。`BufferNotes/` で集めた要素をここで書く。 |
| `Dailies/` | **日次ノート**（Journals プラグインで生成）。その日のタスク集約と「作成/更新されたノート」一覧を自動表示する処理ログ。検索・グラフからは除外設定。                                             |
| `Reviews/` | **週次・月次レビュー**（Journals で生成）。`YYYY-Www`＝週次、`YYYY-MM`＝月次。4ゴールを定期的に俯瞰する振り返りログ。                                                  |
| `Goals/` | **長期ゴール**。各ノートに lag指標（結果）／lead指標（行動）／今月フォーカスを持つ。`wip` フラグで「今月の主役」を選ぶ。                                        |
| `Tasks/` | obsidian-tasks によるタスク管理。ダッシュボードは [[Tasks]]、終えたリストは `Tasks/archive/` へ移す。目印（📅 ⏬ `#daily` 等）と globalQuery の運用は [[Tasks/タスク運用ルール]]。 |
| `Clippings/` | Web クリップ（未処理の外部素材）。                                                                                                          |
| `Resources/` | **実務リファレンスの棚**（住居・学校・家電など、必要なとき正確に引く事実）。Zettelkasten 方法論の対象外で、zettel 化もタグ付けも wikilink 接続もしない。運用は [[Resources/README]]。 |
| `Templates/` | テンプレート。日次・週次・月次を Journals が参照する Markdown テンプレ（`TemplateDailyJournal.md` / `TemplateWeeklyReview.md` / `TemplateMonthly.md`）と、`Resources/` 用の `TemplateResource.md`。 |
| `attachments/` | 画像などの添付（`attachmentFolderPath`）。git 追跡せず Google Drive へ rclone bisync で同期する（`.gitignore` で除外）。                               |
| `references/` | papis の参照文献ライブラリ（`info.yaml` + PDF）。git 追跡せず Google Drive へ rclone bisync で同期する（`.gitignore` で除外）。                          |

**原則としてフォルダは"分類器"ではない。** Zettel はすべて `Zettel/` に平坦に置き、
意味的なまとまりは構造ノートとリンクで表現する（zettelkasten.de の
「カテゴリを使わない」方針）。

**体系的に覚えたい知識（教科書・講義の学習メモ）は slip-box ではない。** これらは
「自分の言葉による原子ノート」ではなく、暗記・整理のために体系立てて纏める別目的の
素材なので `Zettel/` には入れない。退避先は `FleetingNote/未分類/`。

旧サブフォルダ構造のまま置き、そこから価値ある断片だけを**自分の言葉で**
`Zettel/` に蒸留してリンクでつなぐ（素材はそのまま素材として残してよい）。

```
素材ノート（体系メモ・講義資料） ──蒸留──▶ Zettel/（原子的・自分の言葉・リンク）
   FleetingNote/未分類/
```

**slip-box の外側にも場所がある。** 次の3つは Zettel 化を目的にしない。

- `Reading/` — 資料を読みながら手を動かす作業場。理解は `Zettel/` へ、記憶は Anki へ渡し、
  作業の跡だけがここに残る。
- `Resources/` — 実務の参照情報の棚。引くための事実であって、考えではない。
- `Tasks/` — 行動の管理。「要再調査」のようなノートの状態はチェックボックスではなく
  frontmatter で表す（Tasks プラグインが vault 全体の `- [ ]` を拾うため）。

細目は各フォルダの規約ノートが持つ（[[Reading/Reading運用ルール]] / [[Resources/README]] /
[[Tasks/タスク運用ルール]]）。この README は「どこに何があるか」までを引き受け、中身を二重に書かない。

---

## 2. 前提とする道具立て

- **Obsidian** + コミュニティプラグイン: Dataview / Tasks / **Journals**（日次・週次・月次ノート）/
  Linter / **Obsidian Git** / **Typst Mate**。数式は Typst 記法で書く（後述）。
- **リンクは wikilink `[[ ]]`**（`useMarkdownLinks: false`）。`alwaysUpdateLinks` が
  有効なので、**ノートを改名してもリンクは自動追従**する（＝リンクはファイル名で解決）。
- **バックアップは Obsidian Git**。"Create backup" で `vault backup: <日時>` という
  コミットを作り push、起動時に pull（自動 push 間隔は 0＝手動運用）。
- **参照文献は papis**。ライブラリ（`info.yaml` + PDF）は vault 直下の `references/` に置き、
  git では追跡せず Google Drive へ同期する。本文からは **citekey `[@citekey]`** で参照する。
- **清書は typst**。体系立てて"まとめたくなった"ら vault の外の別プロジェクトで
  `.typ` に清書し、`#cite(<citekey>)` で文献を引く。

---

## 3. 中核となる原則

1. **単一の箱**：分野ごとに箱を分けず、生涯ひとつの Zettelkasten を育てる。
2. **カテゴリで分類しない**：フォルダやタグをトップダウンの分類体系にしない。
3. **原子性**：1ノートは単独で完結した1つの考え。正確には**1つの knowledge building
   block**（Concept／Argument／Counter-argument／Model／Hypothesis・Theory／Empirical
   observation のどれか一つ）で、object を主題にすること自体は失格ではない。[^1]
4. **接続性**：関連は**リンク**で表す。連想でつなぐことに意味がある。
5. **写経しない**（collector's fallacy）：資料を丸写しせず、**自分の言葉で作り直す**。
6. **溜まったら束ねる**：ノートが増えたら構造ノートを作る。タグは主軸にしない
   （数学・プログラミングのような体系的分野は typst で清書する方が相性が良い）。
7. **資料はパスでなく citekey で参照**：資料が移動・改名・別マシン同期しても壊れない。

---

## 4. 想定ワークフロー

```
  捕捉        処理         恒久化        接続          構造化        清書
Fleeting → 見返して選別 → Zettel化 → [[リンク]] → 構造ノート → typst
 Daily      (自分の言葉に)  (原子的に)   (関連へ接続)  (溜まったら束ねる) (文献は[@key])
  紙
```

1. **捕捉**：思いついたら `FleetingNote/` か当日の Daily、あるいは紙にすぐ書く。整形不要。
2. **処理**：定期的に `FleetingNote/` を見返し、残す価値のあるものだけを選ぶ。
3. **恒久化**：それを**自分の言葉で** `Zettel/` に原子ノートとして書き直す。
4. **接続**：関連する既存 Zettel へ `[[ ]]` でリンクする（少なくとも1本はつなぐ）。
5. **構造化**：同種のノートが溜まったら `Zettel/` 内に構造ノート（他の Zettel を束ねる
   目次ノート）を1枚作り、`[[ ]]` を並べる。専用フォルダは設けない。
6. **清書**：まとめたくなったら typst で正式文書に清書し、文献は `[@citekey]` /
   `#cite(<citekey>)` で引く。

---

## 5. 進捗管理（4ゴールの並行運用）

長期のゴールを並行して育てる。記憶は vault 自身に置き、Journals の
定期ノートで回す。

- **メモリの置き場**：ゴール本体は `Goals/`、振り返りは `Reviews/`。
- **リズム（Journals）**：Daily（朝会）→ Weekly（実行レビュー）→ Monthly（俯瞰）。
- **lag / lead の分離**：`lag`＝結果（コントロール不可・遅れて動く）、
  `lead`＝日々動かせる行動（コントロール可）。振り返りは lead を回せたかで見る。
- **WIP 制限**：同時に本気を出す「主役」は 1〜2 ゴールに絞る（`Goals` の `wip` フラグ）。
  残りは維持のみ。
- **今週の粒度タスクは当面「仕組み化しない」（A方式）**：「今週やること」の細かい粒度は、
  週次レビューの lead スコアボード（`実績` を埋める）＋日次ノートへの書き捨て
  （`useFilenameAsScheduledDate` の暗黙 scheduled）で回す。週ごとに手書きチェックリストを
  作って翌週へ繰り越す運用（Bullet Journal のマイグレーション）はしない。
  - **将来の仕組み化候補（目処が立てば）**：ゴール名タグ（例 `#g/数学`）＋ Dataview/Tasks で
    「ゴール別の未消化タスク」を週次ノートに自動集約する。繰り越しはクエリ任せ＝単一ソース・
    手作業ゼロ。着手条件は「lead スコアボードだけでは具体を取りこぼす」と実感したとき。
    『まず軽量に回す・ツールを先に作り込まない』に従い、先回りして作らない。
- **カレンダー連携は未確定（運用しながら決める）**：週次で立てたタイムブロックを
  外部カレンダー（Google Calendar 等）へどう落とすかは、いま固定しない。まず手動・
  軽量に回し、運用の中で必要な連携方法・自動化の要否を見つける。ツールを先に作り込まない。

---

## 6. 操作例

### A. Fleeting を1件捕捉する
`FleetingNote/` に新規ノートを作り、思いつきをそのまま書く。粗くてよい。
（例: `FleetingNote/自分はなぜRustが好きなのか.md`）

### B. Fleeting → Zettel に昇格する
断片を、単独で読んで意味が通る**原子ノート**に書き直して `Zettel/` へ。末尾に関連リンクを付ける。

```markdown
# Zettel/continuumの可算減少列の収束先はcontinuum.md
[[continuum]] の減少列 $C_1 ⊇ C_2 ⊇ …$ の共通部分もまた continuum になる
```

要点は「元テキストの引き写し」ではなく「自分の言葉での再構成」であること。

### C. ノートをリンクする
本文中・末尾で `[[topology space]]` のように参照する。リンク先を後で改名しても
`alwaysUpdateLinks` が追従するので壊れない。

### D. 構造ノートに載せる
まとまってきたら `Zettel/` 内に構造ノート（例: `Zettel/連結性.md`）を1枚作り、
他の Zettel と並べて見出し＋リンクを足す。専用フォルダは作らない。

```markdown
# Zettel/連結性.md
## 連結性まわり
- [[連結空間の連続像は連結]]
- [[連結空間の直積空間も連結]]
```

### E. 文献を引用する
1. `papis add` で資料を取り込み、その item の `info.yaml` の `ref:` に citekey を pin する。
2. Zettel 本文で `[@citekey]` と書く。typst 清書では `#cite(<citekey>)`。

例: ある Zettel の末尾に `[@hottbook]` と書けば、その考えの出典（HoTT Book）を
citekey で示せる（PDF 実体は `references/` にあり、ノート本文は citekey だけを持つ）。
**PDF のファイル名や `[[○○.pdf]]` では参照しない。**

### F. Daily / レビューノートを作る
日次・週次・月次はすべて **Journals** プラグインで生成する（旧 Templater 方式は廃止）。
当日締切タスクの集約と、その日に作成/更新したノート一覧が自動で並ぶ（日次）。
週次 `YYYY-Www`・月次 `YYYY-MM` は `Reviews/` に生成され、4ゴールの状態を振り返る。

### G. バックアップする
Obsidian Git の "Create backup" コマンドを実行 → `vault backup: <日時>` で
コミット＋push。

---

## 7. 命名・記法の約束

- **ファイル名がリンクキー**：Zettel は一意な名前を付ける。衝突する場合は括弧で
  曖昧性を除去する（例: `開基 (卒業予備研究)`）。
- **数式・記号は本文に直接書く**。記法は **Typst**（`$…$` / `$$…$$` の中身を
  Typst Mate が描画する）。LaTeX 記法は使わない。対応表は CLAUDE.md を参照。
- **文献参照は pandoc 形式 `[@citekey]`**。ファイルパスや `[[*.pdf]]` は使わない。
- **タグは限定用途**（Daily-note など）。分類の主役にはしない。

---

## 8. 参照文献システム（papis）との関係

```
スリップボックス (この vault, テキスト)        typst プロジェクト
        │  [@citekey] で参照                        │  #cite(<citekey>)
        └──────────────►  papis  ◄──────────────────┘
                     （citekey ↔ PDF 実体）
                            │
                   references/ ──► Google Drive 同期
                   （info.yaml + PDF、git 管理外）
```

資料の**実体は git の外**にあり、ノート本文は citekey だけを持つ。取り込み・同期の
仕組みは zettelkasten-workflow を参照。

`.obsidian/workspace*.json` は環境依存のため git 管理外（`.gitignore`）。

[^1]: https://zettelkasten.de/atomicity/guide/ — 原文: "In short, it is about putting one idea and one idea only on a note." / "Concepts define a specific part of the world. You draw a boundary and say, 'This is X.' Arguments transfer the truth of a set of statements to another via a logical structure. Counter-arguments disrupt the transfer of truth provided by arguments. Models relate entities to each other and provide part-to-part relationships and part-to-whole relationships, often to map a part of reality or a fictional reality. Hypotheses and theories formulate statements on how reality actually is. Empirical observations are results of sensory probing on how reality actually is."
