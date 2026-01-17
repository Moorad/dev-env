#!/usr/bin/env bash
set -euo pipefail

GREEN=2
YELLOW=3
BLUE=4
PURPLE=5
CYAN=6

function pretty_print() {
	gum style --foreground $1 "$2"
}

function announce() {
	message=$(printf "$1")
	gum style --border="normal" --align="center" --padding="1 2" "$message"
}

function backup() {
	FILE_PATH=$1
	FILE=$(basename "$FILE_PATH")
	BACKUP_LOCATION=/var/tmp/$FILE.backup

	sudo cp $FILE_PATH $BACKUP_LOCATION
	pretty_print $CYAN "Backed up $FILE to $BACKUP_LOCATION"
}

function replace() {
	FILE_1=$1
	FILE_2=$2
	cp $FILE_1 $FILE_2
	pretty_print $GREEN "Replaced $(basename $FILE_2)"
}

function check_replace() {
	dev_env_location=$1
	original_location=$2
	file="$(basename $(dirname $dev_env_location)) config"
	color=$YELLOW

	if [[ $file == "bin config" ]]; then
		file="$(basename $dev_env_location) script"
		color=$PURPLE
	fi

	pretty_print $color "Checking $file"

	if [ ! -f $original_location ]; then
		pretty_print $CYAN "It seems like the $file does not exist in your system"
		mkdir -p $(dirname $original_location)
		touch $original_location
		pretty_print $GREEN "Copying over $file"
		cp $dev_env_location $original_location
		return
	fi

	has_diff=$(
		cmp -s $original_location $dev_env_location
		echo $?
	)

	if [[ $has_diff -eq 1 ]] && ! git diff --no-index $original_location $dev_env_location; then
		if gum confirm "Do you want to replace your $file anyways"; then
			backup $original_location
			replace $dev_env_location $original_location
		fi
	else
		echo "No difference in $file"
		return 1
	fi
}

pretty_print $YELLOW "Checking brew formulae and casks"
if ! (cd ./config/brew && brew bundle check --verbose --no-upgrade); then
	(cd ./config/brew && brew bundle install --no-upgrade)
fi

check_replace ./config/zsh/.zshrc ~/.zshrc && announce "Reload your zshrc to apply the changes to the current shell:\n\nsource ~/.zshrc"

check_replace ./config/tmux/.tmux.conf ~/.tmux.conf && announce "Reload your tmux config to apply the changes to the current session:\n\ntmux source-file ~/.tmux.conf"

check_replace ./config/vim/.vimrc ~/.vimrc || true

check_replace ./config/ghostty/config ~/.config/ghostty/config && announce "Reload your ghostty config to apply the changes:\n\n⌘ + SHIFT + ,"

check_replace ./config/lazygit/config.yml ~/.config/lazygit/config.yml || true

pretty_print $YELLOW "Checking scripts"
for FILE in "./scripts/bin"/*; do
	SCRIPT_NAME=$(basename $FILE)
	check_replace $FILE ~/scripts/bin/$SCRIPT_NAME || true
done
