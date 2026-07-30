# Zettelkasten(Obsidian vault)の完結型 home-manager モジュール。
# vault のための機能——添付フォルダの Google Drive 同期と papis(参照文献)ライブラリの
# 設定・同期——を一括で所有する。どのマシンでも zettelkasten flake を import し、vault の
# clone 先(zettelkastenRoot)を注入するだけで、同一の
# Obsidian ワークフローが立ち上がる。
#
# rclone 認証情報はこのモジュールの管轄外。各マシンで `rclone config` が作った
# ~/.config/rclone/rclone.conf を rclone 自身が既定で解決する。
#
# 添付(attachments)と papis はそれぞれ独立した sub-toggle で個別に有効化でき、bisync の
# workdir を分離してベースラインを混ぜない。papis 側の config は ./papis.nix が持つ
# (options はここで一括宣言し、papis.nix は config だけを提供する)。
{ config, lib, pkgs, ... }:

let
  cfg = config.services.zettelkasten;

  # 添付と papis で同じ実体。unit は監視対象ごとに分かれるので --only で片方に絞る。
  # 同期先は options から eval 時に焼き込む(実行時に設定を読む層は無い)。
  syncScript = import ./sync-for-cfg.nix { inherit pkgs cfg; };

  # vault へ .obsidian を非破壊コピーする(既に .obsidian があれば何もしない)。
  seedObsidian = import ./seed-obsidian.nix {
    inherit pkgs;
    obsidianConfig = import ./obsidian-config.nix { inherit pkgs; };
  };

  # vault の tracked .obsidian を config repo へミラーする(seed の逆向き)。
  # PATH には mirrorRepo が非 null のときだけ載せ、vault と dest を env 既定として焼き込む
  # (引数/env で上書き可能。--set-default なので外から与えた env が優先)。
  mirrorObsidian = import ./mirror-obsidian.nix { inherit pkgs; };
  mirrorObsidianWrapped = pkgs.symlinkJoin {
    name = "mirror-obsidian-wrapped";
    paths = [ mirrorObsidian ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/mirror-obsidian \
        --set-default ZETTELKASTEN_ROOT ${lib.escapeShellArg cfg.zettelkastenRoot} \
        --set-default OBSIDIAN_CONFIG_REPO ${lib.escapeShellArg (toString cfg.obsidian.mirrorRepo)}
    '';
  };
in
{
  imports = [ ./papis.nix ];

  options.services.zettelkasten = {
    enable = lib.mkEnableOption "Zettelkasten(Obsidian vault)の完結型ワークフロー(添付同期 + papis)";

    zettelkastenRoot = lib.mkOption {
      type = lib.types.str;
      example = "/home/alice/zettelkasten";
      description = ''
        vault(Obsidian)の clone 先絶対パス。attachments/ と papis の references/ の親。
        これがマシン固有の唯一の設定で、消費側(flake_public 等)がホスト毎に注入する。
      '';
    };

    rcloneRemote = lib.mkOption {
      type = lib.types.str;
      default = "gdrive";
      description = ''
        同期先の rclone remote 名(`rclone config` で作ったもの)。
        認証情報はこのモジュールの管轄外で、~/.config/rclone/rclone.conf に置かれる。
      '';
    };

    after = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "network-online.target" ];
      description = "同期サービスの After。起動順序の依存を消費側から注入する穴。";
    };

    wants = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "network-online.target" ];
      description = "同期サービスの Wants。";
    };

    attachments = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Obsidian 添付フォルダの Google Drive 双方向同期を有効化する。";
      };

      dir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.zettelkastenRoot}/attachments";
        defaultText = "\${zettelkastenRoot}/attachments";
        description = "同期する添付フォルダの絶対パス(Obsidian の attachmentFolderPath と一致)。既定は vault ルート直下の attachments/。";
      };

      folder = lib.mkOption {
        type = lib.types.str;
        default = "zettelkasten-attachments";
        description = "添付を置く Google Drive 側のフォルダ名(remote からの相対パス)。無ければ初回同期で作られる。";
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
        description = "定期バックストップ同期の間隔(秒)。イベント駆動(path/WatchPaths)が取りこぼした変更を拾う保険。";
      };
    };

    papis = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "papis(参照文献マネージャ)本体・設定・ライブラリの Google Drive 同期を有効化する。";
      };

      libraryDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.zettelkastenRoot}/references";
        defaultText = "\${zettelkastenRoot}/references";
        description = "papis ライブラリ(info.yaml と PDF が item ごとに同居)の絶対パス。既定は vault ルート直下の references/。";
      };

      folder = lib.mkOption {
        type = lib.types.str;
        default = "papis-library";
        description = "papis ライブラリを置く Google Drive 側のフォルダ名(remote からの相対パス)。";
      };

      opentool = lib.mkOption {
        type = lib.types.str;
        default = "xdg-open";
        description = "papis open が使う外部ビューア。デスクトップの既定アプリに委譲する。";
      };

      intervalSeconds = lib.mkOption {
        type = lib.types.ints.positive;
        default = 900;
        description = "papis ライブラリの定期バックストップ同期の間隔(秒)。";
      };
    };

    obsidian = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          vault に .obsidian 設定(Obsidian 設定 + community plugin 本体)を seed-once で配置する。
          zettelkastenRoot/.obsidian が無いときだけ store の baseline をコピーし、既存の live 設定は
          触らない(非破壊)。以降の Obsidian 上の変更は local のみで、baseline 更新は手動。
        '';
      };

      mirrorRepo = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/alice/zettelkasten-config";
        description = ''
          vault の tracked .obsidian をミラーする config repo(共有/public repo)の checkout 絶対パス。
          null(既定)なら PATH に何も載せない。非 null かつ obsidian.enable のとき mirror-obsidian を
          PATH に載せ、ZETTELKASTEN_ROOT と OBSIDIAN_CONFIG_REPO を env 既定として焼き込む
          (引数/env で上書き可能)。環境固有パスなので消費側(flake_public 等)が settings で注入する。
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.attachments.enable) {
    # ---- 層1: 宣言的な設定の抜けを eval 時に検知する ----
    assertions = [
      {
        assertion = cfg.attachments.dir != "";
        message = "services.zettelkasten.attachments.dir を設定してください(同期対象が特定できません)。";
      }
    ];

    home.packages = [ syncScript ];

    # Linux: oneshot 同期 + path unit(イベント駆動) + timer(定期バックストップ)。
    # watcher を常駐させず、OS 純正のパス監視/定期起動で同期を1発ずつ走らせる。
    # ConditionPathIsDirectory で添付フォルダ未作成時はサービスを skip(失敗にしない)。
    systemd.user.services.zettelkasten-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit = {
        Description = "Zettelkasten 添付を Google Drive へ bisync する(oneshot)";
        ConditionPathIsDirectory = cfg.attachments.dir;
        After = cfg.after;
        Wants = cfg.wants;
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe syncScript} --only attachments";
      };
    };

    systemd.user.paths.zettelkasten-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "Zettelkasten 添付フォルダの変更を監視して同期をトリガする";
      Path = {
        PathModified = cfg.attachments.dir;
        Unit = "zettelkasten-sync.service";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.timers.zettelkasten-sync = lib.mkIf pkgs.stdenv.isLinux {
      Unit.Description = "Zettelkasten 添付同期の定期バックストップ";
      Timer = {
        OnActiveSec = "30s";
        OnUnitActiveSec = "${toString cfg.attachments.intervalSeconds}s";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # Darwin: launchd の WatchPaths(イベント駆動) + StartInterval(定期) + RunAtLoad(初回)。
    launchd.agents.zettelkasten-sync = lib.mkIf pkgs.stdenv.isDarwin {
      enable = true;
      config = {
        ProgramArguments = [ (lib.getExe syncScript) "--only" "attachments" ];
        RunAtLoad = true;
        WatchPaths = [ cfg.attachments.dir ];
        StartInterval = cfg.attachments.intervalSeconds;
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/zettelkasten-sync.log";
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/zettelkasten-sync.log";
      };
    };
    })

    (lib.mkIf (cfg.enable && cfg.obsidian.enable) {
      home.activation.seedObsidian = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${lib.getExe seedObsidian} ${lib.escapeShellArg cfg.zettelkastenRoot}
      '';
    })

    # config を共有 repo へ手動ミラーするための CLI を PATH に載せる(mirrorRepo 指定時のみ)。
    # seed(public→vault)と対で、これは vault→public の逆向き。常駐はしない(たまに手で実行する)。
    (lib.mkIf (cfg.enable && cfg.obsidian.enable && cfg.obsidian.mirrorRepo != null) {
      home.packages = [ mirrorObsidianWrapped ];
    })
  ];
}
