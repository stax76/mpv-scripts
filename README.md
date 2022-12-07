
Collection of mpv scripts for Windows and Linux, MacOS support is limited.

Screenshots are at the bottom of this page.  

Search Menu is documented here, all other scripts are
documented directly in the script via a code comment
at the beginning of the script.

# Search Menu

## About

Search Menu is a searchable menu based on Rofi or terminal based on fzf.

## Installation

Extract the search menu folder at `~~/scripts/search_menu`, don't rename it.

## Configuration

### mpv.conf

Windows: `input-ipc-server = \\.\pipe\mpvsocket`

Linux: `input-ipc-server = /tmp/mpvsocket`

### Conf file at `~~/scripts-opts/search_menu.conf`:

```
#mode=gnome-terminal+sh    # Requires Linux and Gnome Terminal
#mode=alacritty+sh         # Requires Linux and Alacritty
#mode=rofi                 # Requires Linux and Rofi
#mode=alacritty+ns         # Requires Windows, Alacritty and Nushell
#mode=windows-terminal+ps  # Requires Windows and Windows Terminal
#mode=windows-terminal+ns  # Requires Windows, Windows Terminal and Nushell
```

### input.conf:

```
F1 script-message-to search_menu show-search-menu binding        # Search Binding
F2 script-message-to search_menu show-search-menu binding-full   # Search Binding Full
F3 script-message-to search_menu show-search-menu command        # Search Command
F4 script-message-to search_menu show-search-menu property       # Search Property
F8 script-message-to search_menu show-search-menu playlist       # Search Playlist
Alt+a script-message-to search_menu show-search-menu audio-track # Search Audio Track
Alt+s script-message-to search_menu show-search-menu sub-track   # Search Subtitle Track
```

On Windows Alacritty and Nushell have the advantage of a faster startup.

On Linux Alacritty has the advantage of not having any UI apart from the terminal.

The Rofi configuration has like mpv a learning curve.

## Dependencies

Which dependencies are required depend
on which mode and feature is used.

- https://www.python.org
- https://github.com/davatorium/rofi - Required for rofi mode, depends on Linux and X11.
- https://github.com/junegunn/fzf - Required for modes other than rofi (terminal modes).
- https://mediaarea.net/en/MediaInfo - Required to search audio or subtitle tacks.
- https://alacritty.org - Alternative for Gnome Terminal and Windows Terminal.
- https://www.nushell.sh - Starts 200 ms faster than PowerShell.

## Usage

Invoke a menu via shortcut key, type a search keyword, use up/down key to select,
enter key to confirm, escape key to close.

## Similar Projects

- https://github.com/Seme4eg/mpv-scripts/tree/master#m-x
- https://github.com/CogentRedTester/mpv-search-page
- https://codeberg.org/NRK/mpv-toolbox/src/branch/master/mdmenu
- https://github.com/mpvnet-player/mpv.net#command-palette

## Context Menu Projects

- https://gitlab.com/carmanaught/mpvcontextmenu
- https://github.com/nezumisama/mpvmenu
- https://gist.github.com/avih/bee746200b5712220b8bd2f230e535de

# Screenshots

misc.lua has various features, among them
is printing media info on the screen.

![media-info](screenshots/media-info.jpg)

## Rofi based search menu

![Rofi based search menu](screenshots/rofi.png)

## Terminal based search menu

![Terminal based search menu](screenshots/search_menu-binding.png)
