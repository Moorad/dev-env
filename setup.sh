#!/usr/bin/env bash
set -euo pipefail

function announce() {
	message=$(printf "$1")
	gum style --border="normal" --align="center" --padding="1 2" "$message"
}

function backup() {
	FILE_PATH=$1
	FILE=$(basename "$FILE_PATH")
	BACKUP_LOCATION=/var/tmp/$FILE.backup

	sudo cp $FILE_PATH $BACKUP_LOCATION
	echo "Backed up $FILE to $BACKUP_LOCATION"
}

function replace() {
	FILE_1=$1
	FILE_2=$2
	cp $FILE_1 $FILE_2
	echo "Replaced $(basename $FILE_2)"
}

function check_replace() {
	dev_env_location=$1
	original_location=$2
	file=$(basename $(dirname $dev_env_location))

	echo ""
	echo "Checking $file config"
	if ! git diff --no-index $original_location $dev_env_location; then
		if gum confirm "Do you want to replace your $file anyways"; then
			backup $original_location
			replace $dev_env_location $original_location
		fi
	else
		echo "No difference in $file config"
		return 1
	fi
}

echo "Checking brew formulae and casks"
if ! (cd ./config/brew && brew bundle check --verbose --no-upgrade); then
	(cd ./config/brew && brew bundle install --no-upgrade)
fi

check_replace ./config/zsh/.zshrc ~/.zshrc && announce "Reload your zshrc to apply the changes to the current shell:\n\nsource ~/.zshrc"

check_replace ./config/tmux/.tmux.conf ~/.tmux.conf && announce "Reload your tmux config to apply the changes to the current session:\n\ntmux source-file ~/.tmux.conf"

check_replace ./config/vim/.vimrc ~/.vimrc || true

check_replace ./config/ghostty/config ~/.config/ghostty/config && announce "Reload your ghostty config to apply the changes:\n\n⌘ + SHIFT + ,"

check_replace ./config/lazygit/config.yml ~/.config/lazygit/config.yml || true
