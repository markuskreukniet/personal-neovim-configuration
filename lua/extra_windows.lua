return function(config)
  local utils = require("utils/utils")
  local RULER_COLUMN = config.RULER_COLUMN
  local BUFFER_FLOATING_WINDOW_WIDTH = 34

  local function create_extra_window_buf()
    -- Create an unlisted (not shown in `:ls`) scratch buffer that is not associated with a file.
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = "hide" -- TODO: comment
    return buf
  end

  local windows_state = {
    left_margin_window = -1,
    left_margin_window_buffer = create_extra_window_buf(),
    buffers_floating_window = -1,
    buffers_floating_window_buffer = create_extra_window_buf()
  }
  local buffers_floating_window_buffer_line_length = 1

  local function get_non_extra_window_ids()
    return vim.tbl_filter(function(id)
      return id ~= windows_state.left_margin_window and id ~= windows_state.buffers_floating_window
    end, vim.api.nvim_tabpage_list_wins(0))
  end

  local function close_window(window_key)
    if windows_state[window_key] and vim.api.nvim_win_is_valid(windows_state[window_key]) then
      vim.api.nvim_win_close(windows_state[window_key], true) -- TODO: comment, forcefull close
      windows_state[window_key] = -1 -- TODO: is this needed?
    end
  end

  local function open_left_margin_window(available_columns)
    vim.cmd("topleft vsplit +buffer" .. windows_state.left_margin_window_buffer)
    vim.cmd("vertical resize " .. math.floor(available_columns / 2))

    windows_state.left_margin_window = vim.api.nvim_get_current_win()

    vim.wo[windows_state.left_margin_window].number = false
    vim.wo[windows_state.left_margin_window].relativenumber = false
    vim.wo[windows_state.left_margin_window].cursorline = false
    vim.wo[windows_state.left_margin_window].winfixwidth = true

    -- Sets the window's visual style by applying floating window highlights to its background and status line.
    vim.wo[windows_state.left_margin_window].winhighlight = "Normal:NormalFloat,StatusLine:NormalFloat"
    vim.wo[windows_state.left_margin_window].statusline = " " -- We need the space to get an empty status line.

    local function switch_focus_to_previous_window()
      vim.cmd("wincmd p")
    end

    switch_focus_to_previous_window()

    vim.api.nvim_create_autocmd("WinEnter", {
      callback = function()
        if vim.api.nvim_get_current_win() == windows_state.left_margin_window then
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
    utils.set_buffer_lines(windows_state.buffers_floating_window_buffer, 0, -1, lines)

    buffers_floating_window_buffer_line_length = #lines
  end

  local function open_buffers_floating_window()
    windows_state.buffers_floating_window = vim.api.nvim_open_win(
      windows_state.buffers_floating_window_buffer,
      false, -- Do not enter insert mode automatically when opening the window.
      {
        relative = "editor",
        width = BUFFER_FLOATING_WINDOW_WIDTH,
        height = buffers_floating_window_buffer_line_length,
        row = 1,
        col = vim.o.columns - BUFFER_FLOATING_WINDOW_WIDTH - 1,
        style = "minimal",
        border = "rounded",
        focusable = false
      }
    )
  end

  local function has_extra_width(available_columns, extra_width)
    return available_columns >= extra_width
  end

  local function has_double_extra_windows_width(available_columns)
    return has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH * 2)
  end

  local function has_extra_window_width(available_columns)
    return has_extra_width(available_columns, BUFFER_FLOATING_WINDOW_WIDTH)
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

  -- TODO: comment. When we create a new buf, without an existing file the first event that happens when the is visible with :ls is "BufEnter"
  vim.api.nvim_create_autocmd({"BufEnter"}, {
    callback = function()
      update_buffers_floating_window_buffer()

      if windows_state.buffers_floating_window ~= -1 then
        vim.api.nvim_win_set_height(windows_state.buffers_floating_window, buffers_floating_window_buffer_line_length)
      end
    end
  })

  vim.api.nvim_create_autocmd({"VimEnter"}, {
    callback = function()
      local available_columns = calculate_available_columns()

      if has_extra_window_width(available_columns) then
        open_buffers_floating_window()
      end

      if has_double_extra_windows_width(available_columns) then
        open_left_margin_window(available_columns)
      end
    end
  })

  -- TODO: should not close the windows every time, maybe resize/replace them
  vim.api.nvim_create_autocmd({"VimResized"}, {
    callback = function()
      close_window("buffers_floating_window")
      close_window("left_margin_window")

      local available_columns = calculate_available_columns()

      if has_extra_window_width(available_columns) then
        open_buffers_floating_window()
      end

      if has_double_extra_windows_width(available_columns) then
          open_left_margin_window(available_columns)
      end
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

  vim.api.nvim_create_autocmd({"BufUnload"}, {
    callback = function(args)
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("BufEnter", {})
      end)
    end
  })
end
