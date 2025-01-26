local SPACE_BAR = " "
local RULER_COLUMN = 120
local BUFFER_FLOATING_WINDOW_WIDTH = 34

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
-- Displays mode, file name, modified status, line:column, and percentage in the status line.
vim.opt.statusline = "%{v:lua.mode_map()} %f %m %= %l:%c [%p%%]"

-- Enable Neovim to use the system clipboard for seamless copy-paste operations across applications.
-- It also allows us to paste with the 'p' and 'P' commands without using the '"+p' or '"+P' commands.
vim.opt.clipboard = 'unnamedplus'

local state = {
  left_margin_window = nil,
  left_margin_window_buffer = nil,
  buffers_floating_window = nil,
  buffers_floating_window_buffer = nil
}

-- TODO: add: git diff, multiline comment, auto indent detection

local function calculate_available_columns()
  return vim.o.columns - RULER_COLUMN
end

local function has_extra_width(extra_width)
  return calculate_available_columns() >= extra_width
end

local function has_double_extra_windows_width()
  return has_extra_width(BUFFER_FLOATING_WINDOW_WIDTH * 2)
end

local function has_extra_window_width()
  return has_extra_width(BUFFER_FLOATING_WINDOW_WIDTH)
end

local function close_window(window_key, buffer_key)
  if state[window_key] and vim.api.nvim_win_is_valid(state[window_key]) then
    vim.api.nvim_win_close(state[window_key], true)
    state[buffer_key] = nil
    state[window_key] = nil
  end
end

local function close_left_margin_window()
  close_window("left_margin_window", "left_margin_window_buffer")
end

local function close_buffers_floating_window()
  close_window("buffers_floating_window", "buffers_floating_window_buffer")
end

local function open_left_margin_window()
  vim.cmd("topleft vnew")
  vim.cmd("vertical resize " .. math.max(0, math.floor(calculate_available_columns() / 2)))

  state.left_margin_window = vim.api.nvim_get_current_win()
  state.left_margin_window_buffer = vim.api.nvim_get_current_buf()

  vim.bo[state.left_margin_window_buffer].bufhidden = "wipe" -- TODO: duplicate
  vim.bo[state.left_margin_window_buffer].buftype = "nofile" -- TODO: is it useful?
  vim.wo[state.left_margin_window].number = false
  vim.wo[state.left_margin_window].relativenumber = false
  vim.wo[state.left_margin_window].cursorline = false
  vim.wo[state.left_margin_window].winfixwidth = true

  -- Sets the window's visual style by applying floating window highlights to its background and status line.
  vim.wo[state.left_margin_window].winhighlight = "Normal:NormalFloat,StatusLine:NormalFloat"
  vim.wo[state.left_margin_window].statusline = " " -- We need the space to get an empty status line.

  local function switch_focus_to_previous_window()
    vim.cmd("wincmd p")
  end

  switch_focus_to_previous_window()

  vim.api.nvim_create_autocmd("WinEnter", {
    callback = function()
      if vim.api.nvim_get_current_win() == state.left_margin_window then
        switch_focus_to_previous_window()
      end
    end
  })
end

local function open_buffers_floating_window()
  local lines = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.fn.bufname(buf) ~= "" then
      table.insert(
        lines,
        string.format(
          "%d: %s",
          buf,
          vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
        )
      )
    end
  end

  state.buffers_floating_window_buffer = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(state.buffers_floating_window_buffer, 0, -1, false, lines)
  vim.bo[state.buffers_floating_window_buffer].bufhidden = "wipe"

  state.buffers_floating_window = vim.api.nvim_open_win(
    state.buffers_floating_window_buffer,
    false,
    {
      relative = "editor",
      width = BUFFER_FLOATING_WINDOW_WIDTH,
      height = #lines,
      row = 1,
      col = vim.o.columns - BUFFER_FLOATING_WINDOW_WIDTH - 1,
      style = "minimal",
      border = "rounded",
      focusable = false
    }
  )
end

vim.api.nvim_create_autocmd({"VimEnter", "VimResized"}, {
  callback = function()
    close_left_margin_window()
    close_buffers_floating_window()

    if has_extra_window_width() then
      open_buffers_floating_window()

      if has_double_extra_windows_width() then
        open_left_margin_window()
      end
    end
  end
})

vim.api.nvim_create_autocmd({"BufEnter", "BufDelete"}, {
  callback = function()
    close_buffers_floating_window()

    if has_extra_window_width() then
      open_buffers_floating_window()
    end
  end
})

vim.api.nvim_create_autocmd("WinClosed", {
  callback = function()
    local number_of_windows = #vim.api.nvim_tabpage_list_wins(0)

    if (has_double_extra_windows_width() and number_of_windows == 3) or
      (has_extra_window_width() and number_of_windows == 2) then
        vim.schedule(function()
          vim.cmd("q")
        end)
    end
  end
})

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

  require("lsp"),

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
