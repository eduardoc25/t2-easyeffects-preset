# T2 MacBook Pro EasyEffects Preset

This preset for the EasyEffects app enhances speaker quality for T2 Linux users.

It has been tested on a MacBook Pro 15,1 (2019) running Fedora 39 and Arch Linux, but it should be compatible with any other PipeWire-based distribution.

The processing chain consists of: **High-pass filter → Bass Enhancer → Multiband Compressor → Stereo Tools → Limiter → Equalizer**.

## Requirements

- [EasyEffects](https://github.com/wwmm/easyeffects) ≥ 7.x
- [LSP Plugins](https://lsp-plug.in/) (LV2)
- [CALF Studio Gear](https://calf-studio-gear.org/) (LV2)
- PipeWire audio server

## Installation

### Automatic (recommended)

Run the provided installer script — it detects your distro, installs all dependencies, copies the preset, and configures autoloading:

```bash
git clone https://github.com/angelobdev/t2-easyeffects-preset
cd t2-easyeffects-preset
./install.sh
```

If dependencies are already installed, you can skip that step:

```bash
./install.sh --no-deps
```

Supported package managers: `pacman` (Arch), `dnf` (Fedora/RHEL), `apt` (Debian/Ubuntu).

### Manual

1. Install [EasyEffects](https://github.com/wwmm/easyeffects), LSP Plugins, and CALF Studio Gear from your distro's repositories.

2. Copy [mbp.json](mbp.json) to `~/.config/easyeffects/output/`.

3. Open EasyEffects and go to the **Pipewire** tab.

4. Go to **Presets Autoloading**, select your Apple speakers output device (usually listed as `Apple Audio Device` or `Apple Audio Device Pro`) and the `mbp` preset, then click **+**.

5. Open **Preferences** (three-dot menu, top right) and enable **Launch Service at System Startup**.

6. Enjoy!

## Licence

This project is under the GPL3 license. Read the [LICENSE](LICENSE.md) for more.

## Contribution

Feel free to contribute to this project.

---

Made with ❤️ by [angelobdev](https://github.com/angelobdev)
