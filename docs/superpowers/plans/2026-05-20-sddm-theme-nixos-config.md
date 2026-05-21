# SDDM Theme NixOS Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add NixOS-configurable LTMNight SDDM clock format and background selection, with AM/PM as the default and 24-hour time as an option.

**Architecture:** Keep QML behavior unchanged because `Components/Clock.qml` already reads `config.HourFormat` and `Main.qml` already reads `Background` / `BackgroundPlaceholder`. Move customization into the NixOS module by building a configured copy of the theme package that patches `Themes/hyprltm.conf` at build time.

**Tech Stack:** Nix flakes, NixOS module options, SDDM theme config, Qt/QML theme files.

**Human control:** Do not commit. Only stage or commit if the user explicitly asks.

---

## File Structure

| File                  | Responsibility                                                                                                           |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `flake.nix`           | Package the base theme, expose NixOS module options, build configured package for module users, and define flake checks. |
| `Themes/hyprltm.conf` | Source default theme config; `HourFormat` default becomes AM/PM.                                                         |
| `README.md`           | Document the NixOS options and generated-background usage.                                                               |

---

### Task 1: Add failing NixOS module check

**Files:**

- Modify: `flake.nix`

- [ ] **Step 1: Add a failing check that describes expected module behavior**

Add a `checks` output next to `packages` in `flake.nix`. The check intentionally uses the future options before they exist, so `nix flake check` should fail first.

Add this attrset after the existing `packages = ...;` block and before `nixosModules.default = ...;`:

```nix
      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          evaluated = lib.evalModules {
            modules = [
              self.nixosModules.default
              ({ ... }: {
                services.displayManager.sddm.ltmnight = {
                  timeFormat = "24h";
                  background = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
                  backgroundPlaceholder = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
                };
              })
            ];
            specialArgs = { inherit pkgs; };
          };
          configuredTheme = builtins.head evaluated.config.environment.systemPackages;
        in
        {
          module-options = pkgs.runCommand "ltmnight-module-options-check" { } ''
            conf="${configuredTheme}/share/sddm/themes/${themeName}/Themes/hyprltm.conf"

            grep -q 'HourFormat="HH:mm"' "$conf"
            grep -q 'Background="Backgrounds/generated-candidates/18-neutral-hyprland.png"' "$conf"
            grep -q 'BackgroundPlaceholder="Backgrounds/generated-candidates/18-neutral-hyprland.png"' "$conf"

            touch "$out"
          '';
        });
```

- [ ] **Step 2: Run check to verify RED**

Run:

```bash
nix flake check
```

Expected: FAIL because option `services.displayManager.sddm.ltmnight` does not exist yet.

Acceptable failure shape:

```text
The option `services.displayManager.sddm.ltmnight' does not exist
```

If the check passes, stop. The test is not proving the missing feature.

---

### Task 2: Implement configured package and NixOS options

**Files:**

- Modify: `flake.nix`

- [ ] **Step 1: Refactor package creation into a helper**

Replace the current `themePackage = pkgs.stdenvNoCC.mkDerivation { ... };` inside `packages` with a top-level helper in the `let` block.

Add this helper after `version = "1.2.4-osmargm1202";`:

```nix
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
                $0 ~ "^" key "=" && done == 0 {
                  print key "=\"" value "\""
                  done = 1
                  next
                }
                { print }
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
```

- [ ] **Step 2: Simplify `packages` to use the helper**

Replace the current `packages = ...` body with:

```nix
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          themePackage = mkThemePackage pkgs { };
        in
        {
          default = themePackage;
          ltmnight-sddm-theme = themePackage;
        });
