# === April's PowerShell profile ===

# --- oh-my-posh prompt (pure theme, loaded from scoop's bundled themes) ---
oh-my-posh init pwsh --config "$env:USERPROFILE\scoop\apps\oh-my-posh\current\themes\pure.omp.json" | Invoke-Expression

# --- ls -> eza ---
# Remove PS 5.1's built-in `ls` alias -> Get-ChildItem (aliases outrank functions).
Remove-Item alias:ls -Force -ErrorAction SilentlyContinue
function ls { eza --icons=auto @args }
function ll { eza --long --all --git --icons=auto @args }   # detailed listing
function la { eza --all --icons=auto @args }                # everything incl. dotfiles
function lt { eza --tree --level=2 --icons=auto @args }     # quick tree view

# I don't like writing "cd ~"
function home { cd ~ }

# === Interactive niceties (console host only, skip inside IDEs/heredocs) ===
if ($host.Name -eq 'ConsoleHost') {

    # --- Modules ---
    Import-Module PSReadLine
    Import-Module PSFzf
    Import-Module Terminal-Icons

    # --- PSReadLine: fish-style history autocomplete + syntax highlighting ---
    # NOTE: works in real terminals (Windows Terminal); silently skipped in
    # redirected hosts since Virtual Terminal isn't available there.
    try {
        Set-PSReadLineOption -PredictionSource History     # grey ghost suggestion inline (fish-style)
        Set-PSReadLineOption -PredictionViewStyle InlineView # one inline ghost; full list stays on Ctrl+R
        Set-PSReadLineOption -HistoryNoDuplicates
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd

        # ->            accept the WHOLE grey suggestion when cursor is at end of line
        # Alt+->        accept it ONE WORD at a time (exactly like fish)
        Set-PSReadLineKeyHandler -Key "Alt+RightArrow" -Function ForwardWord
        # ↑ / ↓         search history by what you've already typed (fish-like)
        Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
        Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        # Tab           menu-complete: cycles suggestions in a menu instead of beeping
        Set-PSReadLineKeyHandler -Key Tab      -Function MenuComplete
        Set-PSReadLineOption -EditMode Windows                   # keep familiar Ctrl+V etc.
    } catch { }

    # --- fzf: fuzzy finder ---
    # Ctrl+R = fuzzy-search full history, Ctrl+T = fuzzy-insert file paths
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'

    # --- zoxide: smarter cd that learns your habits (`z proj`) ---
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
