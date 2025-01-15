local utils = require("utils/utils")
local SPACE_BAR = " "
local RULER_COLUMN = 120

-- The `noremap = true` prevents recursive mappings,
-- and `silent = true` suppresses the command display in the command line.
local KEY_MAP_OPTIONS_TABLE = { noremap = true, silent = true }

vim.g.mapleader = SPACE_BAR -- Set the global leader key to the space bar.
vim.g.maplocalleader = SPACE_BAR -- Set the local leader key to the space bar.

vim.opt.cursorline = true -- Highlights the line where the cursor is.
vim.opt.number = true -- Show absolute line numbers.
vim.opt.relativenumber = true -- Show relative line numbers.
vim.opt.breakindent = true -- Enable break indent for visually indented wrapped lines.
vim.opt.undofile = false -- Disable persistent undo, undo history will not be saved across sessions.
vim.opt.colorcolumn = tostring(RULER_COLUMN) -- Set a ruler at column number.

-- The sign column is a dedicated area next to the line numbers for displaying icons or symbols.
-- Sign column options:
-- "auto": Show only when signs are present.
-- "auto:NUMBER": Show if at least NUMBER signs are present.
-- "yes": Always show the sign column, even if no signs are present.
-- "no": Never show the sign column.
-- "number": Combine the sign column with the number column.
vim.opt.signcolumn = "yes"

vim.opt.list = true -- Enable visualization of whitespace characters.
vim.opt.listchars = { -- Configure symbols used to visualize whitespace and line-related characters.
  tab = "→ ", -- Tab characters. These two characters do not work with "tabstop=1".
  space = "·", -- Spaces
  trail = "•", -- Trailing spaces
  extends = "›", -- Overflowing lines on the right
  precedes = "‹", -- Overflowing lines on the left
  nbsp = "␣" -- Non-breaking spaces
}

-- Controls whether Neovim shows the current mode in the command-line area.
-- According to ":h 'showmode'", it is enabled by default.
-- Since we use a custom status line that displays the current mode, we can disable it here.
vim.opt.showmode = false

-- This function maps Neovim's internal mode identifiers to human-readable mode names for the status line.
local function mode_map()
  local modes = {
    n = "NORMAL",
    i = "INSERT",
    v = "VISUAL",
    V = "V-LINE",
    ["\22"] = "V-BLOCK",
    c = "COMMAND",
    R = "REPLACE",
    t = "TERMINAL"
  }
  return modes[vim.api.nvim_get_mode().mode] or "UNKNOWN"
end

-- Stores the function in Neovim's global scope (`vim.g`), avoiding `_G` pollution while keeping it accessible.
-- `vim.opt.statusline` can only call global functions.
vim.g.mode_map = mode_map

-- Displays mode, file name, modified status, line:column (total number of lines), and [percentage] in the status line.
vim.opt.statusline = "%{v:lua.vim.g.mode_map()} | %f %m %= %l:%c (%L) [%p%%]"

-- Enable Neovim to use the system clipboard for seamless copy-paste operations across applications.
-- It also allows us to paste with the `p` and `P` commands without using the `"+p` or `"+P` commands.
vim.opt.clipboard = "unnamedplus"

-- Maps `<leader>o` to insert a new line below in normal mode and return to normal mode immediately.
vim.keymap.set("n", "<leader>o", "o<Esc>", KEY_MAP_OPTIONS_TABLE)
-- Maps `<leader>O` to insert a new line above in normal mode and return to normal mode immediately.
vim.keymap.set("n", "<leader>O", "O<Esc>", KEY_MAP_OPTIONS_TABLE)

local rename_current_file = "Rename current file"

vim.keymap.set("n", "<leader>rf", function()
  local current_name = vim.fn.expand("%") -- Get the current buffer's filename (relative to CWD).
  -- Get a new filename from user input, using the current name as the default and trim spaces.
  local new_name = vim.trim(vim.fn.input(rename_current_file .. ": ", current_name))

  if not utils.is_empty(new_name) and new_name ~= current_name then
    local success, err = os.rename(current_name, new_name)
    if success then
      vim.cmd("e " .. new_name)
      vim.cmd("bd " .. current_name)
    else
      print("Error: " .. err)
    end
  end
end, { desc = rename_current_file })

-- When yanking (copying), it highlights the yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end
})

local function find_project_root()
  -- Returns the Git project root if inside a Git repository; otherwise, defaults to Neovim's current working directory.
  return vim.fn.systemlist("git rev-parse --show-toplevel")[1] or vim.fn.getcwd()
end

require("toggle_comment")({ KEY_MAP_OPTIONS_TABLE = KEY_MAP_OPTIONS_TABLE })
require("detect_indentation")()
require("extra_windows")({ RULER_COLUMN = RULER_COLUMN })

-- Bootstraps the `lazy.nvim` plugin manager by cloning it if not installed and adding it to the runtime path,
-- ensuring efficient plugin management and faster startup.
local lazy_path = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazy_path) then
  local out = vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazy_path
  }
  if tonumber(vim.v.shell_error) ~= 0 then
    error("Error cloning lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazy_path)

require("lazy").setup({
  -- A plugin that is an extendable fuzzy finder over lists, enabling file, buffer, and text search.
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      -- By default, Telescope searches from the directory where Neovim was opened,
      -- including all its subdirectories.
      -- Setting `project_root` as `cwd` ensures searches start from the project's root directory instead.
      local project_root = find_project_root()

      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" }
        },
        pickers = {
          find_files = {
            hidden = true, -- Show hidden files
            cwd = project_root
          },
          live_grep = {
            cwd = project_root
          }
        }
      })

      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
      vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
      vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
      vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
    end
  },

  -- A plugin that visualizes indentation levels with customizable guides, enhancing code readability.
  {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      require("ibl").setup({
        scope = {
          enabled = true, -- Enable Tree-sitter-based scope highlighting.
          show_start = true -- Show the start of the scope.
        }
      })
    end
  },

  -- A plugin that deeply integrates Git into buffers.
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end
  },

  require("language_plugins"),

  -- Set up a color scheme plugin.
  {
    "catppuccin/nvim",
    priority = 1000, -- Ensure this plugin loads before other startup plugins.
    config = function()
      require("catppuccin").setup({ flavour = "mocha" })
      vim.cmd.colorscheme "catppuccin"
    end
  }
})
