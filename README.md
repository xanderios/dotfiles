# Dotfiles setup

### 🍎 MacOS

*TODO: add macOS instructions*

---

### 🐧 WSL 2

```bash
# Update system packages
$ sudo apt update && apt upgrade

# Install Homebrew
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

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

# Setup dotfiles symlinks
$ git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles
$ ln -s ~/.dotfiles/.editorconfig ~/.editorconfig
$ ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
$ ln -s ~/.dotfiles/.vimrc ~/.vimrc
$ ln -s ~/.dotfiles/README.md ~/README.md
$ ln -s ~/.dotfiles/wsl/.bashrc ~/.bashrc
$ ln -s ~/.dotfiles/wsl/.p10k.zsh ~/.p10k.zsh
$ ln -s ~/.dotfiles/wsl/.profile ~/.profile
$ ln -s ~/.dotfiles/wsl/.zprofile ~/.zprofile
$ ln -s ~/.dotfiles/wsl/.zshrc ~/.zshrc

# Create Workspace dir
$ mkdir ~/Workspace
```