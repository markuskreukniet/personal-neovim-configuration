local SPACE_BAR = " "
local RULER_COLUMN = 120

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

-- This function maps Neovim's internal mode identifiers to human-readable mode names for the status line.
_G.mode_map = function()
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
-- Displays mode, file name, modified status, line:column (total number of lines), and [percentage] in the status line.
vim.opt.statusline = "%{v:lua.mode_map()} %f %m %= %l:%c (%L) [%p%%]"

-- Enable Neovim to use the system clipboard for seamless copy-paste operations across applications.
-- It also allows us to paste with the 'p' and 'P' commands without using the '"+p' or '"+P' commands.
vim.opt.clipboard = 'unnamedplus'

-- This function adds key mappings for '<leader>--', '<leader>//', and '<leader>#' in visual mode.
-- When we select one or multiple lines and press one of these mappings,
-- each line is prefixed with '-- ', '// ', or '# '.
-- If the key sequence is pressed too slowly,
-- Neovim may interpret the input as separate key presses instead of executing the mapping.
function add_line_comment_key_map(keybinding_suffix, replacement_text_part)
  if not replacement_text_part then
    replacement_text_part = keybinding_suffix
  end

  vim.api.nvim_set_keymap(
    "v",
    "<leader>" .. keybinding_suffix, ":<C-U>'<,'>s/^/" .. replacement_text_part .. " /g<CR>:noh<CR>",
     -- It prevents the mapping from triggering other mappings and suppresses command-line messages.
    { noremap = true, silent = true }
  )
end

add_line_comment_key_map("--")
add_line_comment_key_map("#")
add_line_comment_key_map("//", "\\/\\/")

require("extra_windows")({ RULER_COLUMN = RULER_COLUMN })

-- Bootstraps the 'lazy.nvim' plugin manager by cloning it if not installed and adding it to the runtime path,
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
  -- A plugin is an extendable fuzzy finder over lists, enabling file, buffer, and text search.
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" }
        },
        pickers = {
          find_files = { hidden = true } -- Show hidden files
        }
      })

      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
      vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
      vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
      vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
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

  require("lsp_plugins"),

  -- This plugin provides better syntax highlighting, code folding,
  -- and multi-language support than standard regex using Tree-sitter parsing.
  -- config = function() is currently not needed
  {
    "nvim-treesitter/nvim-treesitter",
    -- After installing the plugin, it updates Tree-sitter parsers by running ':TSUpdate.'
    build = ":TSUpdate",
    opts = {
      ensure_installed = {
        "css", -- CSS syntax highlighting and parsing
        "diff", -- Highlights differences in files for better readability
        "html", -- HTML syntax highlighting and parsing
        "javascript", -- JavaScript syntax highlighting and parsing
        "lua", -- Lua syntax highlighting and parsing
        "luadoc", -- Lua documentation syntax highlighting
        "markdown", -- Markdown syntax highlighting and parsing
        "markdown_inline", -- Inline Markdown highlighting and parsing
        "query", -- Tree-sitter queries for advanced highlighting and parsing
        "vim", -- Vimscript syntax highlighting and parsing
        "vimdoc" -- Vim documentation highlighting
    },
      -- For languages like Ruby that use Vim's regex for indenting,
      -- add them to 'additional_vim_regex_highlighting' and 'disable indent.'
      highlight = {
        enable = true
        -- additional_vim_regex_highlighting = { "ruby" }
      },
      indent = {
        enable = true
        -- disable = { "ruby" }
      }
    }
  },

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
