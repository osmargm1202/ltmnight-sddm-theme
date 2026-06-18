{
  description = "NixOS-ready fork of the LTMNight SDDM theme";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      themeName = "ltmnight";
      version = "1.2.4-osmargm1202";

      patchThemeConfig = configOverrides:
        lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: ''
          setThemeValue ${lib.escapeShellArg key} ${lib.escapeShellArg value}
        '') configOverrides);

      mkThemePackage = pkgs: { configOverrides ? { } }:
        pkgs.stdenvNoCC.mkDerivation {
          pname = "ltmnight-sddm-theme";
          inherit version;

          src = self;

          nativeBuildInputs = [ pkgs.gawk ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall

            themeDir="$out/share/sddm/themes/${themeName}"
            mkdir -p "$themeDir"

            cp -r \
              Assets \
              Backgrounds \
              Components \
              Previews \
              Themes \
              i18n \
              Main.qml \
              metadata.desktop \
              "$themeDir/"

            setThemeValue() {
              key="$1"
              value="$2"
              file="$themeDir/Themes/hyprltm.conf"
              tmp="$file.tmp"

              awk -v key="$key" -v value="$value" '
                index($0, key "=") == 1 && done == 0 {
                  print key "=\"" value "\""
                  done = 1
                  next
                }
                { print }
                END {
                  if (done != 1) {
                    print "missing theme config key: " key > "/dev/stderr"
                    exit 1
                  }
                }
              ' "$file" > "$tmp"

              mv "$tmp" "$file"
            }

            ${patchThemeConfig configOverrides}

            runHook postInstall
          '';

          meta = {
            description = "LTMNight SDDM theme packaged for NixOS";
            homepage = "https://github.com/osmargm1202/ltmnight-sddm-theme";
            license = lib.licenses.agpl3Only;
            platforms = lib.platforms.linux;
            maintainers = [ ];
          };
        };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          themePackage = mkThemePackage pkgs { };
        in
        {
          default = themePackage;
          ltmnight-sddm-theme = themePackage;
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          configuredSystem = lib.nixosSystem {
            inherit system;
            modules = [
              self.nixosModules.default
              ({ ... }: {
                services.displayManager.sddm.ltmnight = {
                  timeFormat = "24h";
                  background = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
                  backgroundPlaceholder = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
                };
              })
            ];
          };
          configuredTheme = lib.findFirst
            (pkg: (pkg.pname or "") == "ltmnight-sddm-theme")
            (throw "ltmnight-sddm-theme package not found in environment.systemPackages")
            configuredSystem.config.environment.systemPackages;
        in
        {
          module-options = pkgs.runCommand "ltmnight-module-options-check" { } ''
            conf="${configuredTheme}/share/sddm/themes/${themeName}/Themes/hyprltm.conf"

            grep -Fxq 'HourFormat="HH:mm"' "$conf"
            grep -Fxq 'Background="Backgrounds/generated-candidates/20-neutral-cybernetic.png"' "$conf"
            grep -Fxq 'BackgroundPlaceholder="Backgrounds/generated-candidates/20-neutral-cybernetic.png"' "$conf"

            touch "$out"
          '';
        });

      nixosModules.default = { lib, pkgs, config, ... }:
        let
          cfg = config.services.displayManager.sddm.ltmnight;
          themeConfigValueType = lib.types.addCheck lib.types.str (value:
            value != ""
            && !lib.hasInfix "\"" value
            && !lib.hasInfix "\n" value
            && !lib.hasInfix "\r" value);
          themePackage = mkThemePackage pkgs {
            configOverrides = {
              HourFormat = if cfg.timeFormat == "24h" then "HH:mm" else "h:mm AP";
              Background = cfg.background;
              BackgroundPlaceholder = cfg.backgroundPlaceholder;
            };
          };
        in
        {
          options.services.displayManager.sddm.ltmnight = {
            timeFormat = lib.mkOption {
              type = lib.types.enum [ "ampm" "24h" ];
              default = "ampm";
              description = ''
                Clock format for the LTMNight SDDM theme.
                `ampm` renders as AM/PM and `24h` renders as 24-hour time.
              '';
            };

            background = lib.mkOption {
              type = themeConfigValueType;
              default = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
              example = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
              description = ''
                Theme-relative background path for the LTMNight SDDM theme.
                Use a non-empty value without quotes or newlines. Paths under
                `Backgrounds/` support image or video mode.
              '';
            };

            backgroundPlaceholder = lib.mkOption {
              type = themeConfigValueType;
              default = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
              example = "Backgrounds/generated-candidates/20-neutral-cybernetic.png";
              description = ''
                Theme-relative placeholder image path used while video backgrounds load.
                Use a non-empty value without quotes or newlines.
              '';
            };
          };

          config = {
            services.displayManager = {
              defaultSession = lib.mkDefault "hyprland";
              sddm = {
                enable = lib.mkDefault true;
                wayland.enable = lib.mkDefault true;
                autoNumlock = lib.mkDefault true;
                theme = lib.mkDefault themeName;
                extraPackages = with pkgs.qt6; [
                  qtdeclarative
                  qtmultimedia
                  qtsvg
                  qtvirtualkeyboard
                ];
              };
            };

            environment.systemPackages = [ themePackage ];
            fonts.packages = [ pkgs.jetbrains-mono ];
          };
        };
    };
}
