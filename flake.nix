{
  description = "khimoo の Zettelkasten(Obsidian vault)。添付フォルダと papis ライブラリの Google Drive 同期・papis 設定を、どのマシンでも再現できる完結型モジュールとして提供する";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  # 責務分離: この flake は vault のための「ワークフローの仕組み」(添付同期・papis 本体/設定/同期)だけを
  # 所有する。rclone の認証情報は持たず、各マシンの ~/.config/rclone/rclone.conf(`rclone config` で
  # 各自が作る)に委ねる。clone 位置といった環境固有の配線は、これを取り込む側(flake_public 等)が
  # options 経由で注入する(依存性逆転)。
  #
  # 提供物:
  #   apps.default(zettelkasten-bootstrap) … 新しいマシンで使える状態にするまでの対話スクリプト。
  #     `nix run github:khimoo/zettelkasten-workflow` の入口。
  #   homeManagerModules.zettelkasten … 統合 HM モジュール services.zettelkasten。
  #     添付 watcher と papis(設定 + ライブラリ同期 watcher)を常駐管理する。HM 環境向け。
  #   packages.<system>.zettelkasten-sync / apps.sync … 添付と papis をまとめて同期する単一コマンド。
  #     home-manager 非対応環境でも `nix run github:khimoo/zettelkasten-workflow#sync` でワンショット同期できる。
  #   apps.obsidian … 配布する .obsidian のプラグインが要求する外部コマンド(git / claude)ごと
  #     Obsidian を配る。unfree の許可もこちらで持ち、第三者に環境変数を要求しない。
  #   HM モジュールと apps は同じ nix/*-script.nix を共有する。同期ロジックを二重に持たない。
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      syncFor = system: import ./nix/sync-script.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };

      obsidianConfigFor = system: import ./nix/obsidian-config.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };
      seedObsidianFor = system: import ./nix/seed-obsidian.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        obsidianConfig = obsidianConfigFor system;
      };
      mirrorObsidianFor = system: import ./nix/mirror-obsidian.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };
      bootstrapFor = system: import ./nix/bootstrap.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        seedObsidian = seedObsidianFor system;
        syncScript = syncFor system;
      };

      # obsidian と claude-code はどちらも unfree。第三者に NIXPKGS_ALLOW_UNFREE を
      # 要求しないよう、この flake の側で許可した pkgs を用意する。
      obsidianFor = system: import ./nix/obsidian.nix {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in
    {
      homeManagerModules.zettelkasten = import ./nix/hm-module.nix;
      homeManagerModules.default = self.homeManagerModules.zettelkasten;

      packages = forAllSystems (system: {
        bootstrap = bootstrapFor system;
        zettelkasten-sync = syncFor system;
        seed-obsidian = seedObsidianFor system;
        mirror-obsidian = mirrorObsidianFor system;
        obsidian-config = obsidianConfigFor system;
        obsidian = obsidianFor system;
        default = bootstrapFor system;
      });

      apps = forAllSystems (system:
        let
          mkApp = pkg: bin: {
            type = "app";
            program = "${pkg}/bin/${bin}";
          };
          sync = syncFor system;
          seedObsidian = seedObsidianFor system;
          mirrorObsidian = mirrorObsidianFor system;
        in {
          sync = mkApp sync "zettelkasten-sync";
          seed-obsidian = mkApp seedObsidian "seed-obsidian";
          mirror-obsidian = mkApp mirrorObsidian "mirror-obsidian";
          obsidian = mkApp (obsidianFor system) "obsidian";
          default = mkApp (bootstrapFor system) "zettelkasten-bootstrap";
        });
    };
}
