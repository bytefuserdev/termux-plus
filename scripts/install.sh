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

mkdir -p "$(dirname "$LOG_FILE")"
: > "$LOG_FILE"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

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

# Run a command and show its real-time stdout/stderr in a dialog program box.
# The complete output is also written to the installer log.
run_live_cmd() {
    local title="$1"
    shift
    local -a command=("$@")

    printf '\n>>> %q' "${command[0]}" >> "$LOG_FILE"
    printf ' %q' "${command[@]:1}" >> "$LOG_FILE"
    printf '\n' >> "$LOG_FILE"

    "${command[@]}" 2>&1 | tee -a "$LOG_FILE" | dialog \
        --title "$title" \
        --programbox \
        24 100

    local -a pipe_status=("${PIPESTATUS[@]}")
    return "${pipe_status[0]}"
}

run_live_shell() {
    local title="$1"
    local command="$2"

    printf '\n>>> %s\n' "$command" >> "$LOG_FILE"

    bash -c "$command" 2>&1 | tee -a "$LOG_FILE" | dialog \
        --title "$title" \
        --programbox \
        24 100

    local -a pipe_status=("${PIPESTATUS[@]}")
    return "${pipe_status[0]}"
}

pkg_install() {
    local title="$1"
    shift
    local -a packages=("$@")

    ((${#packages[@]})) || return 0
    run_live_cmd "$title" pkg install -y "${packages[@]}"
}

show_error() {
    local message="$1"
    dialog --title "Installation Error" \
        --msgbox "$message\n\nSee:\n$LOG_FILE" 12 75
}

append_unique() {
    local component="$1"
    local package="$2"
    local current="${SELECTED[$component]-}"

    case " $current " in
        *" $package "*) ;;
        *) SELECTED[$component]="${current:+$current }$package" ;;
    esac
}

# Store only packages the user selected. Components are reviewed one at a time.
declare -A SELECTED=()
declare -A SELECTED_FLAGS=()

select_packages() {
    local component="$1"
    local title="$2"
    local help_text="$3"
    shift 3

    local current="${SELECTED[$component]-}"
    local -a checklist=("$@")
    local -a normalized=()
    local i package description state

    # Rebuild the checklist so packages already selected in this component
    # appear selected when the user re-enters it.
    for ((i=0; i<${#checklist[@]}; i+=3)); do
        package="${checklist[i]}"
        description="${checklist[i+1]}"
        state="${checklist[i+2]}"

        case " $current " in
            *" $package "*) state="ON" ;;
        esac

        normalized+=("$package" "$description" "$state")
    done

    local choices
    choices=$(dialog --stdout --title "$title" --checklist \
        "$help_text" \
        24 100 16 \
        "${normalized[@]}")

    local status=$?
    ((status == 0)) || return 1

    # Replace the component's previous selection with the current checklist.
    SELECTED["$component"]=""
    for package in $choices; do
        package="${package#\"}"
        package="${package%\"}"
        append_unique "$component" "$package"
    done

    return 0
}

select_config_items() {
    local flag_name="$1"
    local title="$2"
    local help_text="$3"
    shift 3

    local choices
    choices=$(dialog --stdout --title "$title" --checklist \
        "$help_text" \
        20 100 8 \
        "$@")

    local status=$?
    ((status == 0)) || return 1

    SELECTED_FLAGS["$flag_name"]=""
    local item
    for item in $choices; do
        item="${item#\"}"
        item="${item%\"}"
        SELECTED_FLAGS["$flag_name"]+="${SELECTED_FLAGS[$flag_name]:+ }$item"
    done

    return 0
}

# -----------------------------------------------------------------------------
# Installation actions
# -----------------------------------------------------------------------------

install_zsh() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing Zsh packages" "${packages[@]}" || return $?

    case " ${SELECTED[zsh]-} " in
        *" zsh "*)
            local font="$REPO_DIR/assets/font/font.ttf"
            mkdir -p "$HOME/.termux"
            copy_if_exists "$font" "$HOME/.termux/font.ttf" || return $?

            if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
                if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1; then
                    dialog --title "Zsh setup skipped" \
                        --msgbox "Oh My Zsh needs both curl and git.

Select curl and git in the Zsh component and run the installer again." 10 70
                    return 0
                fi

                run_live_shell "Installing Oh My Zsh" \
                    'yes | sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"' || return $?
            fi

            local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

            if [[ ! -d "$custom/themes/powerlevel10k" ]]; then
                run_live_cmd "Installing Powerlevel10k" git clone --depth=1 \
                    https://github.com/romkatv/powerlevel10k.git \
                    "$custom/themes/powerlevel10k" || return $?
            fi

            if [[ ! -d "$custom/plugins/zsh-syntax-highlighting" ]]; then
                run_live_cmd "Installing zsh-syntax-highlighting" git clone \
                    https://github.com/zsh-users/zsh-syntax-highlighting.git \
                    "$custom/plugins/zsh-syntax-highlighting" || return $?
            fi

            if [[ -f "$HOME/.zshrc" ]]; then
                cp "$HOME/.zshrc" "$HOME/.zshrc.termux-plus.backup"
            fi

            if ! grep -q 'powerlevel10k/powerlevel10k' "$HOME/.zshrc" 2>/dev/null; then
                printf '\nZSH_THEME="powerlevel10k/powerlevel10k"\n' >> "$HOME/.zshrc"
            fi
            ;;
    esac
}

install_neovim() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing Neovim packages" "${packages[@]}" || return $?

    case " ${SELECTED[neovim]-} " in
        *" neovim "*)
            if [[ ! -d "$HOME/.config/nvim" ]]; then
                if ! command -v git >/dev/null 2>&1; then
                    dialog --title "Neovim setup skipped" \
                        --msgbox "The NvChad starter needs git.

