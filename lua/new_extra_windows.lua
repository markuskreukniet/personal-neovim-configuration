return function(config)
  local utils = require("utils/utils")
  local RULER_COLUMN = config.RULER_COLUMN
  local BUFFER_FLOATING_WINDOW_WIDTH = 34

  -- TODO: check code on comments and useless code
  --vim.api.nvim_win_hide(window)

  local function create_extra_window_buf()
    -- Create an unlisted (not shown in `:ls`) scratch buffer that is not associated with a file.
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "hide" -- TODO: comment
    return buf
  end

  local left_margin_window = -1
  local buffers_floating_window = -1
  local left_margin_window_buffer = create_extra_window_buf()
  local buffers_floating_window_buffer = create_extra_window_buf()
  local buffers_floating_window_buffer_line_length = 1 -- TODO: should it be a part of this state part? -- Start as 1, since there is always at least one buffer

  local function get_non_extra_window_ids()
    return vim.tbl_filter(function(id)
      return id ~= left_margin_window and id ~= buffers_floating_window
    end, vim.api.nvim_tabpage_list_wins(0))
  end

  -- In this function,
  -- we must call `get_non_extra_window_ids()` even after `close_window()` calls because window closing is asynchronous,
  -- and the windows might not be fully closed yet.
  local function calculate_available_columns()
    local count = 0
    for _, id in ipairs(get_non_extra_window_ids()) do
      if vim.api.nvim_win_get_width(id) < vim.o.columns then
          count = count + 1
      end
    end
    if count == 0 then
      count = 1
    end

    return vim.o.columns - (RULER_COLUMN * count)
  end

  local function has_extra_width(available_columns, extra_width)
    return available_columns >= extra_width
  end

  local function open_left_margin_window(available_columns)
    vim.cmd("topleft vsplit +buffer" .. left_margin_window_buffer)
    vim.cmd("vertical resize " .. math.floor(available_columns / 2))

    left_margin_window = vim.api.nvim_get_current_win()
    vim.wo[left_margin_window].number = false
    vim.wo[left_margin_window].relativenumber = false
    vim.wo[left_margin_window].cursorline = false
    vim.wo[left_margin_window].winfixwidth = true

    -- Sets the window's visual style by applying floating window highlights to its background and status line.
    vim.wo[left_margin_window].winhighlight = "Normal:NormalFloat,StatusLine:NormalFloat"
    vim.wo[left_margin_window].statusline = " " -- We need the space to get an empty status line.

    local function switch_focus_to_previous_window()
      vim.cmd("wincmd p")
    end

    switch_focus_to_previous_window()

    -- TODO: is needed?
    vim.api.nvim_create_autocmd("WinEnter", {
      callback = function()
        if vim.api.nvim_get_current_win() == left_margin_window then
          switch_focus_to_previous_window()
        end
      end
    })
  end

  local function calculate_buffers_floating_window_horizontal_position()
    return vim.o.columns - BUFFER_FLOATING_WINDOW_WIDTH - 1
  end

  local function open_buffers_floating_window()
    buffers_floating_window = vim.api.nvim_open_win(
      buffers_floating_window_buffer,
      false, -- Do not enter insert mode automatically when opening the window.
      {
        relative = "editor",
        width = BUFFER_FLOATING_WINDOW_WIDTH,
        height = buffers_floating_window_buffer_line_length,
        row = 1,
        col = calculate_buffers_floating_window_horizontal_position(),
        style = "minimal",
        border = "rounded",
        focusable = false
      }
    )
  end

  local function update_buffers_floating_window_buffer()
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

    utils.set_buffer_lines(buffers_floating_window_buffer, 0, -1, lines)

    buffers_floating_window_buffer_line_length = #lines
  end

  -- TODO: comment
  -- If you start Neovim without a file (nvim), the main events that are triggered are:
  -- These three events happen:
  -- UIEnter: When Neovim's UI is initialized (for GUIs like Neovide).
  -- BufEnter: When entering the default empty buffer ([No Name]).
  -- VimEnter: When Neovim has fully initialized.

  -- When you execute :vsplit, the following events occur in this order:
  -- WinNew: A new window is created (the split).
  -- BufEnter: The new window enters the current buffer.
  -- BufWinEnter: The buffer becomes visible in the new window.
  -- WinEnter: The cursor moves into the new split window.

  vim.api.nvim_create_autocmd({"BufEnter", "VimResized"}, {
    callback = function(arguments)
      local available_columns = calculate_available_columns()
      local has_width = has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH)
      local has_double_width = has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH * 2)

      if buffers_floating_window == -1 and has_width then
        if arguments.event == "BufEnter" then
          update_buffers_floating_window_buffer()
        end
        open_buffers_floating_window()
      elseif buffers_floating_window ~= -1 and has_width then
        if arguments.event == "BufEnter" then
          update_buffers_floating_window_buffer()
          vim.api.nvim_win_set_height(buffers_floating_window, buffers_floating_window_buffer_line_length)
        end
        if arguments.event == "VimResized" then
          vim.api.nvim_win_set_config(buffers_floating_window, {
            relative = "editor", -- TODO: duplicate code and comment is missing
            row = 1, -- TODO: duplicate code
            col = calculate_buffers_floating_window_horizontal_position()
          })
        end
      elseif buffers_floating_window ~= -1 and not has_width then
        vim.api.nvim_win_close(buffers_floating_window, false)
      end
      -- Do nothing when `buffers_floating_window == -1 and not has_width`

      if left_margin_window == -1 and has_double_width then
        open_left_margin_window(available_columns)
      elseif left_margin_window ~= -1 and has_double_width then
        vim.api.nvim_win_set_width(left_margin_window, math.floor(available_columns / 2)) -- TODO: duplicate code
      elseif left_margin_window ~= -1 and not has_double_width then
        vim.api.nvim_win_close(left_margin_window, false)
      end
      -- Do nothing when `left_margin_window == -1 and not has_double_width`

      -- vim.schedule(function()
      --   local ids = vim.api.nvim_tabpage_list_wins(0)
      --   print('nr of ids: ' .. #ids)
      -- end)
      -- vim.schedule(function()
      --   local buffers = vim.api.nvim_list_bufs()
      --   print('nr of buffers: ' .. #buffers)
      -- end)
    end
  })

  --

  vim.api.nvim_create_autocmd({"BufUnload"}, {
    callback = function()
      vim.schedule(function()
        --update_buffers_floating_window()
      end)
    end
  })
--
  -- local function close_window(window_key)
  --   if windows_state[window_key] and vim.api.nvim_win_is_valid(windows_state[window_key]) then
  --     vim.api.nvim_win_close(windows_state[window_key], true)
  --     windows_state[window_key] = nil
  --   end
  -- end

      -- The "VimEnter" event should close the `buffers_floating_window`.
      -- That could be because the "BufEnter" event happens before that.
--       close_window("buffers_floating_window")

  vim.api.nvim_create_autocmd({"WinClosed"}, {
    callback = function(args)
      local ids_count = #get_non_extra_window_ids()

      vim.schedule(function()
        if ids_count > 1 then
          -- Trigger "VimResized" to open and close the extra windows as needed.
          vim.api.nvim_exec_autocmds("VimResized", {})
        elseif ids_count == 1 then
          vim.cmd("q")
        end
      end)
    end
  })
end
