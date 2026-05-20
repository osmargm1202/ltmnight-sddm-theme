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
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          themePackage = pkgs.stdenvNoCC.mkDerivation {
            pname = "ltmnight-sddm-theme";
            inherit version;

            src = self;

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
          default = themePackage;
          ltmnight-sddm-theme = themePackage;
        });

      nixosModules.default = { lib, pkgs, ... }:
        let
          themePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
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
}