Select git in the Neovim component and run the installer again." 10 70
                    return 0
                fi

                run_live_cmd "Installing NvChad starter" git clone \
                    https://github.com/NvChad/starter "$HOME/.config/nvim" || return $?
            fi

            if [[ -d "$HOME/.config/nvim/.git" ]]; then
                rm -rf "$HOME/.config/nvim/.git"
            fi

            mkdir -p "$HOME/.config/nvim/lua/configs"

            copy_if_exists \
                "$REPO_DIR/configs/neovim/lspconfig.lua" \
                "$HOME/.config/nvim/lua/configs/lspconfig.lua" || return $?

            copy_if_exists \
                "$REPO_DIR/configs/neovim/init.lua" \
                "$HOME/.config/nvim/lua/plugins/init.lua" || return $?
            ;;
    esac
}

install_termux_config() {
    mkdir -p "$HOME/.termux"
    copy_if_exists \
        "$REPO_DIR/configs/termux/termux.properties" \
        "$HOME/.termux/termux.properties" || return $?

    if command -v termux-reload-settings >/dev/null 2>&1; then
        termux-reload-settings
    fi
}

install_desktop() {
    local package_string="$1"
    local -a packages=()
    read -r -a packages <<< "$package_string"
    pkg_install "Installing desktop packages" "${packages[@]}"
}

install_themes() {
    local tmp="$HOME/.cache/termux-plus"
    mkdir -p "$tmp"

    local theme="$REPO_DIR/assets/theme/theme.tar.xz"
    local icons="$REPO_DIR/assets/icons/icons.tar.gz"
    local cursor="$REPO_DIR/assets/icons/cursor.zip"
    local wallpaper="$REPO_DIR/assets/wallpaper/wallpaper.jpg"

    pkg_install "Installing theme tools" unzip || return $?
    mkdir -p "$PREFIX/share/themes" "$PREFIX/share/icons"

    if [[ -f "$theme" ]]; then
        run_live_shell "Extracting GTK theme" \
            "tar -xJf '$theme' -C '$tmp' && find '$tmp' -maxdepth 2 -type d -name 'Orchis*' -exec cp -r {} '$PREFIX/share/themes/' \\;" || return $?
    fi

    if [[ -f "$icons" ]]; then
        run_live_shell "Extracting icon theme" \
            "tar -xzf '$icons' -C '$tmp' && find '$tmp' -maxdepth 2 -type d \\( -name 'kora*' -o -name 'Kora*' \\) -exec cp -r {} '$PREFIX/share/icons/' \\;" || return $?
    fi

    if [[ -f "$cursor" ]]; then
        run_live_shell "Installing cursor theme" \
            "unzip -o '$cursor' -d '$tmp/cursor' && find '$tmp/cursor' -maxdepth 2 -type d -name 'ArcAurora*' -exec cp -r {} '$PREFIX/share/icons/' \\;" || return $?
    fi

    if [[ -f "$wallpaper" ]]; then
        run_live_shell "Installing wallpaper" \
            "mkdir -p '$HOME/Pictures' && cp -f '$wallpaper' '$HOME/Pictures/termux-plus-wallpaper.jpg'" || return $?
    fi
}

