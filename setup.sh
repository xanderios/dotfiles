#!/bin/sh
git clone https://github.com/xanderios/dotfiles.git ~/.dotfiles
ln -s ~/.dotfiles/.editorconfig ~/.editorconfig
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/wsl/.bashrc ~/.bashrc
ln -s ~/.dotfiles/wsl/.p10k.zsh ~/.p10k.zsh
ln -s ~/.dotfiles/wsl/.profile ~/.profile
ln -s ~/.dotfiles/wsl/.zprofile ~/.zprofile
ln -s ~/.dotfiles/wsl/.zshrc ~/.zshrc
ln -s ~/.dotfiles/wsl/.ssh/config ~/.ssh/config
