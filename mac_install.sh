echo "Checking brew formulae and casks"
if !(brew bundle check --verbose --no-upgrade); then
	brew bundle install --no-upgrade
else
	echo "No formulae or casks are pending for install."
fi