install_desktop_configs() {
    local config_dir="$REPO_DIR/configs/desktop"
    local tmp="$HOME/.cache/termux-plus/desktop-configs"
    local selected="${SELECTED_FLAGS[desktopconfig]-}"

    mkdir -p "$tmp" "$HOME/.config"

    if [[ ! -d "$config_dir" ]]; then
        show_error "Desktop configuration directory was not found:\n\n$config_dir"
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

        run_live_shell "Extracting $config_name configuration" \
            "tar -xf '$archive_path' -C '$extract_dir'" || return $?

        local source_dir
        source_dir="$(find "$extract_dir" -mindepth 1 -type d -name "$config_name" -print -quit)"

        # Flat archive (no "$config_name" folder inside): use the extraction directory itself.
        if [[ -z "$source_dir" && -n "$(ls -A "$extract_dir")" ]]; then
            source_dir="$extract_dir"
        fi

        if [[ -z "$source_dir" ]]; then
            dialog --msgbox \
                "Could not find '$config_name' inside:\n\n$archive_path\n\nThe archive was extracted to:\n$extract_dir" \
                12 70
            return 1
        fi

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

    case " $selected " in *" xfce4 "*) extract_config_archive "xfce4.tar" "xfce4" || return $? ;; esac
    case " $selected " in *" plank "*) extract_config_archive "plank.tar" "plank" || return $? ;; esac
    case " $selected " in *" eww "*) extract_config_archive "eww.tar" "eww" || return $? ;; esac
    case " $selected " in *" autostart "*) extract_config_archive "autostart.tar" "autostart" || return $? ;; esac
}

install_toolchain() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing C/C++ toolchain" "${packages[@]}"
}

install_python() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing Python environment" "${packages[@]}"
}

install_web() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing web development packages" "${packages[@]}"
}

install_other_languages() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing other languages" "${packages[@]}"
}

install_debugging() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing debugging tools" "${packages[@]}"
}

install_lsp() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing language servers" "${packages[@]}"
}

install_networking() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing networking/server tools" "${packages[@]}"
}

install_cli() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing CLI utilities" "${packages[@]}"
}

install_graphics() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing graphics libraries" "${packages[@]}"
}

install_qemu() {
    local -a packages=()
    read -r -a packages <<< "$1"
    pkg_install "Installing QEMU" "${packages[@]}"
}

