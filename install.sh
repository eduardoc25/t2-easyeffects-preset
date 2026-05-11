#!/usr/bin/env bash
# install.sh — Installer for the T2 MacBook Pro EasyEffects preset
# Installs dependencies, copies the preset, and configures autoloading.
# Supported distros: Arch Linux, Fedora/RHEL, Debian/Ubuntu

set -euo pipefail

PRESET_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mbp.json"
PRESET_NAME="mbp"
EE_OUTPUT_DIR="$HOME/.config/easyeffects/output"
EE_OUTPUT_DIR_ALT="$HOME/.config/easyeffects/presets/output"
EE_AUTOLOAD_DIR="$HOME/.config/easyeffects/autoloading"

# ── colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BOLD}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── detect distro ──────────────────────────────────────────────────────────────
detect_distro() {
    if   command -v pacman &>/dev/null;      then echo "arch"
    elif command -v dnf    &>/dev/null;      then echo "fedora"
    elif command -v apt    &>/dev/null;      then echo "debian"
    else error "Unsupported package manager. Install dependencies manually: easyeffects, lsp-plugins, calf."
    fi
}

# ── install packages ───────────────────────────────────────────────────────────
install_deps() {
    local distro="$1"
    info "Installing dependencies for distro: $distro"

    case "$distro" in
        arch)
            sudo pacman -S --needed --noconfirm easyeffects lsp-plugins calf
            ;;
        fedora)
            sudo dnf install -y easyeffects lsp-plugins calf
            ;;
        debian)
            sudo apt update -qq
            sudo apt install -y easyeffects lsp-plugins-lv2 calf-plugins
            ;;
    esac
}

# ── verify LV2 plugins are loadable ───────────────────────────────────────────
check_plugins() {
    local missing=()
    for dir in /usr/lib/lv2 /usr/local/lib/lv2 "$HOME/.lv2"; do
        [[ -d "$dir/lsp-plugins.lv2" ]] && LSP_OK=1
        [[ -d "$dir/calf.lv2"        ]] && CALF_OK=1
    done
    [[ "${LSP_OK:-0}" -eq 0 ]]  && missing+=("lsp-plugins")
    [[ "${CALF_OK:-0}" -eq 0 ]] && missing+=("calf")

    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "LV2 plugin directories not found for: ${missing[*]}"
        warn "Some effects may not work until plugins are installed correctly."
    else
        success "LSP and CALF LV2 plugins found."
    fi
}

# ── install preset file ────────────────────────────────────────────────────────
install_preset() {
    [[ -f "$PRESET_FILE" ]] || error "Preset file not found: $PRESET_FILE"

    # Some EasyEffects versions/distros keep output presets in different paths.
    local output_dirs=("$EE_OUTPUT_DIR")
    if [[ -d "$HOME/.config/easyeffects/presets" ]]; then
        output_dirs+=("$EE_OUTPUT_DIR_ALT")
    fi

    local dir
    for dir in "${output_dirs[@]}"; do
        mkdir -p "$dir"
        cp "$PRESET_FILE" "$dir/$PRESET_NAME.json"
        success "Preset installed to $dir/$PRESET_NAME.json"
    done
}

# ── detect Apple T2 speaker sink ──────────────────────────────────────────────
detect_t2_sink() {
    # Prefer the sink whose description contains "Apple Audio Device"
    local sink_name sink_desc

    if ! command -v pactl &>/dev/null; then
        warn "pactl not found; skipping autoloading setup. Set it up manually in EasyEffects."
        return 1
    fi

    # Look for any sink associated with the Apple T2 card
    sink_name=$(pactl list sinks 2>/dev/null \
        | awk '/^\s*Name:/{name=$2} /Apple (Audio Device|T2)/{print name; exit}')

    if [[ -z "$sink_name" ]]; then
        warn "Apple T2 audio sink not found. Is the t2linux driver loaded?"
        warn "Autoloading config was NOT created. Set it up manually in EasyEffects."
        return 1
    fi

    sink_desc=$(pactl list sinks 2>/dev/null \
        | awk "/^\s*Name:\s*${sink_name//\//\\/}/{found=1} found && /^\s*Description:/{print; exit}" \
        | sed 's/.*Description:[[:space:]]*//')

    echo "$sink_name|$sink_desc"
}

# ── write autoloading config ───────────────────────────────────────────────────
setup_autoloading() {
    local sink_info="$1"
    local sink_name="${sink_info%%|*}"
    local sink_desc="${sink_info##*|}"

    mkdir -p "$EE_AUTOLOAD_DIR"
    local autoload_file="$EE_AUTOLOAD_DIR/output.json"

    # Merge with existing entries if the file already exists
    if [[ -f "$autoload_file" ]]; then
        # Remove any previous entry for this preset to avoid duplicates
        local tmp
        tmp=$(python3 -c "
import json, sys
data = json.load(open('$autoload_file'))
data = [e for e in data if e.get('preset-name') != '$PRESET_NAME']
data.append({'device': '$sink_name', 'device-description': '$sink_desc', 'preset-name': '$PRESET_NAME'})
print(json.dumps(data, indent=4))
" 2>/dev/null) && echo "$tmp" > "$autoload_file" || {
            warn "Could not merge autoloading config; overwriting."
            write_autoloading_json "$autoload_file" "$sink_name" "$sink_desc"
        }
    else
        write_autoloading_json "$autoload_file" "$sink_name" "$sink_desc"
    fi

    success "Autoloading configured: $sink_desc → $PRESET_NAME"
}

write_autoloading_json() {
    local file="$1" sink_name="$2" sink_desc="$3"
    cat > "$file" <<EOF
[
    {
        "device": "$sink_name",
        "device-description": "$sink_desc",
        "preset-name": "$PRESET_NAME"
    }
]
EOF
}

# ── main ───────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}T2 MacBook Pro — EasyEffects Preset Installer${NC}"
    echo "────────────────────────────────────────────────"

    local distro
    distro=$(detect_distro)

    if [[ "${1:-}" == "--no-deps" ]]; then
        info "Skipping dependency installation (--no-deps)."
    else
        if ! install_deps "$distro"; then
            warn "Dependency installation failed. Continuing with preset installation."
            warn "You can rerun later with --no-deps if dependencies are already present."
        fi
    fi

    check_plugins
    install_preset

    local sink_info
    if sink_info=$(detect_t2_sink); then
        setup_autoloading "$sink_info"
    fi

    echo "────────────────────────────────────────────────"
    echo -e "${GREEN}${BOLD}Done!${NC} Open EasyEffects and:"
    echo "  1. Go to Pipewire → Presets Autoloading to verify the entry."
    echo "  2. Enable 'Launch Service at System Startup' in Preferences."
}

main "$@"
