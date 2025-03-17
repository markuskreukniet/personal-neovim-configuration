# personal-neovim-configuration

## Installation

1. On Windows, go to: C:\Users\[user name]\AppData\Local
1. git clone https://github.com/markuskreukniet/personal-neovim-configuration.git nvim
1. (optional) Live grep of Telescope requires `ripgrep` (rg). We can Install it, for example, with:

    - Windows: `choco install ripgrep`
    - Debian: `sudo apt install ripgrep

## Good To Know

- If a key mapping is pressed too slowly, Neovim may interpret the input as separate key presses instead of executing the mapping.

## TODO:

- fuzzy find should not find all project files, such as .gitignore files
- something like a minimap?
- show :reg content in floating window?