install_python_apps() {
    local -a packages=()
    read -r -a packages <<< "$1"
    local package

    # Native Termux packages selected in this component are installed first.
    local -a native_packages=()
    for package in "${packages[@]}"; do
        case "$package" in
            python-rpds-py) native_packages+=("$package") ;;
        esac
    done
    if ((${#native_packages[@]})); then
        pkg_install "Installing Python app dependencies" "${native_packages[@]}" || return $?
    fi

    case " ${SELECTED[pythonapps]-} " in
        *" django "*|*" flask "*)
            local pip_basic=""
            case " ${SELECTED[pythonapps]-} " in
                *" django "*) pip_basic+=" django" ;;
            esac
            case " ${SELECTED[pythonapps]-} " in
                *" flask "*) pip_basic+=" flask" ;;
            esac
            run_live_shell "Installing Django / Flask" "pip install${pip_basic} --verbose" || return $?
            ;;
    esac

    case " ${SELECTED[pythonapps]-} " in
        *" jupyter "*|*" jupyterlab-lsp "*|*" jupyter-ruff "*)
            local -a jupyter_packages=()
            case " ${SELECTED[pythonapps]-} " in *" jupyter "*) jupyter_packages+=(jupyter) ;; esac
            case " ${SELECTED[pythonapps]-} " in *" jupyterlab-lsp "*) jupyter_packages+=(jupyterlab-lsp) ;; esac
            case " ${SELECTED[pythonapps]-} " in *" jupyter-ruff "*) jupyter_packages+=(jupyter-ruff) ;; esac
            run_live_shell "Installing Jupyter packages" \
                "ANDROID_API_LEVEL=31 CARGO_BUILD_JOBS=4 pip install ${jupyter_packages[*]} --verbose" || return $?
            ;;
    esac

    case " ${SELECTED[pythonapps]-} " in
        *" meson "*|*" maturin "*)
            local -a build_apps=()
            case " ${SELECTED[pythonapps]-} " in *" meson "*) build_apps+=(meson) ;; esac
            case " ${SELECTED[pythonapps]-} " in *" maturin "*) build_apps+=(maturin) ;; esac
            run_live_shell "Installing Meson / Maturin" \
                "ANDROID_API_LEVEL=31 CARGO_BUILD_JOBS=4 pip install ${build_apps[*]} --verbose" || return $?
            ;;
    esac
}

cleanup() {
    run_live_shell "Cleaning Termux" \
        'pkg autoremove -y; pkg clean; pip cache purge; npm cache clean --force || true'
}

# -----------------------------------------------------------------------------
# Component package definitions
# -----------------------------------------------------------------------------

