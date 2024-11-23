#!/usr/bin/env bash

set -e
set -v

cd "$(dirname "${BASH_SOURCE[0]}")"
git pull origin main

function install_mac_dependencies() {

  # Check the current path of the active developer directory
  XCODE_PATH=$(xcode-select -p 2>/dev/null)

  # Verify if it contains "CommandLineTools"
  if [[ "$XCODE_PATH" == *"CommandLineTools"* ]]; then
    echo "Command Line Tools are already installed at $XCODE_PATH."
  else
    echo "Command Line Tools are not installed. Initiating installation..."
    xcode-select --install

    # Inform the user to complete the installation if needed
    echo "Please follow the on-screen instructions to complete the installation."
  fi

  # Check if Homebrew is installed, install if not
  if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  # Update Homebrew and install packages
  echo "Updating Homebrew and installing packages..."
  brew update
  brew install openssl readline sqlite3 xz jq zlib tcl-tk zsh
}

function install_linux_dependencies() {
  if [ -f /etc/debian_version ]; then
    echo "Installing packages on Debian/Ubuntu..."
    sudo apt update
    sudo apt install -y wget tar zsh gpg build-essential \
                        libssl-dev zlib1g-dev libbz2-dev libreadline-dev \
                        libsqlite3-dev curl libncursesw5-dev xz-utils tk-dev \
                        libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev \
                        pinentry-tty nano unzip util-linux jq bsdmainutils locales
  elif [ -f /etc/arch-release ]; then
    echo "Installing packages on Arch Linux..."
    sudo pacman -Syu --noconfirm wget tar zsh gnupg base-devel \
                            openssl zlib bzip2 readline sqlite xz \
                            tk xmlsec libffi lzma jq pinentry nano unzip
  else
    echo "Unsupported Linux distribution"
    exit 1
  fi
}

function change_shell_to_zsh() {
  if [ "$SHELL" != "$(which zsh)" ]; then
    if [ "$CHSH_QUIET" != "true" ]; then
      read -p "Change your default shell to zsh? (Y/n) " -n 1 response
      echo ""
      if [[ ! "$response" =~ ^[Nn]$ ]]; then
        chsh -s "$(which zsh)"
      fi
    else
      chsh -s "$(which zsh)"
    fi
  fi
}

function install_asdf() {
  if [ ! -d "$HOME/.asdf" ]; then
    echo "Installing asdf..."
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1

  fi
}

function install_starship() {
  if ! command -v starship &>/dev/null; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
  fi
}

function ensure_direnv_plugin() {
  if ! asdf plugin-list | grep -q 'direnv'; then
    echo "Adding direnv plugin to asdf..."
    asdf plugin-add direnv https://github.com/asdf-community/asdf-direnv
    asdf direnv setup --no-touch-rc-file --shell zsh --version latest
  fi
}

function ensure_all_asdf_plugins() {
  echo "Ensuring all .tool-versions plugins are added to asdf..."
  cut -d' ' -f1 .tool-versions | xargs -I{} asdf plugin add {}
}

function doIt() {
  rsync --exclude ".git/" \
        --exclude "bootstrap.sh" \
        --exclude "README.md" \
        --exclude ".devcontainer/" \
        --exclude "Makefile" \
        -avh --no-perms /home/vscode/.dotfiles/ ~
  echo "refresh your shell with: source ~/.zshrc"
}

# Check the OS and install required dependencies
if [ "$(uname)" == "Darwin" ]; then
  install_mac_dependencies
else
  install_linux_dependencies
fi

# Change shell to zsh if needed
# change_shell_to_zsh

# Install Starship
install_starship

# Install or update asdf
install_asdf

. /home/$USERNAME/.asdf/asdf.sh

# Ensure direnv plugin for asdf is installed
ensure_direnv_plugin

# Add all plugins from .tool-versions
ensure_all_asdf_plugins

# Execute the main function
if [ "$1" == "--force" -o "$1" == "-f" ]; then
  doIt
else
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    doIt
  fi
fi
