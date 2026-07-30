# cfg から同期コマンドを組み立てる。hm-module.nix と papis.nix の両方がこれを呼ぶ。
# 同じ引数なら同じ derivation になるので、PATH に載る実体と unit が起動する実体は1つに収束する
# ——組み立て式を2か所に書くと、片方だけ直したときに静かに別物へ分岐する。
{ pkgs, cfg }:

import ./sync-script.nix {
  inherit pkgs;
  inherit (cfg) rcloneRemote;

  attachments =
    if cfg.attachments.enable
    then { inherit (cfg.attachments) dir folder; }
    else null;

  papis =
    if cfg.papis.enable
    then { dir = cfg.papis.libraryDir; inherit (cfg.papis) folder; }
    else null;
}