open_component() {
    local component="$1"

    case "$component" in
        toolchain)
            select_packages toolchain "C/C++ / LLVM / Build Tools" \
                "Select the packages to install for the toolchain component." \
                clang "C/C++ compiler" ON \
                binutils "Assembler / linker utilities" OFF \
                llvm-tools "LLVM command-line tools" OFF \
                ndk-multilib "Android NDK multilib support" OFF \
                build-essential "Build-essential meta package" OFF \
                mlir "Multi-Level IR toolchain" OFF \
                bear "Compilation database generator" OFF \
                lld "LLVM linker" OFF \
                autoconf "Autoconf" OFF \
                bison "Parser generator" OFF \
                flex "Lexical analyzer generator" OFF \
                ninja "Ninja build system" OFF \
                pkg-config "Build dependency metadata" OFF \
                automake "Automake" OFF \
                make "GNU Make" OFF \
                cmake "CMake" OFF \
                autoconf-archive "Autoconf macros" OFF \
                xorgproto "X.Org protocol headers" OFF \
                gettext "Internationalization tools" OFF
            ;;
        python)
            select_packages python "Python / Scientific Computing" \
                "Select the Python packages to install." \
                python "Python interpreter" ON \
                uv "Fast Python package manager" OFF \
                python-numpy "NumPy" OFF \
                matplotlib "Matplotlib" OFF \
                python-pandas "Pandas" OFF \
                python-psutil "Process/system utilities" OFF \
                python-tkinter "Tkinter bindings" OFF
            ;;
        web)
            select_packages web "Web Development" \
                "Select the web/server packages to install." \
                nodejs "Node.js runtime" ON \
                npm "Node package manager" OFF \
                apache2 "Apache HTTP server" OFF \
                nginx "Nginx HTTP server" OFF \
                perl "Perl" OFF \
                php "PHP" OFF
            ;;
        languages)
            select_packages languages "Other Languages" \
                "Select additional programming languages to install." \
                golang "Go" ON \
                rust "Rust" OFF \
                openjdk-21 "OpenJDK 21" OFF
            ;;
        debugging)
            select_packages debugging "Debugging / Reverse Engineering" \
                "Select debugging packages to install." \
                lldb "LLVM debugger" ON \
                gdb "GNU debugger" OFF \
                strace "System call tracer" OFF \
                ldd "Library dependency tool" OFF \
                rizin "Reverse engineering framework" OFF
            ;;
        lsp)
            select_packages lsp "Language Servers" \
                "Select language servers to install." \
                neocmakelsp "CMake language server" ON \
                asm-lsp "Assembly language server" OFF \
                pyrefly "Python language server" OFF \
                ruff "Ruff linter / formatter" OFF
            ;;
        neovim)
            select_packages neovim "Neovim" \
                "Select Neovim packages. Selecting neovim also applies the repository configuration." \
                neovim "Neovim editor" ON \
                lua54 "Lua 5.4" OFF \
                git "Git (required for full setup)" ON \
                curl "curl (required for full setup)" ON
            ;;
        zsh)
            select_packages zsh "Zsh Shell" \
                "Select Zsh packages. Selecting zsh also enables Oh My Zsh / Powerlevel10k setup." \
                zsh "Zsh shell" ON \
                zsh-completions "Zsh completions" OFF \
                git "Git (required for full setup)" ON \
                curl "curl (required for full setup)" ON
            ;;
        networking)
            select_packages networking "Networking / Server Tools" \
                "Select networking and self-hosting packages." \
                inetutils "Network utilities" ON \
                iproute2 "IP routing utilities" OFF \
                wget "wget" OFF \
                curl "curl" OFF \
                apache2 "Apache HTTP server" OFF \
                nginx "Nginx HTTP server" OFF \
                gitea "Git hosting service" OFF
            ;;
        cli)
            select_packages cli "CLI Utilities" \
                "Select command-line utilities to install." \
                lsd "Modern ls replacement" ON \
                fastfetch "System information" OFF \
                mandoc "Manual page formatter" OFF \
                cmatrix "Terminal matrix effect" OFF \
                mlocate "File locator" OFF \
                manpages "Manual pages" OFF \
                bat "Modern cat replacement" OFF \
                fd "Modern find replacement" OFF \
                android-tools "ADB / Android utilities" OFF \
                synaptic "Package manager GUI" OFF \
                fzf "Fuzzy finder" OFF \
                tmux "Terminal multiplexer" OFF \
                cava "Audio visualizer" OFF \
                proot-distro "Linux userspace containers" OFF \
                inotify-tools "Filesystem event tools" OFF \
                python-yt-dlp "yt-dlp Python package" OFF \
                tree "Directory tree viewer" OFF
            ;;
        graphics)
            select_packages graphics "Graphics / Multimedia Libraries" \
                "Select graphics and multimedia development packages." \
                mesa-dev "Mesa development files" ON \
                sdl2 "SDL2" OFF \
                sdl2-ttf "SDL2 TrueType" OFF \
                sdl2-image "SDL2 image support" OFF \
                sdl2-mixer "SDL2 audio support" OFF \
                glew "OpenGL extension library" OFF \
                glfw "OpenGL window/input library" OFF \
                glm "OpenGL mathematics library" OFF \
                mesa "Mesa runtime" OFF \
                opencv "OpenCV" OFF
            ;;
        qemu)
            select_packages qemu "QEMU" \
                "Select QEMU packages to install." \
                qemu-system-x86-64 "x86-64 system emulation" ON \
                qemu-utils "QEMU utility tools" OFF \
                qemu-user-x86-64 "x86-64 user-mode emulation" OFF
            ;;
        desktop)
            select_packages desktop "Desktop / Termux:X11" \
                "Select the desktop applications and graphical tools to install." \
                xfce4 "Xfce desktop environment" ON \
                xfce4-goodies "Extra Xfce applications" OFF \
                firefox "Firefox" OFF \
                xfce4-*plugin "Xfce panel plugins" OFF \
                vlc-qt "VLC media player" OFF \
                eww "ElKowars wacky widgets" OFF \
                telegram-desktop "Telegram Desktop" OFF \
                keepassxc "KeePassXC" OFF \
                fontconfig-utils "Font utilities" OFF \
                thunderbird "Thunderbird" OFF \
                inkscape "Inkscape" OFF \
                code-oss "Code - OSS" OFF \
                pavucontrol "PulseAudio volume control" OFF \
                termux-x11-nightly "Termux:X11" OFF \
                gimp "GIMP" OFF \
                plank-reloaded "Plank dock" OFF \
                xfce4-taskmanager "Xfce task manager" OFF \
                xfce4-screenshooter "Xfce screenshot tool" OFF \
                xfce4-appfinder "Xfce application finder" OFF \
                ristretto "Image viewer" OFF \
                parole "Xfce media player" OFF \
                mousepad "Xfce text editor" OFF \
                galculator "Calculator" OFF \
                tigervnc "TigerVNC server" OFF \
                tigervnc-viewer "TigerVNC viewer" OFF \
                libreoffice "LibreOffice" OFF \
                ghex "Hex editor" OFF \
                jadx-x "JADX GUI" OFF
            ;;
        pythonapps)
            select_packages pythonapps "Python Applications / Build Tools" \
                "Select which Python applications/tools to install." \
                django "Django" OFF \
                flask "Flask" OFF \
                python-rpds-py "Termux rpds-py package" OFF \
                jupyter "Jupyter" OFF \
                jupyterlab-lsp "Jupyter LSP integration" OFF \
                jupyter-ruff "Jupyter Ruff integration" OFF \
                meson "Meson" OFF \
                maturin "Maturin" OFF
            ;;
        themes)
            select_config_items themes "Themes / Icons / Wallpaper" \
                "Select the bundled assets to install." \
                themes "GTK theme" OFF \
                icons "Kora icon theme" OFF \
                cursor "ArcAurora cursor theme" OFF \
                wallpaper "Wallpaper" OFF
            ;;
        desktopconfig)
            select_config_items desktopconfig "Desktop Configurations" \
                "Select the bundled desktop configurations to install." \
                xfce4 "Xfce4 configuration" OFF \
                eww "EWW configuration" OFF \
                plank "Plank configuration" OFF \
                autostart "Autostart configuration" OFF
            ;;
        termuxconfig)
            SELECTED_FLAGS[termuxconfig]=1
            dialog --msgbox "The repository Termux configuration will be installed when you start the installation." 8 65
            ;;
        cleanup)
            SELECTED_FLAGS[cleanup]=1
            dialog --msgbox "Cleanup will run after the selected package installations." 8 65
            ;;
    esac
}

