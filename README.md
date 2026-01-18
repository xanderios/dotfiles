# Dotfiles setup

## Prerequisites

### Install Ansible
```bash
# macOS
$ brew install ansible

# or via pip
$ pip3 install ansible
```

---

## 🍎 macOS

### Quick Start
```bash
# Clone dotfiles
$ git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles
$ cd ~/.dotfiles

# Run the playbook (interactive)
$ ansible-playbook macos.yml

# Or run specific sections with tags
$ ansible-playbook macos.yml --tags "homebrew,devtools"

# Check what would change (dry-run)
$ ansible-playbook macos.yml --check --diff
```

### Available Tags
- `prerequisites` - Xcode Command Line Tools
- `homebrew` - Homebrew installation and setup
- `devtools` - Development tools (git, wget, neovim, zoxide, fzf, nvm)
- `zsh` - Zsh, Oh My Zsh, Powerlevel10k
- `fonts` - Nerd Fonts
- `macos-settings` - System preferences
- `dotfiles` - Dotfile symlinks
- `cleanup` - Homebrew cleanup

### Non-interactive Mode
Create a variables file to skip prompts:

```bash
$ cat > vars.yml <<EOF
setup_prerequisites: yes
setup_homebrew: yes
setup_devtools: yes
setup_zsh: yes
setup_fonts: yes
setup_macos_settings: yes
setup_dotfiles: yes
EOF

$ ansible-playbook macos.yml -e @vars.yml
```

---

## 🐧 WSL 2

### Quick Start
```bash
# Clone dotfiles
$ git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles
$ cd ~/.dotfiles

# Run the playbook
$ ansible-playbook wsl.yml --ask-become-pass

# Or check what would change
$ ansible-playbook wsl.yml --check --diff --ask-become-pass
```

### Manual Steps
```bash
# Generate SSH key
$ ssh-keygen

# Add passphrase to keychain
$ ssh-add -K ~/.ssh/ed_25519
```

---

## Manual Shell Scripts (Legacy)

The old shell script setup is still available in the `scripts/` directory:

```bash
# Run interactive setup
$ ./setup.sh

# Or run in dry-run mode
$ ./setup.sh --dry-run
```

---

## What Gets Configured

### Development Tools
- git, wget, neovim, zoxide, fzf, nvm
- Homebrew (macOS/WSL package manager)

### Shell Environment
- Zsh with Oh My Zsh
- Powerlevel10k theme (macOS)
- Shell completions and integrations

### Fonts
- FiraCode Nerd Font
- JetBrainsMono Nerd Font

### macOS Settings
- Dark mode
- Show file extensions in Finder
- Show hidden files
- Fast keyboard repeat

### Dotfiles
Symlinks for:
- `.editorconfig`
- `.gitconfig`
- `.zshrc`
- `.zprofile`
- `.p10k.zsh`
