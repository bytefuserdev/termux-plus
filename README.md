# Termux Plus

A modular, interactive development environment for [Termux](https://termux.dev/) on Android.

Termux Plus provides an optional collection of development toolchains, Neovim, Xfce4/Termux:X11, networking and server software, graphics libraries, Python tooling, QEMU, and desktop applications.

The installation is **modular**: you choose what you want to install instead of installing the entire environment.

## Highlights

- Interactive `dialog`-based installer
- Select only the components you need
- C/C++ and LLVM development
- Python, `uv`, Django, Flask, Jupyter, Meson, and Maturin
- Rust, Go, Node.js, Java, Perl, and PHP
- Neovim + NvChad with repository-provided configuration
- Zsh + Oh My Zsh + Powerlevel10k
- Xfce4 + Termux:X11 and optional desktop applications
- Apache, Nginx, Gitea, and networking tools
- QEMU x86-64 emulation
- SDL2, GLFW, GLEW, GLM, Mesa, and OpenCV
- Repository-provided fonts, themes, icons, cursor, and wallpaper

## Requirements

- Android device with Termux installed
- Internet connection
- Sufficient storage for the components you select
- At least **12 GB free space** is recommended for a large/full installation

> This project is designed for Termux. It does not require a Linux distribution running through `proot`.

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/bytefuserdev/termux-plus.git
cd termux-plus
chmod +x scripts/install.sh
./scripts/install.sh
```

The installer will automatically install `dialog` if it is not already installed.

### Selecting components

The installer opens a checklist. Press **Space** to select or deselect an item, then press **Enter** to continue.

Available component groups include:

| Component | Installs |
|---|---|
| Basic utilities | Git, curl, wget, unzip, tar |
| Termux repositories | TUR and Termux:X11 repositories |
| Zsh | Zsh, Oh My Zsh, Powerlevel10k, syntax highlighting, font |
| C/C++ | Clang, LLVM, linker, build tools, MLIR, Bear |
| Node.js | Node.js and npm |
| Debugging | LLDB, GDB, strace, ldd, Rizin |
| Build tools | CMake, Make, Ninja, Autotools, pkg-config |
| Python | Python and `uv` |
| Go | Go toolchain |
| Rust | Rust toolchain |
| Development utilities | GitHub CLI, NASM, libtool, CPIO, and related tools |
| Java | OpenJDK 21 |
| Perl + PHP | Perl and PHP |
| Language servers | `neocmakelsp`, `asm-lsp`, Pyrefly, Ruff |
| Neovim | Neovim, NvChad starter, and project configuration |
| Desktop | Xfce4, Termux:X11, Firefox, VLC, GIMP, LibreOffice, and others |
| Graphical tools | GHex and JADX |
| Networking | Apache, Nginx, Gitea, and networking utilities |
| CLI tools | `fzf`, `tmux`, `bat`, `fd`, `lsd`, `fastfetch`, `yt-dlp`, and others |
| Graphics | Mesa, SDL2, GLFW, GLEW, GLM, OpenCV |
| QEMU | x86-64 system and user emulation |
| Python libraries | NumPy, Pandas, Matplotlib, psutil, Tkinter |
| Web Python | Django and Flask |
| Jupyter | Jupyter, JupyterLab LSP, Ruff integration |
| Python build | Meson and Maturin |
| Termux configuration | Project `termux.properties` |
| Xfce configuration | Project themes, icons, cursor, and wallpaper |
| Font | Repository font installed system-wide |
| Startup | Shell variables, aliases, MOTD handling, and directories |
| Cleanup | APT, pip, and npm cache cleanup |
| Remove plugins | Removes the optional Xfce plugins listed by the original setup |

## Repository Structure

```text
.
├── LICENSE
├── README.md
├── assets
│   ├── font
│   │   └── font.ttf
│   ├── icons
│   │   ├── cursor.zip
│   │   └── icons.tar.gz
│   ├── theme
│   │   └── theme.tar.xz
│   └── wallpaper
│       └── wallpaper.jpg
├── configs
│   ├── neovim
│   │   ├── init.lua
│   │   └── lspconfig.lua
│   └── termux
│       └── termux.properties
└── scripts
    └── install.sh
```

The repository is self-contained for its custom assets and configuration files. The installer does not need to download those files from the repository after cloning it.

## Project Files

### `assets/`

Contains the custom resources used by the setup:

- Terminal font
- Xfce/GTK theme archive
- Icon archive
- Cursor archive
- Wallpaper

### `configs/`

Contains configuration files installed by the script:

- Neovim configuration
- Neovim LSP configuration
- Termux properties

### `scripts/install.sh`

The interactive installer. It handles package installation, configuration deployment, and optional cleanup based on the selections made in the `dialog` interface.

## Neovim

If Neovim is selected, the installer:

1. Installs Neovim and Lua.
2. Clones the NvChad starter configuration when no Neovim configuration exists.
3. Removes the starter Git metadata.
4. Installs the project's `init.lua` and `lspconfig.lua` files.

After installation, start Neovim with:

```bash
nvim
```

Tree-sitter parsers can then be installed from inside Neovim, for example:

```vim
:TSInstall python bash lua c cpp rust asm java go yaml json xml
```

## Desktop Environment

The desktop portion uses **Xfce4 with Termux:X11**. It is optional and can be skipped completely from the installer.

When Xfce configuration is selected, the installer uses the resources stored in `assets/` instead of downloading them separately.

## Configuration After Installation

If the startup component is selected, the installer adds the following environment variables and aliases to `.zshrc`:

```bash
export DISPLAY=:0
export CARGO_BUILD_JOBS=1
export ANDROID_API_LEVEL=31

alias ls="lsd"
alias cat="bat"
alias neofetch="fastfetch"

source <(fzf --zsh)
```

Restart the shell or run:

```bash
exec zsh
```

## Logs

Installation output is written to:

```text
$HOME/termux-plus-install.log
```

If an installation step fails, check this file for the command output.

## Updating Termux

The project does not automatically perform repeated upgrades. You can update Termux packages manually with:

```bash
apt update && apt upgrade -y
```

## Notes

- You can run the installer again and select additional components later.
- Existing Neovim configuration is not overwritten automatically.
- The installer only deploys project files when the corresponding component is selected.
- Some packages are architecture-dependent and may not be available on every Termux architecture.
- Some desktop packages require the Termux:X11 repository.
- Maturin may take considerably longer to install because dependencies can require native compilation on Android.

## License

See [`LICENSE`](LICENSE).