# -----------------------------------------------------------------------------
# UI: component browser -> package checklist
# -----------------------------------------------------------------------------

show_welcome() {
    dialog --title "Termux Plus Installer" \
        --msgbox \
"Welcome to Termux Plus.\n\nEnter a component, choose exactly which packages you want inside it, then return to the component list for more selections.\n\nNothing is installed while you are browsing.\n\nInstallation log:\n$LOG_FILE" \
        14 75
}

choose_components() {
    while true; do
        local component
        component=$(dialog --stdout --title "Components" --menu \
            "Enter a component to select its packages. Choose Finish when done." \
            24 100 20 \
            toolchain     "C/C++ / LLVM / build tools" \
            python        "Python / uv / scientific libraries" \
            web           "Node.js / npm / web servers" \
            languages     "Go / Rust / OpenJDK 21" \
            debugging    "GDB / LLDB / tracing / rizin" \
            lsp           "Neovim language servers" \
            neovim        "Neovim + repository configuration" \
            zsh           "Zsh + Oh My Zsh + Powerlevel10k" \
            desktop       "Xfce4 / Termux:X11 / desktop applications" \
            desktopconfig "Xfce4 / Plank / Autostart configuration" \
            networking   "Networking / Gitea / server tools" \
            cli           "CLI utilities / fzf / tmux / yt-dlp" \
            graphics     "Mesa / SDL2 / GLFW / OpenCV" \
            qemu         "QEMU x86-64 emulation" \
            pythonapps   "Django / Flask / Jupyter / build tools" \
            themes       "Themes / icons / cursor / wallpaper" \
            termuxconfig "Repository Termux configuration" \
            cleanup      "Remove unused packages and clean caches" \
            finish       "Start installation with current selections")

        local status=$?
        ((status == 0)) || return 1

        if [[ "$component" == "finish" ]]; then
            return 0
        fi

        open_component "$component" || true
    done
}

