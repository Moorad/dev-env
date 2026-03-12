#if !(omz version); then
#	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
#fi

mkdir -p "$HOME/.zsh"

git clone https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

pacman -S stow zoxide fzf ghostty neovim ttf-fira-code
