#!/bin/sh

# Identify which OS we are running on
OS="$(uname -s)"

# Prompt user for confirmation
echo "Are you sure you want to run this setup on $OS? (y/n)"
read -n 1 -r -s response
echo # Move to next line after key press
if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
	echo "\033[33mSetup cancelled by user.\033[0m"
	exit 0
fi

echo "\033[34mRunning setup for $OS...\033[0m"

# Common setup steps for all OSes can go here
# For example, installing common packages or tools
echo "\033[34mInstalling common packages...\033[0m"
if [ "$OS" = "Linux" ]; then
	sudo apt update
	sudo apt install -y git curl wget
elif [ "$OS" = "Darwin" ]; then
	# homebrew installation
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	# homebrew post-install setup
	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/"$USER"/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
	# install packages
	brew update
	brew upgrade
	brew install zoxide nvim fzf powerlevel10k
fi

# Clone dotfiles repository and create symlinks
git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles

if [ -d ~/.dotfiles/.oh-my-zsh ]; then
	echo "\033[34mSetting up Oh My Zsh...\033[0m"
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
ln -s ~/.dotfiles/.editorconfig ~/.editorconfig
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/wsl/.bashrc ~/.bashrc
ln -s ~/.dotfiles/wsl/.p10k.zsh ~/.p10k.zsh
ln -s ~/.dotfiles/wsl/.profile ~/.profile
ln -s ~/.dotfiles/wsl/.zprofile ~/.zprofile
ln -s ~/.dotfiles/wsl/.zshrc ~/.zshrc
ln -s ~/.dotfiles/wsl/.ssh/config ~/.ssh/config

# OS-specific setup steps
if [ "$OS" = "Linux" ]; then
	echo "\033[34mRunning Linux-specific setup...\033[0m"
	# Linux-specific commands go here
elif [ "$OS" = "Darwin" ]; then
	echo "\033[34mRunning macOS-specific setup...\033[0m"
	# macOS-specific commands go here
fi
