#!/usr/bin/env bash
set -euo pipefail

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

if ! brew bundle check --verbose --no-upgrade; then
	brew bundle install --no-upgrade
fi

echo "Checking .zshrc"
if ! git --no-pager diff --no-index  ~/.zshrc ./.zshrc; then
	if gum confirm "Do you want to replace your .zshrc anyways"; then
		backup ~/.zshrc
		replace ./.zshrc ~/.zshrc 
		gum style --border="normal" --align="center" --padding="1 2" "$(cat <<'EOF'
Reload your zshrc to apply the changes to the current shell:

source ~/.zshrc
EOF
)"
	fi
else 
	echo "No difference in .zshrc"
fi

