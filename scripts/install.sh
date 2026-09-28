#!/data/data/com.termux/files/usr/bin/bash
#
# Termux Plus - Interactive Installer
# https://github.com/bytefuserdev/termux-plus
#

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
LOG_FILE="$HOME/termux-plus-install.log"

if ! command -v dialog >/dev/null 2>&1; then
    printf '%s\n' "dialog is not installed."
    printf '%s\n' "Install it first with: pkg install dialog"
    exit 1
fi

if [[ ! -d "$REPO_DIR" ]]; then
    dialog --msgbox "Repository directory could not be detected." 8 50
    exit 1
fi

exec 3>&1

run_cmd() {
    printf '\n>>> %s\n' "$*" >> "$LOG_FILE"
    "$@" >> "$LOG_FILE" 2>&1
    local status=$?
    if (( status != 0 )); then
        dialog --title "Installation Error" \
            --msgbox "Command failed:\n\n$*\n\nSee:\n$LOG_FILE" 12 70
        return $status
    fi
    return 0
}

run_shell() {
    printf '\n>>> %s\n' "$1" >> "$LOG_FILE"
    bash -c "$1" >> "$LOG_FILE" 2>&1
    local status=$?
    if (( status != 0 )); then
        dialog --title "Installation Error" \
            --msgbox "Command failed:\n\n$1\n\nSee:\n$LOG_FILE" 12 70
        return $status
    fi
    return 0
}

pkg_install() {
    local packages=("$@")
    run_cmd pkg install -y "${packages[@]}"
}

copy_if_exists() {
    local source="$1"
    local destination="$2"

    if [[ ! -e "$source" ]]; then
        dialog --msgbox "Repository file not found:\n\n$source" 10 70
        return 1
    fi

    mkdir -p "$(dirname "$destination")"
    cp -f "$source" "$destination"
}

install_zsh() {
    pkg_install git zsh zsh-completions
    pkg_install curl

    local font="$REPO_DIR/assets/font/font.ttf"
    mkdir -p "$HOME/.termux"
    copy_if_exists "$font" "$HOME/.termux/font.ttf"

    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        run_shell 'yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    fi

    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    if [[ ! -d "$custom/themes/powerlevel10k" ]]; then
        run_cmd git clone --depth=1 \
            https://github.com/romkatv/powerlevel10k.git \
            "$custom/themes/powerlevel10k"
    fi

    if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
        run_cmd git clone \
            https://github.com/zsh-users/zsh-syntax-highlighting.git \
            "$custom/plugins/zsh-syntax-highlighting"
    fi

    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.termux-plus.backup"
    fi

    if ! grep -q 'powerlevel10k/powerlevel10k' "$HOME/.zshrc" 2>/dev/null; then
        printf '\nZSH_THEME="powerlevel10k/powerlevel10k"\n' >> "$HOME/.zshrc"
    fi
}

install_neovim() {
    pkg_install neovim lua54 git curl

    if [[ ! -d "$HOME/.config/nvim" ]]; then
        run_cmd git clone https://github.com/NvChad/starter "$HOME/.config/nvim"
    fi

    if [[ -d "$HOME/.config/nvim/.git" ]]; then
        rm -rf "$HOME/.config/nvim/.git"
    fi

    mkdir -p "$HOME/.config/nvim/lua/configs"

    copy_if_exists \
        "$REPO_DIR/configs/neovim/lspconfig.lua" \
        "$HOME/.config/nvim/lua/configs/lspconfig.lua"

    copy_if_exists \
        "$REPO_DIR/configs/neovim/init.lua" \
        "$HOME/.config/nvim/lua/plugins/init.lua"
}

install_termux_config() {
    mkdir -p "$HOME/.termux"
    copy_if_exists \
        "$REPO_DIR/configs/termux/termux.properties" \
        "$HOME/.termux/termux.properties"

    if command -v termux-reload-settings >/dev/null 2>&1; then
        termux-reload-settings
    fi
}

