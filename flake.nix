{
  description = "A flake to run samwhosung/benilla";

  inputs = {
    # rustc 1.98.1. is required, the rustc in 26.05 is too old so unstable is used here
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

        # set app_id, so the name shows up right in e.g. gnome when the app is open
        postPatch = ''
          substituteInPlace crates/benilla-app/src/lib.rs \
            --replace-fail 'title: "benilla".into(),' \
                           'title: "benilla".into(), name: Some("benilla".into()),'
        '';

        nativeBuildInputs = with pkgs; [ pkg-config makeWrapper copyDesktopItems ];

        # make benilla show up in desktop app launchers (gnome's grid etc.)
        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "benilla";
            desktopName = "benilla";
            comment = "benilla client";
            exec = "benilla";
            icon = "applications-games"; # generic placeholder here
            categories = [ "Game" ];
          })
        ];
        buildInputs = with pkgs; [ alsa-lib udev ];

        # LD_LIBRARY_PATH: libs bevy dlopens at runtime
        # BENILLA_HOME: settings would otherwise go in the read-only nix store
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
        { config, lib, pkgs, ... }:
        let
          cfg = config.programs.benilla;
          benilla-pkg = self.packages.x86_64-linux.default;

          # pre-accept game eula, this just skips a screen at first login, which is empty if no eula text in client
          seeded = {
            readTOS = "1";
            readEULA = "1";
            readScanning = "1";
            readContest = "1";
          } // cfg.settings;

          # each launch overwrites these values in the settings conf, so the settings here win over anything set by hand / in game
          launcher = pkgs.writeShellScriptBin "benilla" ''
            if [ -z "''${WOW_DATA:-}" ]; then export WOW_DATA=${lib.escapeShellArg cfg.clientData}; fi
            export BENILLA_HOME="''${BENILLA_HOME:-$HOME/.local/share/benilla}"
            cfg="$BENILLA_HOME/config.toml"
            mkdir -p "$BENILLA_HOME"
            grep -qs '^\[cvars\]' "$cfg" || echo '[cvars]' >> "$cfg"
            ${lib.concatStrings (lib.mapAttrsToList (name: value: ''
              sed -i '/^${name}[[:space:]]*=/d' "$cfg"
              echo ${lib.escapeShellArg "${name} = \"${value}\""} >> "$cfg"
            '') seeded)}
            exec ${benilla-pkg}/bin/benilla "$@"
          '';
        in
        {
          options.programs.benilla = {
            enable = lib.mkEnableOption "samwhosung/benilla client";
            clientData = lib.mkOption {
              type = lib.types.str;
              example = "/path/to/game/Data";
              description = "Path to the game data folder.";
            };
            settings = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              example = {
                gxMultisample = "4";
                anisotropic = "16";
                farclip = "777";
                renderScale = "1.5";
              };
              description = ''
                Client settings (the `[cvars]` of benilla's config.toml), enforced
                on every launch: they override hand edits and in-game changes.
                Settings not listed here are left alone.
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            # the launcher defined above wins over the default one from the pkg
            environment.systemPackages = [ (lib.hiPrio launcher) benilla-pkg ];
          };
        };
    };
}
