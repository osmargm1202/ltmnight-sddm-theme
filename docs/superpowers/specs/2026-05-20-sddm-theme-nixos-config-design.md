# NixOS-configurable SDDM time and background

Add high-level NixOS module options for the LTMNight SDDM theme so hosts can choose the clock format and login background declaratively. The theme default changes to AM/PM, while 24-hour time remains a supported option.

## Quick path

1. Change the theme default clock format from `HH:mm` to AM/PM.
2. Add NixOS module options under `services.displayManager.sddm.ltmnight`.
3. Build a configured theme package that patches `Themes/hyprltm.conf` from those options.
4. Document NixOS usage and validation commands.

## Decisions

| Topic                 | Decision                                                                                                       |
| --------------------- | -------------------------------------------------------------------------------------------------------------- |
| Public NixOS API      | Expose high-level options: `timeFormat`, `background`, and `backgroundPlaceholder`.                            |
| Time format values    | Use `"ampm"` as the default and `"24h"` as the configurable alternative.                                       |
| Theme config mapping  | Map `"ampm"` to `HourFormat="h:mm AP"` and `"24h"` to `HourFormat="HH:mm"`.                                    |
| Background selection  | Accept a theme-relative path like `Backgrounds/generated-candidates/09-blue-professional-engineering.png`.     |
| Config generation     | Keep the upstream `Themes/hyprltm.conf` file as the source, then patch selected keys in the Nix package build. |
| SDDM integration      | Keep `services.displayManager.sddm.theme = "ltmnight"`; only change the package installed by the module.       |
| Generated backgrounds | Generated files under `Backgrounds/` must be tracked by git before flake consumers can build them from GitHub. |

## NixOS API

Target configuration shape:

```nix
services.displayManager.sddm.ltmnight = {
  timeFormat = "ampm"; # default, or "24h"
  background = "Backgrounds/ltmnight.mp4";
  backgroundPlaceholder = "Backgrounds/ltmnight.png";
};
```

Example using a generated static background:

```nix
services.displayManager.sddm.ltmnight = {
  timeFormat = "24h";
  background = "Backgrounds/generated-candidates/09-blue-professional-engineering.png";
  backgroundPlaceholder = "Backgrounds/generated-candidates/09-blue-professional-engineering.png";
};
```

## Files

| File                  | Change                                                                 |
| --------------------- | ---------------------------------------------------------------------- |
| `Themes/hyprltm.conf` | Set default `HourFormat` to AM/PM.                                     |
| `flake.nix`           | Add NixOS module options and produce a configured package.             |
| `README.md`           | Document `services.displayManager.sddm.ltmnight` options and examples. |

## Validation

- `nix flake check` should evaluate the package and module.
- `nix build .` should produce the default theme package.
- A local module evaluation should show the configured `Themes/hyprltm.conf` contains the selected `HourFormat`, `Background`, and `BackgroundPlaceholder`.
- Optional manual visual check: `sddm-greeter-qt6 --test-mode --theme ./result/share/sddm/themes/ltmnight`.

## Non-goals

- No redesign of `Components/Clock.qml`; it already reads `config.HourFormat`.
- No new background picker UI in the greeter.
- No automatic discovery/listing of all files under `Backgrounds/` in the Nix option type.
- No committing generated backgrounds unless the user explicitly asks which ones to include.

## Risks

- Flake source from GitHub only includes tracked files, so untracked generated backgrounds cannot be selected remotely.
- Patching INI-like config in shell must preserve quotes and avoid accidental replacement of commented sample lines.
- SDDM/QML time format tokens should be verified with the greeter or current Qt behavior; `h:mm AP` is the intended AM/PM format.

## Next step

Create an implementation plan with TDD-style evaluation checks before touching production files.