install_themes() {
    local tmp="$HOME/.cache/termux-plus"
    mkdir -p "$tmp"

    local theme="$REPO_DIR/assets/theme/theme.tar.xz"
    local icons="$REPO_DIR/assets/icons/icons.tar.gz"
    local cursor="$REPO_DIR/assets/icons/cursor.zip"
    local wallpaper="$REPO_DIR/assets/wallpaper/wallpaper.jpg"

    mkdir -p "$PREFIX/share/themes" "$PREFIX/share/icons"

    if [[ -f "$theme" ]]; then
        tar -xJf "$theme" -C "$tmp"
        find "$tmp" -maxdepth 2 -type d -name 'Orchis*' -exec cp -r {} "$PREFIX/share/themes/" \;
    fi

    if [[ -f "$icons" ]]; then
        tar -xzf "$icons" -C "$tmp"
        find "$tmp" -maxdepth 2 -type d \( -name 'kora*' -o -name 'Kora*' \) \
            -exec cp -r {} "$PREFIX/share/icons/" \;
    fi

    if [[ -f "$cursor" ]]; then
        unzip -o "$cursor" -d "$tmp/cursor" >> "$LOG_FILE" 2>&1
        find "$tmp/cursor" -maxdepth 2 -type d -name 'ArcAurora*' \
            -exec cp -r {} "$PREFIX/share/icons/" \;
    fi

    if [[ -f "$wallpaper" ]]; then
        mkdir -p "$HOME/Pictures"
        cp -f "$wallpaper" "$HOME/Pictures/termux-plus-wallpaper.jpg"
    fi
}


install_desktop_configs() {
    local config_dir="$REPO_DIR/configs/desktop"
    local tmp="$HOME/.cache/termux-plus/desktop-configs"

    mkdir -p "$tmp" "$HOME/.config"

    if [[ ! -d "$config_dir" ]]; then
        dialog --msgbox "Desktop configuration directory was not found:\n\n$config_dir" 10 70
        return 1
    fi

    extract_config_archive() {
        local archive="$1"
        local config_name="$2"
        local archive_path="$config_dir/$archive"
        local extract_dir="$tmp/$config_name"

        if [[ ! -f "$archive_path" ]]; then
            dialog --msgbox "Configuration archive not found:\n\n$archive_path" 10 70
            return 1
        fi

        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"

        if ! tar -xf "$archive_path" -C "$extract_dir" >> "$LOG_FILE" 2>&1; then
            dialog --msgbox "Could not extract:\n\n$archive_path\n\nSee:\n$LOG_FILE" 12 70
            return 1
        fi

        # Find the actual configuration directory regardless of how
        # the archive was created.
        local source_dir
        source_dir="$(find "$extract_dir" -type d -name "$config_name" -print -quit)"

        if [[ -z "$source_dir" ]]; then
            dialog --msgbox \
                "Could not find '$config_name' inside:\n\n$archive_path\n\nThe archive was extracted to:\n$extract_dir" \
                12 70
            return 1
        fi

        # Back up an existing configuration before replacing/merging it.
        if [[ -e "$HOME/.config/$config_name" ]]; then
            local backup="$HOME/.config/${config_name}.termux-plus-backup"
            rm -rf "$backup"
            cp -a "$HOME/.config/$config_name" "$backup"
        fi

        rm -rf "$HOME/.config/$config_name"
        cp -a "$source_dir" "$HOME/.config/$config_name"

        printf 'Installed desktop configuration: %s -> ~/.config/%s\n' \
            "$archive" "$config_name" >> "$LOG_FILE"
    }

    extract_config_archive "xfce4.tar" "xfce4"
    extract_config_archive "plank.tar" "plank"
    extract_config_archive "autostart.tar" "autostart"

    dialog --title "Desktop Configuration" \
        --msgbox \
"Xfce4, Plank, and Autostart configurations have been installed.

Existing configurations were backed up as:
~/.config/<name>.termux-plus-backup

Restart Xfce/Termux:X11 to apply all changes." \
        12 70
}

install_toolchain() {
    pkg_install clang binutils llvm-tools ndk-multilib build-essential mlir bear lld
    pkg_install autoconf bison flex ninja pkg-config automake make cmake
    pkg_install autoconf-archive xorgproto gettext
}

install_python() {
    pkg_install python uv python-numpy matplotlib python-pandas python-psutil python-tkinter
}

install_web() {
    pkg_install nodejs npm apache2 nginx perl php
}

install_other_languages() {
    pkg_install golang rust openjdk-21
}

install_debugging() {
    pkg_install lldb gdb strace ldd rizin
}

install_lsp() {
    pkg_install neocmakelsp asm-lsp pyrefly ruff
}

install_networking() {
    pkg_install inetutils iproute2 wget curl apache2 nginx gitea
}

install_cli() {
    pkg_install lsd fastfetch mandoc cmatrix mlocate manpages bat fd
    pkg_install android-tools synaptic fzf tmux cava proot-distro
    pkg_install inotify-tools python-yt-dlp
}

