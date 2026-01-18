# Dotfiles setup

### 🍎 MacOS

```bash
# Clone dotfiles
$ git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles

# Make setup script executable
$ chmod +x ~/.dotfiles/setup.sh ~/.dotfiles/scripts/*.sh

# Run interactive setup (select components to install)
$ ~/.dotfiles/setup.sh

# Or run in dry-run mode to preview changes
$ ~/.dotfiles/setup.sh --dry-run
```

#### What gets configured:
- **Prerequisites**: Xcode Command Line Tools
- **Homebrew**: Package manager + shell environment
- **Development Tools**: git, wget, neovim, zoxide, fzf, nvm
- **Zsh**: Oh My Zsh + Powerlevel10k theme
- **Fonts**: Nerd Fonts (FiraCode, JetBrainsMono)
- **macOS Settings**: Dark mode, Finder preferences, keyboard repeat
- **Dotfiles**: Symlinks for .zshrc, .gitconfig, .editorconfig, etc.

#### Modular scripts:
Each component can also be run independently:
```bash
$ ~/.dotfiles/scripts/prerequisites.sh
$ ~/.dotfiles/scripts/devtools.sh
$ ~/.dotfiles/scripts/zsh.sh
$ ~/.dotfiles/scripts/fonts.sh
$ ~/.dotfiles/scripts/macos-settings.sh
$ ~/.dotfiles/scripts/dotfiles.sh
```

---

### 🐧 WSL 2

```bash
# Update system packages
$ sudo apt update && apt upgrade

# Setup SSH keys
$ ssh-keygen

# Install ZSH
$ sudo apt install zsh -y

# Install Oh My Zsh
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Homebrew
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install common brew formulas
$ brew install bash curl git nvm pnpm php vim wget

# Install keychain for SSH passphrase persistence
$ sudo apt install keychain -y

# Add passphrase to keychain
$ ssh-add -K ~/.ssh/ed_25519

# Clone dotfiles
$ git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles

# Make setup script executable
$ chmod +x ~/.dotfiles/setup.sh

#	Setup symlinks
$ ~/.dotfiles/setup.sh

# Create Workspace dir
$ mkdir ~/Workspace
```