```

- [ ] **Step 3: Add module options**

Replace the current `nixosModules.default = { lib, pkgs, ... }:` module with this shape:

```nix
      nixosModules.default = { lib, pkgs, config, ... }:
        let
          cfg = config.services.displayManager.sddm.ltmnight;
          hourFormat = if cfg.timeFormat == "24h" then "HH:mm" else "h:mm AP";
          themePackage = mkThemePackage pkgs {
            configOverrides = {
              HourFormat = hourFormat;
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
              type = lib.types.str;
              default = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
              example = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
              description = ''
                Theme-relative background path for the LTMNight SDDM theme.
                Use `ltmnight` for shader mode, or a path under `Backgrounds/` for image/video mode.
              '';
            };

            backgroundPlaceholder = lib.mkOption {
              type = lib.types.str;
              default = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
              example = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
              description = ''
                Theme-relative placeholder image path used while video backgrounds load.
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
```

- [ ] **Step 4: Run focused check to verify GREEN for module behavior**

Run:

```bash
nix flake check
```

Expected: PASS for `checks.<system>.module-options`, or fail only because `Themes/hyprltm.conf` still defaults to old `HH:mm` and Task 3 has not run yet. If it fails because `gawk` or module evaluation is broken, fix `flake.nix` before continuing.

---

### Task 3: Change theme default to AM/PM

**Files:**

- Modify: `Themes/hyprltm.conf`

- [ ] **Step 1: Change default hour format**

Replace:

```ini
HourFormat="HH:mm"
```

with:

```ini
HourFormat="h:mm AP"
```

- [ ] **Step 2: Build default package and inspect default config**

Run:

```bash
nix build .
grep -n 'HourFormat=' result/share/sddm/themes/ltmnight/Themes/hyprltm.conf
```

Expected:

```text
HourFormat="h:mm AP"
```

---

### Task 4: Document NixOS options

**Files:**

- Modify: `README.md`

- [ ] **Step 1: Add module option example under NixOS usage**

Add this after the module import example and before the existing default SDDM values section:

Configure theme-specific options with:

```nix
services.displayManager.sddm.ltmnight = {
  timeFormat = "ampm"; # default, or "24h"
  background = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
  backgroundPlaceholder = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
};
```

To use a fixed generated background:

```nix
services.displayManager.sddm.ltmnight = {
  timeFormat = "24h";
  background = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
  backgroundPlaceholder = "Backgrounds/generated-candidates/18-neutral-hyprland.png";
};
```

Generated backgrounds must be tracked in git before remote flake consumers can build them from GitHub.

- [ ] **Step 2: Update customization table**

Replace the `HourFormat` row with:

```markdown
| `HourFormat` | Time format. Default is AM/PM (`h:mm AP`); use `HH:mm` for 24-hour time. |
```

Add these rows near the customization table if they are missing:

```markdown
| NixOS `timeFormat` | High-level module option: `"ampm"` or `"24h"`. |
| NixOS `background` | High-level module option for a theme-relative background path. |
| NixOS `backgroundPlaceholder` | High-level module option for the video placeholder image. |
```

---

### Task 5: Final verification

**Files:**

- Verify: `flake.nix`, `Themes/hyprltm.conf`, `README.md`

- [ ] **Step 1: Run flake check**

Run:

```bash
nix flake check
```

Expected: PASS.

- [ ] **Step 2: Build default package**

Run:

```bash
nix build .
```

Expected: PASS.

- [ ] **Step 3: Inspect default theme config**

Run:

```bash
grep -E '^(HourFormat|Background|BackgroundPlaceholder)=' result/share/sddm/themes/ltmnight/Themes/hyprltm.conf
```

Expected:

```text
HourFormat="h:mm AP"
Background="Backgrounds/generated-candidates/18-neutral-hyprland.png"
BackgroundPlaceholder="Backgrounds/generated-candidates/18-neutral-hyprland.png"
```

- [ ] **Step 4: Inspect configured module output from check derivation**

Run:

```bash
nix build .#checks.$(nix eval --impure --raw --expr 'builtins.currentSystem').module-options
```

Expected: PASS and produce a result symlink.

- [ ] **Step 5: Review diff before reporting**

Run:

```bash
git diff -- flake.nix Themes/hyprltm.conf README.md docs/superpowers/specs/2026-05-20-sddm-theme-nixos-config-design.md docs/superpowers/plans/2026-05-20-sddm-theme-nixos-config.md
```

Expected: Diff only includes planned changes. Existing user changes in generated backgrounds remain untouched.
