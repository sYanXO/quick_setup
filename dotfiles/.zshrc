export EDITOR=nvim
export VISUAL=nvim
export GOPATH="$HOME/go"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$GOPATH/bin:$PATH"

if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd)"
fi

alias ll='ls -lah'
alias gs='git status -sb'
