echo "Checking brew formulae and casks"
if !(brew bundle check --verbose --no-upgrade); then
  brew bundle install --no-upgrade
else
  echo "No formulae or casks need to be installed."
fi

if [ ! -d ~/.config/tmux/plugins/catppuccin ]; then
  mkdir -p ~/.config/tmux/plugins/catppuccin
  git clone -b v2.1.3 https://github.com/catppuccin/tmux.git ~/.config/tmux/plugins/catppuccin/tmux
fi
