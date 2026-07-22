# Zettelkasten の添付フォルダを Google Drive へ双方向同期するスクリプト。
# 本体は nix/bisync-lib.nix が持ち、ここは添付同期固有の spec を渡すだけの薄いラッパー。
# home-manager モジュール(watcher 常駐)と `nix run`(ワンショット)の両方がこれを使う。
{ pkgs, defaultRemote ? "gdrive:zettelkasten-attachments" }:

import ./bisync-lib.nix { inherit pkgs; } {
  name = "zettelkasten-sync";
  dirEnv = "ZETTELKASTEN_ATTACHMENTS_DIR";
  remoteEnv = "ZETTELKASTEN_REMOTE";
  forceResyncEnv = "ZETTELKASTEN_FORCE_RESYNC";
  baselineName = "bisync-zettelkasten";
  inherit defaultRemote;
  dirLabel = "添付フォルダ";
  exampleDir = "/path/to/vault/attachments";
  createHint = "パスを確認するか、まず Obsidian で画像を1枚貼り付けてフォルダを作成してください。";
}
