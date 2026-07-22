{
  description = "khimoo の Zettelkasten(Obsidian vault)。添付フォルダと papis ライブラリの Google Drive 同期・papis 設定を、どのマシンでも再現できる完結型モジュールとして提供する";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  # 責務分離: この flake は vault のための「ワークフローの仕組み」(添付同期・papis 本体/設定/同期)と
  # vault 専用 secret の暗号文(secrets/rclone.yaml = rclone 認証情報)を所有する。復号鍵は持たない
  # (各マシンの SSH 鍵か持ち込みの age 鍵が環境側にある)。clone 位置といった環境固有の配線は、
  # これを取り込む側(flake_public 等)が options 経由で注入する(依存性逆転)。
  #
  # 提供物:
  #   homeManagerModules.zettelkasten … 統合 HM モジュール services.zettelkasten。
  #     添付 watcher と papis(設定 + ライブラリ同期 watcher)を常駐管理する。HM 環境向け。
  #   packages.<system>.{zettelkasten-sync,papis-sync} / apps … 実行可能スクリプト。
  #     home-manager 非対応環境でも `nix run github:khimoo/zettelkasten#papis-sync` 等でワンショット同期できる。
  #   HM モジュールと apps は同じスクリプトを共有する: nix/with-rclone-secret.nix(実行時復号)+
  #   nix/*-script.nix(同期本体)。復号も同期もロジックを二重に持たない。
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      withRcloneSecretFor = system: import ./nix/with-rclone-secret.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };
      attachmentsSyncFor = system: (withRcloneSecretFor system) (import ./nix/sync-script.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      });
      papisSyncFor = system: (withRcloneSecretFor system) (import ./nix/papis-sync-script.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      });

      obsidianConfigFor = system: import ./nix/obsidian-config.nix {
        pkgs = nixpkgs.legacyPackages.${system};
      };
      seedObsidianFor = system: import ./nix/seed-obsidian.nix {
        pkgs = nixpkgs.legacyPackages.${system};
        obsidianConfig = obsidianConfigFor system;
      };
    in
    {
      homeManagerModules.zettelkasten = import ./nix/hm-module.nix;
      homeManagerModules.default = self.homeManagerModules.zettelkasten;

      packages = forAllSystems (system: {
        zettelkasten-sync = attachmentsSyncFor system;
        papis-sync = papisSyncFor system;
        seed-obsidian = seedObsidianFor system;
        obsidian-config = obsidianConfigFor system;
        default = attachmentsSyncFor system;
      });

      apps = forAllSystems (system:
        let
          mkApp = pkg: bin: {
            type = "app";
            program = "${pkg}/bin/${bin}";
          };
          attachments = attachmentsSyncFor system;
          papis = papisSyncFor system;
          seedObsidian = seedObsidianFor system;
        in {
          zettelkasten-sync = mkApp attachments "zettelkasten-sync";
          papis-sync = mkApp papis "papis-sync";
          seed-obsidian = mkApp seedObsidian "seed-obsidian";
          default = mkApp attachments "zettelkasten-sync";
        });
    };
}
