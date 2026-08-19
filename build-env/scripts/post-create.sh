#!/bin/bash

exec 2>&1 1> /tmp/pecunia-env-post-create.log

HOST_MOUNT_PATH=$HOME/host
FILES_TO_SYMLINK=(
    .bashrc
    .bash_aliases
    .bash_history
    .bashrc_devcontainer
    .gitconfig
    .ssh
    .vim
    .vimrc
)

# Fixing the workspace access
git config --global --add safe.directory /workspace

# Unlinking the .ssh folder if it's not a symlink
SSH_FOLDER="$HOME/.ssh"
if [[ -d "${SSH_FOLDER}" && ! -L "${SSH_FOLDER}" ]]; then
    rm -f "${SSH_FOLDER}/known_hosts"
    if [[ -z "$(ls -A ${SSH_FOLDER})" ]]; then
        echo "Unlinking the ${SSH_FOLDER} file"
        rm -fr "${SSH_FOLDER}"
    fi
fi

# Copying user folders (that are not copied by default by the vscode setup)
for file in .saml2aws; do
    what=$HOME/host/$file
    to=$HOME/$file
    if [[ -f $what || -d $what ]]; then
        cp -rv $what $to || echo "Failed to copy $what -> $to"
    else
        echo "File $what doesn't exist"
    fi
done

# Symlinking 
for file in ${FILES_TO_SYMLINK[@]}; do
    what=$HOME/host/$file
    to=$HOME/$file
    if [[ -f $what || -d $what ]]; then
        ln -sf $what $to || echo "Failed to symlink $what -> $to"
    else
        echo "File $what doesn't exist"
    fi
done

# Fix hostname
expected_host=$(hostname)
grep ${expected_host} /etc/hosts || (echo "127.0.0.1 ${expected_host}" | sudo tee -a /etc/hosts)

[ -f $HOME/.bash_aliases ] && echo "source $HOME/.bash_aliases" >> $HOME/.bashrc


# Setup the git
git config -f ~/.gitconfig core.hooksPath /.githooks


# Setup the pecunia env
if [ -z "$PECUNIA_SRC" ]; then
    echo "PECUNIA_SRC is not set. Please set it to the path of the pecunia src repository."
    exit 1
fi

if [ ! -d "$PECUNIA_SRC" ]; then
    echo "PECUNIA_SRC is not a directory. Please set it to the path of the pecunia src repository."
    exit 1
fi

if [ -z "$PECUNIA_SCRIPT_DIR" ]; then
    echo "PECUNIA_SCRIPT_DIR is not set. Please set it to the path of the pecunia src repository."
    exit 1
fi