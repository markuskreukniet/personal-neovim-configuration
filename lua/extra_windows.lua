return function(config)
  local utils = require("utils/utils")
  local RULER_COLUMN = config.RULER_COLUMN
  local BUFFER_FLOATING_WINDOW_WIDTH = 34

   -- Position the floating window relative to the entire editor screen.
  local BUFFERS_FLOATING_WINDOW_RELATIVE_POSITIONING = "editor"
  local BUFFERS_FLOATING_WINDOW_ROW_POSITIONING = 1

  -- We could use `vim.api.nvim_win_hide(window_id)`,
  -- but that would require extra logic to differentiate between opening a new window and restoring a hidden one.

  local function create_extra_window_buf()
    -- Create an unlisted (not shown in `:ls`) scratch buffer that is not associated with a file.
    local buf = vim.api.nvim_create_buf(false, true)

     -- (Default) Keeps the buffer in memory when hidden, allowing it to be reopened without losing content.
    vim.bo[buf].bufhidden = "hide"
    return buf
  end

  local window_ids = {
    left_margin_window = -1,
    buffers_floating_window = -1
  }
  local left_margin_window_buffer = create_extra_window_buf()
  local buffers_floating_window_buffer = create_extra_window_buf()
  local buffers_floating_window_buffer_line_length = 0

  local function get_non_extra_window_ids()
    return vim.tbl_filter(function(id)
      return id ~= window_ids.left_margin_window and id ~= window_ids.buffers_floating_window
    end, vim.api.nvim_tabpage_list_wins(0))
  end

  local function close_window(window_key)
    vim.api.nvim_win_close(window_ids[window_key], true) -- Forcefully close the window.
    window_ids[window_key] = -1
  end

  local function resize_left_margin_window(available_columns)
    vim.api.nvim_win_set_width(window_ids.left_margin_window, math.floor(available_columns / 2))
  end

  local function open_left_margin_window(available_columns)
    vim.cmd("topleft vsplit +buffer" .. left_margin_window_buffer)

    window_ids.left_margin_window = vim.api.nvim_get_current_win()

    resize_left_margin_window(available_columns)

    vim.wo[window_ids.left_margin_window].number = false
    vim.wo[window_ids.left_margin_window].relativenumber = false
    vim.wo[window_ids.left_margin_window].cursorline = false
    vim.wo[window_ids.left_margin_window].winfixwidth = true

    -- Sets the window's visual style by applying floating window highlights to its background and status line.
    vim.wo[window_ids.left_margin_window].winhighlight = "Normal:NormalFloat,StatusLine:NormalFloat"
    vim.wo[window_ids.left_margin_window].statusline = " " -- We need the space to get an empty status line.

    local function switch_focus_to_previous_window()
      vim.cmd("wincmd p")
    end

    switch_focus_to_previous_window()

    vim.api.nvim_create_autocmd("WinEnter", {
      callback = function()
        if vim.api.nvim_get_current_win() == window_ids.left_margin_window then
          switch_focus_to_previous_window()
        end
      end
    })
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

    -- Replace all lines in `buf` with `lines`, starting at index 0 and extending to the last line (-1).
    utils.set_buffer_lines(buffers_floating_window_buffer, 0, -1, lines)

    buffers_floating_window_buffer_line_length = #lines

    -- The number of lines can be 0, such as when starting Neovim without a file (just `nvim`).
    -- In this case, it's better to show an empty floating window rather than no window at all.
    -- Since the minimum height of a floating window is 1, this ensures proper display.
    if buffers_floating_window_buffer_line_length == 0 then
      buffers_floating_window_buffer_line_length = 1
    end
  end

  local function calculate_buffers_floating_window_horizontal_position()
    return vim.o.columns - BUFFER_FLOATING_WINDOW_WIDTH - 1
  end

  -- A window’s position must be set at creation; it cannot be repositioned before it has been placed.
  local function open_buffers_floating_window()
    window_ids.buffers_floating_window = vim.api.nvim_open_win(
      buffers_floating_window_buffer,
      false, -- Do not enter insert mode automatically when opening the window.
      {
        relative = BUFFERS_FLOATING_WINDOW_RELATIVE_POSITIONING,
        row = BUFFERS_FLOATING_WINDOW_ROW_POSITIONING,
        col = calculate_buffers_floating_window_horizontal_position(),
        width = BUFFER_FLOATING_WINDOW_WIDTH,
        height = buffers_floating_window_buffer_line_length,
        style = "minimal",
        border = "rounded",
        focusable = false
      }
    )
  end

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

  local function calculate_available_column_widths()
    local function has_extra_width(available_columns, extra_width)
      return available_columns >= extra_width
    end

    local available_columns = calculate_available_columns()

    return available_columns,
      has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH),
      has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH * 2)
  end

  -- When starting Neovim without a file (just `nvim`), the following events occur in this order:
  -- 1. `UIEnter` - Triggered when the UI attaches (always happens, but mostly relevant for GUIs like Neovide).
  -- 2. `BufEnter` - Entering the default empty buffer.
  -- 3. `VimEnter` - Neovim has fully initialized.

  -- When executing `:vsplit`, the following events occur in this order:
  -- 1. `WinNew` - A new window is created for the split.
  -- 2. `BufEnter` - Triggered if the new window enters a different buffer.
  -- 3. `BufWinEnter` - The buffer becomes visible in the new window.
  -- 4. `WinEnter` - The cursor moves into the new split window.

  -- When closing a window in Neovim, the following events occur in this order:
  -- 1. `WinLeave` - Triggered when you leave the window (before closing).
  -- 2. `BufWinLeave` - Triggered when a buffer is removed from the window.
  -- 3. `WinClosed` - Triggered when the window is actually closed (gives window ID).
  -- 4. `BufUnload` - Triggered only if the buffer is completely unloaded (not used in any other window).

  -- When executing `:bd` (buffer delete), the following events occur in this order:
  -- 1. `BufLeave` - Triggered when leaving the buffer.
  -- 2. `BufWinLeave` - Triggered when the buffer is removed from the window.
  -- 3. `BufUnload` - Triggered when the buffer is unloaded from memory.
  -- 4. `BufDelete` - Triggered when the buffer is fully deleted.

  -- When creating a new buffer without an existing file,
  -- the first event that occurs when it becomes visible in `:ls` is `BufEnter`.
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function()
      update_buffers_floating_window_buffer()

      if window_ids.buffers_floating_window ~= -1 then
        vim.api.nvim_win_set_height(window_ids.buffers_floating_window, buffers_floating_window_buffer_line_length)
      end
    end
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      local available_columns, has_extra_width, has_double_extra_width = calculate_available_column_widths()

      if has_extra_width then
        open_buffers_floating_window()
      end

      if has_double_extra_width then
        open_left_margin_window(available_columns)
      end
    end
  })

  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      local available_columns, has_extra_width, has_double_extra_width = calculate_available_column_widths()

      if window_ids.buffers_floating_window == -1 and has_extra_width then
        open_buffers_floating_window()
      elseif window_ids.buffers_floating_window ~= -1 and has_extra_width then
        vim.api.nvim_win_set_config(window_ids.buffers_floating_window, {
          relative = BUFFERS_FLOATING_WINDOW_RELATIVE_POSITIONING,
          row = BUFFERS_FLOATING_WINDOW_ROW_POSITIONING,
          col = calculate_buffers_floating_window_horizontal_position()
        })
      elseif window_ids.buffers_floating_window ~= -1 and not has_extra_width then
        close_window("buffers_floating_window")
      end
      -- Do nothing when `window_ids.buffers_floating_window == -1 and not has_extra_width`

      if window_ids.left_margin_window == -1 and has_double_extra_width then
        open_left_margin_window(available_columns)
      elseif window_ids.left_margin_window ~= -1 and has_double_extra_width then
        resize_left_margin_window(available_columns)
      elseif window_ids.left_margin_window ~= -1 and not has_double_extra_width then
        close_window("left_margin_window")
      end
      -- Do nothing when `window_ids.left_margin_window == -1 and not has_double_extra_width`
    end
  })

  vim.api.nvim_create_autocmd({"WinNew", "WinClosed"}, {
    callback = function(args)
      local ids_count = #get_non_extra_window_ids()

      vim.schedule(function()
        if ids_count > 1 then
          -- Trigger "VimResized" to open and close the extra windows as needed.
          vim.api.nvim_exec_autocmds("VimResized", {})
        elseif ids_count == 1 and args.event == "WinClosed" then
          vim.cmd("q")
        end
      end)
    end
  })

  -- Without `vim.schedule`, it does not work.
  vim.api.nvim_create_autocmd("BufDelete", {
    callback = function(args)
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("BufEnter", {})
      end)
    end
  })
end
