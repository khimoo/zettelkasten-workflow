# papis ライブラリを Google Drive へ双方向同期するスクリプト。
# 本体は nix/bisync-lib.nix が持ち、ここは papis 同期固有の spec を渡すだけの薄いラッパー。
# home-manager の watcher 常駐(papis.nix)と手動実行の両方がこれを使う。baseline は添付同期
# (bisync-zettelkasten)と分離するため bisync-papis に固定する。
{ pkgs, defaultRemote ? "gdrive:papis-library" }:

import ./bisync-lib.nix { inherit pkgs; } {
  name = "papis-sync";
  dirEnv = "PAPIS_LIBRARY_DIR";
  remoteEnv = "PAPIS_REMOTE";
  forceResyncEnv = "PAPIS_FORCE_RESYNC";
  baselineName = "bisync-papis";
  inherit defaultRemote;
  dirLabel = "papis ライブラリ";
  exampleDir = "/path/to/vault/references";
  createHint = "パスを確認するか、まず papis add で item を1件追加してライブラリを作成してください。";
}
