{
  description = "A flake to run samwhosung/benilla";

  inputs = {
    # Benilla requires rustc 1.98.1. 26.05 was too told, nixos-unstable is new enough.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    benilla = {
      url = "github:samwhosung/benilla";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, benilla }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      packages.x86_64-linux.default = pkgs.rustPlatform.buildRustPackage {
        pname = "benilla";
        version = (pkgs.lib.importTOML "${benilla}/Cargo.toml").workspace.package.version;
        src = benilla;
        cargoLock.lockFile = "${benilla}/Cargo.lock";

        # the -p flag is here for player build, otherwise dev features also built
        cargoBuildFlags = [ "-p" "benilla" ];
        buildNoDefaultFeatures = true;
        doCheck = false;

        nativeBuildInputs = with pkgs; [ pkg-config makeWrapper ];
        buildInputs = with pkgs; [ alsa-lib udev ];

        # bevy dlopens these at runtime. otherwise they would go beside the binary in nix store, which is read only.
        postInstall = ''
          wrapProgram $out/bin/benilla \
            --prefix LD_LIBRARY_PATH : ${
              pkgs.lib.makeLibraryPath (with pkgs; [
                vulkan-loader
                libxkbcommon
                wayland
                libGL
                libx11
                libxcursor
                libxi
                libxrandr
              ])
            } \
            --run 'export BENILLA_HOME="''${BENILLA_HOME:-$HOME/.local/share/benilla}"'
        '';

        meta.mainProgram = "benilla";
      };

      nixosModules.default =
        { config, lib, ... }:
        let
          cfg = config.programs.benilla;
        in
        {
          options.programs.benilla = {
            enable = lib.mkEnableOption "samwhosung/benilla client";
            clientData = lib.mkOption {
              type = lib.types.str;
              example = "/games/wow/Data";
              description = "Path to the game data folder.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ self.packages.x86_64-linux.default ];
            environment.sessionVariables.WOW_DATA = cfg.clientData;
          };
        };
    };
}
