# Imports
Import-Module posh-git
Import-Module oh-my-posh
Import-Module Terminal-Icons
Set-PoshPrompt bubbles

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
clear
