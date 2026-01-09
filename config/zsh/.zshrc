export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""

zstyle ':omz:update' mode auto # update automatically without asking

plugins=(git)

source $ZSH/oh-my-zsh.sh

# OMZ theme
fpath+=($HOME/.zsh/pure)
autoload -U promptinit
promptinit
prompt pure

# Paths
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"
export PATH="/Users/mooradaltamimi/go/bin:$PATH"
export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/scripts/bin:$PATH"

eval "$(zoxide init zsh --cmd cd)"
eval "$(fzf --zsh)"

# Zsh plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

if type brew &>/dev/null; then
	FPATH=$(brew --prefix)/share/zsh-completions:$FPATH

	autoload -Uz compinit
	compinit
fi

# Hotkeys
# bindkey '\t' autosuggest-accept
# bindkey '^[^I' complete-word

# Shortcuts
alias g="git"
alias k="kubectl"
alias d="docker"
alias p="pnpm"

alias ncln="find . -type d \( -name "node_modules" -o -name ".next" -o -name ".turbo" \) -prune -exec rm -rf {} +"
alias aes="java -jar ~/misc/AesUtils.jar"

function stash {
	git stash push -u -m "$(gum input --placeholder 'message')"
}

function unstash {
	git stash pop "$(git stash list | sed -E 's/^stash@(\{[0-9]+\}): (WIP on|On) ([^:]+): ?([0-9a-f]{7,})? ?(.*)$/stash@\1  \3  \5/' | fzf | awk '{print $1}')"
}
alias stash="stash"
alias unstash="unstash"

alias lookup="sh ~/lookup.sh"

export EDITOR=code
export XDG_CONFIG_HOME="$HOME/.config"
