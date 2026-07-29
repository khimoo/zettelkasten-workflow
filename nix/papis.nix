# papis(参照文献マネージャ)本体・宣言的設定・ライブラリの Google Drive 同期。
# services.zettelkasten.papis.enable が真のときだけ config を出す(options は hm-module.nix が宣言)。
#
# papis ライブラリ(info.yaml と PDF が item ごとに同居)を丸ごと bisync することで、メタデータ
# (平文 yaml)も PDF バイトも 1 系統で同期する。ディレクトリ名は同期 backend でもツール名でもなく
# 参照文献マネージャという安定ドメイン(papis)で付ける。backend 差し替えは sync-script の
# 差し替えで済み、programs.papis 設定は不変。
#
# rclone 認証情報は各マシンの ~/.config/rclone/rclone.conf に委ねる(添付同期と同一の経路)。
{ config, lib, pkgs, ... }:

let
  cfg = config.services.zettelkasten;

  # 添付同期と同じ実体を --only papis で呼ぶ(同期ロジックを対象ごとに複製しない)。
  syncScript = import ./sync-script.nix { inherit pkgs; };
in
{
  config = lib.mkIf (cfg.enable && cfg.papis.enable) {
    # ---- 層1: 宣言的な設定の抜けを eval 時に検知する ----
    assertions = [
      {
        assertion = cfg.papis.libraryDir != "";
        message = "services.zettelkasten.papis.libraryDir を設定してください(同期対象が特定できません)。";
      }
    ];

    # programs.papis.enable が pkgs.papis 本体も home.packages に入れる。
    # citekey は各 item の info.yaml の `ref:` に手動 pin する運用(自動 ref-format は設定しない)。
    programs.papis = {
      enable = true;
      settings.opentool = cfg.papis.opentool;
      libraries.library = {
        isDefault = true;
        settings.dir = cfg.papis.libraryDir;
      };
    };

    # 同期コマンドは attachments 側でも同じものを入れる。同一 derivation なので重複しても実害はない。
    home.packages = [ syncScript ];

    # Linux: oneshot 同期 + path unit(イベント駆動) + timer(定期バックストップ)。
    # ライブラリ未作成(papis add 前)は ConditionPathIsDirectory で skip する。
    systemd.user.services.papis-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "papis ライブラリを Google Drive へ bisync する(oneshot)";
        ConditionPathIsDirectory = cfg.papis.libraryDir;
        After = cfg.after;
        Wants = cfg.wants;
      };
      Service = {
        Type = "oneshot";
        Environment = [ "ZETTELKASTEN_ROOT=${cfg.zettelkastenRoot}" ];
        ExecStart = "${lib.getExe syncScript} --only papis";
      };
    };

    systemd.user.paths.papis-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "papis ライブラリの変更を監視して同期をトリガする";
      Path = {
        PathModified = cfg.papis.libraryDir;
        Unit = "papis-sync.service";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.papis-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "papis ライブラリ同期の定期バックストップ";
      Timer = {
        OnActiveSec = "30s";
        OnUnitActiveSec = "${toString cfg.papis.intervalSeconds}s";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Darwin: launchd の WatchPaths(イベント駆動) + StartInterval(定期) + RunAtLoad(初回)。
    launchd.agents.papis-sync = lib.mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe syncScript) "--only" "papis" ];
        RunAtLoad = true;
        WatchPaths = [ cfg.papis.libraryDir ];
        StartInterval = cfg.papis.intervalSeconds;
        EnvironmentVariables.ZETTELKASTEN_ROOT = cfg.zettelkastenRoot;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/papis-sync.log";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/papis-sync.log";
      };
    };
  };
}