show_selection_summary() {
    local summary=""
    local component package packages flags
    local -a components=(toolchain python web languages debugging lsp neovim zsh desktop desktopconfig networking cli graphics qemu pythonapps themes termuxconfig cleanup)

    for component in "${components[@]}"; do
        packages="${SELECTED[$component]-}"
        flags="${SELECTED_FLAGS[$component]-}"

        [[ -z "$packages" && -z "$flags" ]] && continue

        summary+="\n[$component]\n"
        [[ -n "$packages" ]] && summary+="  Packages: $packages\n"
        [[ -n "$flags" ]] && summary+="  Extras: $flags\n"
    done

    if [[ -z "$summary" ]]; then
        dialog --msgbox "No packages or actions have been selected." 8 55
        return 1
    fi

    dialog --title "Selection Summary" --yesno \
        "The following will be processed:$summary\n\nContinue to installation?" \
        24 100
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

show_welcome
choose_components || {
    clear
    exit 0
}

show_selection_summary || {
    clear
    exit 0
}

# Ensure repositories required by the setup are available. This is a
# prerequisite of the installer itself, not a component choice.
if ! run_live_cmd "Updating Termux repositories" pkg update -y; then
    show_error "Could not update the Termux package lists."
    clear
    exit 1
fi

if ! run_live_cmd "Preparing Termux repositories" pkg install -y tur-repo x11-repo dialog; then
    show_error "Could not install the required Termux repositories/dialog package."
    clear
    exit 1
fi

# Install in a stable component order, regardless of the order the user browsed.
for component in \
    toolchain python web languages debugging lsp neovim zsh desktop desktopconfig \
    networking cli graphics qemu pythonapps themes termuxconfig cleanup; do

    packages="${SELECTED[$component]-}"
    [[ -z "$packages" && -z "${SELECTED_FLAGS[$component]-}" ]] && continue

    case "$component" in
        toolchain)     install_toolchain "$packages" || { show_error "Toolchain installation failed."; break; } ;;
        python)        install_python "$packages" || { show_error "Python installation failed."; break; } ;;
        web)           install_web "$packages" || { show_error "Web package installation failed."; break; } ;;
        languages)     install_other_languages "$packages" || { show_error "Language installation failed."; break; } ;;
        debugging)     install_debugging "$packages" || { show_error "Debugging tools installation failed."; break; } ;;
        lsp)           install_lsp "$packages" || { show_error "LSP installation failed."; break; } ;;
        neovim)        install_neovim "$packages" || { show_error "Neovim installation failed."; break; } ;;
        zsh)           install_zsh "$packages" || { show_error "Zsh installation failed."; break; } ;;
        desktop)       install_desktop "$packages" || { show_error "Desktop installation failed."; break; } ;;
        desktopconfig) install_desktop_configs || { show_error "Desktop configuration installation failed."; break; } ;;
        networking)    install_networking "$packages" || { show_error "Networking installation failed."; break; } ;;
        cli)           install_cli "$packages" || { show_error "CLI installation failed."; break; } ;;
        graphics)      install_graphics "$packages" || { show_error "Graphics installation failed."; break; } ;;
        qemu)          install_qemu "$packages" || { show_error "QEMU installation failed."; break; } ;;
        pythonapps)    install_python_apps "$packages" || { show_error "Python applications installation failed."; break; } ;;
        themes)        install_themes || { show_error "Theme installation failed."; break; } ;;
        termuxconfig)  install_termux_config || { show_error "Termux configuration installation failed."; break; } ;;
        cleanup)       cleanup || { show_error "Cleanup failed."; break; } ;;
    esac
done

dialog --title "Installation Complete" \
    --msgbox \
"Termux Plus installation finished.\n\nThe selected components were processed.\n\nLive installation output was shown during installation.\n\nLog:\n$LOG_FILE\n\nRestart your shell or Termux if required." \
    14 75

clear
