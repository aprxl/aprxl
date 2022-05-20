# Imports
Import-Module posh-git
Import-Module Terminal-Icons

# Auto-complete
Set-PSReadLineOption -PredictionSource History

# Aliases
Set-Alias g git
Set-Alias vim nvim

# Functions
function emacsc {
  emacsclient -c -a 'emacs'
}

# Run
oh-my-posh init pwsh --config ~/scoop/apps/oh-my-posh/current/themes/bubbles.omp.json | Invoke-Expression
clear
