# ltmnight-sddm-theme

![Version](https://img.shields.io/badge/Version-v1.2.4--osmargm1202-bd93f9?style=for-the-badge&labelColor=282a36)
![License](https://img.shields.io/badge/License-AGPL%20v3-ffb86c?style=for-the-badge&labelColor=282a36)
![Qt](https://img.shields.io/badge/Qt-6.10+-50fa7b?style=for-the-badge&labelColor=282a36)
![SDDM](https://img.shields.io/badge/SDDM-0.21+-8be9fd?style=for-the-badge&labelColor=282a36)

NixOS-ready fork of **LTMNight SDDM Theme**.

This fork is based on the original project by **Djalel Oukid (sniper1720)**:

- Original repository: https://github.com/hyprltm/ltmnight-sddm-theme
- Original project website: https://www.linuxtechmore.com/

The goal of this fork is to make the theme easy to consume from a NixOS flake and to adapt the login experience for a custom Hyprland/NixOS setup.

## Preview

![Static Preview](Previews/ltmnight.png)

## Features

- **LTMNight styling** — dark background, purple accents, and subtle glow effects.
- **Static, video, or shader background** — configurable through the theme config.
- **Partial blur** — frosted glass behind the login form.
- **Clock and top bar** — time, host/session controls, and keyboard layout controls.
- **Session selector** — choose Hyprland or another installed SDDM session.
- **Virtual keyboard support** — optional Qt virtual keyboard integration.
- **HiDPI ready** — UI scales based on screen resolution.
- **Nix flake package** — install directly from GitHub on NixOS.

## Fork changes

- Added `flake.nix`.
- Exposes package output:
  - `packages.<system>.default`
  - `packages.<system>.ltmnight-sddm-theme`
- Exposes a NixOS module:
  - `nixosModules.default`
- Documents NixOS usage instead of non-Nix package-manager installation.
- Removes non-Nix installer, distro packaging, and funding sections from this fork.
- Keeps attribution to the original project.

## NixOS usage

### Option A — import the module

Add the fork as a flake input:

```nix
{
  inputs.ltmnight-sddm-theme.url = "github:osmargm1202/ltmnight-sddm-theme";
}
```

Then include the module from your flake output:

```nix
{
  outputs = inputs@{ nixpkgs, ltmnight-sddm-theme, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ltmnight-sddm-theme.nixosModules.default
      ];
    };
  };
}
```

The module provides SDDM defaults with:

```nix
services.displayManager = {
  defaultSession = "hyprland";
  sddm = {
    enable = true;
    wayland.enable = true;
    autoNumlock = true;
    theme = "ltmnight";
  };
};
```

These values use `lib.mkDefault`, so your host configuration can override them.

### Option B — use only the package

If you prefer to configure SDDM yourself:

```nix
{ pkgs, inputs, ... }:
let
  ltmnight = inputs.ltmnight-sddm-theme.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  services.displayManager = {
    defaultSession = "hyprland";
    sddm = {
      enable = true;
      wayland.enable = true;
      autoNumlock = true;
      theme = "ltmnight";
      extraPackages = with pkgs.qt6; [
        qtdeclarative
        qtmultimedia
        qtsvg
        qtvirtualkeyboard
      ];
    };
  };

  environment.systemPackages = [ ltmnight ];
  fonts.packages = [ pkgs.jetbrains-mono ];
}
```

Apply with:

```bash
sudo nixos-rebuild switch --flake /path/to/your/flake#your-host
```

## Build locally

```bash
nix build .
```

Result path:

```text
result/share/sddm/themes/ltmnight
```

## Test locally

From this repository:

```bash
sddm-greeter-qt6 --test-mode --theme ./result/share/sddm/themes/ltmnight
```

If `result` does not exist yet, run:

```bash
nix build .
```

## Customization

Theme config lives at:

```text
Themes/hyprltm.conf
```

On mutable installs, the upstream theme also supports a user override file:

```text
Themes/hyprltm.conf.user
```

On NixOS, prefer changing this repository and rebuilding the flake so the theme remains declarative.

Important options:

| Option | Description |
|---|---|
| `Background` | `ltmnight` for shader mode, or path to image/video. |
| `PartialBlur` | Enables blur behind the login form. |
| `FormPosition` | `left`, `center`, or `right`. |
| `HourFormat` | Time format. |
| `HeaderText` | Custom top/header text. |
| `HideVirtualKeyboard` | Hide or show virtual keyboard toggle. |
| `VirtualKeyboardAutoShow` | Auto-show virtual keyboard on input focus. |

## Notes

- This theme requires Qt6 SDDM.
- For speed, static image mode is usually faster than video/shader mode.
- `autoNumlock = true` is enabled in the bundled NixOS module.
- If NumLock still does not activate under a Wayland greeter, SDDM/KWin may need extra keyboard config outside the theme.

## License

Original work copyright:

```text
Copyright (C) 2026 Djalel Oukid (sniper1720)
```

Licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

This fork preserves the original license and attribution.