install_graphics() {
    pkg_install mesa-dev sdl2 sdl2-ttf sdl2-image sdl2-mixer glew glfw glm mesa opencv
}

install_qemu() {
    pkg_install qemu-system-x86-64 qemu-utils qemu-user-x86-64
}

install_desktop() {
    pkg_install xfce4 xfce4-goodies firefox xfce4-*plugin vlc-qt
    pkg_install telegram-desktop keepassxc fontconfig-utils thunderbird inkscape
    pkg_install code-oss pavucontrol termux-x11-nightly gimp plank-reloaded
    pkg_install xfce4-taskmanager xfce4-screenshooter xfce4-appfinder
    pkg_install ristretto parole mousepad galculator tigervnc tigervnc-viewer libreoffice
    pkg_install ghex jadx-x
}

install_python_apps() {
    run_shell 'pip install django flask --verbose'
    run_shell 'ANDROID_API_LEVEL=31 CARGO_BUILD_JOBS=4 pip install jupyter jupyterlab-lsp jupyter-ruff --verbose'
    run_shell 'ANDROID_API_LEVEL=31 CARGO_BUILD_JOBS=4 pip install meson maturin --verbose'
}

cleanup() {
    pkg autoremove -y >> "$LOG_FILE" 2>&1 || true
    pkg clean >> "$LOG_FILE" 2>&1 || true
    pip cache purge >> "$LOG_FILE" 2>&1 || true
    npm cache clean --force >> "$LOG_FILE" 2>&1 || true
}

mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

dialog --title "Termux Plus Installer" \
    --msgbox \
"Welcome to Termux Plus.

Choose exactly which components you want to install.

Nothing is installed until you confirm your selection.

Installation log:
$LOG_FILE" 12 70

choices=$(
dialog --stdout --title "Select Components" --checklist \
"Use SPACE to select/unselect components. Press ENTER when finished." \
24 90 15 \
"toolchain" "C/C++ / LLVM / build tools" OFF \
"python" "Python / uv / scientific libraries" OFF \
"web" "Node.js / npm / Apache / Nginx / Perl / PHP" OFF \
"languages" "Go / Rust / OpenJDK 21" OFF \
"debugging" "GDB / LLDB / strace / rizin" OFF \
"lsp" "Neovim language servers" OFF \
"neovim" "Neovim + NvChad + repository configuration" OFF \
"zsh" "Zsh + Oh My Zsh + Powerlevel10k" OFF \
"desktop" "Xfce4 / Termux:X11 / desktop applications" OFF \
"desktopconfig" "Install bundled Xfce4 / Plank / Autostart configuration" OFF \
"networking" "Networking / Gitea / server tools" OFF \
"cli" "CLI utilities / fzf / tmux / yt-dlp" OFF \
"graphics" "Mesa / SDL2 / GLFW / OpenCV" OFF \
"qemu" "QEMU x86-64 emulation" OFF \
"pythonapps" "Django / Flask / Jupyter / Meson / Maturin" OFF \
"themes" "Themes / icons / cursor / wallpaper" OFF \
"termuxconfig" "Install repository Termux configuration" OFF \
"cleanup" "Remove unused packages and clean caches" OFF
)

status=$?
if (( status != 0 )); then
    clear
    exit 0
fi

dialog --title "Confirm Installation" \
    --yesno \
"Install the selected components?

The process can take a long time, especially desktop packages and Maturin.

Continue?" 10 60

if (( $? != 0 )); then
    clear
    exit 0
fi

# Ensure repositories required by the setup are available.
pkg update -y >> "$LOG_FILE" 2>&1
pkg install -y tur-repo x11-repo dialog >> "$LOG_FILE" 2>&1

for item in $choices; do
    case "$item" in
        toolchain) install_toolchain ;;
        python) install_python ;;
        web) install_web ;;
        languages) install_other_languages ;;
        debugging) install_debugging ;;
        lsp) install_lsp ;;
        neovim) install_neovim ;;
        zsh) install_zsh ;;
        desktop) install_desktop ;;
        desktopconfig) install_desktop_configs ;;
        networking) install_networking ;;
        cli) install_cli ;;
        graphics) install_graphics ;;
        qemu) install_qemu ;;
        pythonapps) install_python_apps ;;
        themes) install_themes ;;
        termuxconfig) install_termux_config ;;
        cleanup) cleanup ;;
    esac
done

dialog --title "Installation Complete" \
    --msgbox \
"Termux Plus installation finished.

Your selected components have been processed.

Log:
$LOG_FILE

Restart your shell or Termux if required." 12 70

clear
