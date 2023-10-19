# Dotfiles setup

### 🍎 MacOS

_TODO: add macOS instructions_

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
