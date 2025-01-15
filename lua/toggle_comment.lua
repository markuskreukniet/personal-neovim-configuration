return function(config)
  local KEY_MAP_OPTIONS_TABLE = config.KEY_MAP_OPTIONS_TABLE
  local utils = require("utils/utils")
  local replacement_text = nil

  local function set_replacement_text(filetype)
    local double_forward_slash_replacement_text_part = "//"
    local replacement_text_part_map = {
      lua = "--",
      python = "#",
      c = double_forward_slash_replacement_text_part,
      cpp = double_forward_slash_replacement_text_part,
      go = double_forward_slash_replacement_text_part,
      java = double_forward_slash_replacement_text_part,
      javascript = double_forward_slash_replacement_text_part,
      typescript = double_forward_slash_replacement_text_part,
      kotlin = double_forward_slash_replacement_text_part
    }

    if replacement_text_part_map[filetype] then
      replacement_text = replacement_text_part_map[filetype] .. " "
    else
      replacement_text = nil
    end
  end

  local function get_whole_visual_lines(start_pos, end_pos)
    local start_line = start_pos[2]
    local end_line = end_pos[2]

    if start_line < 1 or end_line < 1 then
      return nil, nil, nil
    end

    local lines = vim.fn.getline(start_line, end_line)
    local index_first_line = 1
    local index_last_line = #lines

    if start_pos[3] > 1 then -- start_column > 1
      start_line = start_line + 1
      index_first_line = index_first_line + 1
    end

    if end_pos[3] < #lines[index_last_line] then -- end_column < end_line_length
      end_line = end_line - 1
      index_last_line = index_last_line - 1
    end

    if end_line < start_line then
      return nil, nil, nil
    end

    --- The `table.move` copies a range of lines from `lines` into a new table starting at index 1.
    return table.move(lines, index_first_line, index_last_line, 1, {}), start_line, end_line
  end

  local function get_positions()
    -- We can get the cursor position with `local cursor_pos = vim.fn.getpos(".")`,
    -- which is not needed in the current implementation.

    -- Sends the `<Esc>` key (`"\27"` is its ASCII code) to Neovim and executes it immediately without queuing.
    -- Sends the raw key sequence, bypassing mappings.
    vim.api.nvim_feedkeys("\27", "x", false)
    return vim.fn.getpos("'<"), vim.fn.getpos("'>")
  end

  local function toggle_comments()
    local start_pos, end_pos = get_positions()
    local lines, start_line, end_line = get_whole_visual_lines(start_pos, end_pos)

    if lines == nil or start_line == nil or end_line == nil then
      return
    end

    local function table_insert_indexed_line(indexed_lines, index, line)
      table.insert(indexed_lines, { index = index, line = line })
    end

    local commented_indexed_lines = {}
    local non_commented_indexed_lines = {}

    for i, line in ipairs(lines) do
      if not utils.is_empty(line) then
        if utils.starts_with(line, replacement_text) then
          table_insert_indexed_line(commented_indexed_lines, i, line)
        else
          table_insert_indexed_line(non_commented_indexed_lines, i, line)
        end
      end
    end

    if #non_commented_indexed_lines >= #commented_indexed_lines then
      for _, indexed_line in ipairs(non_commented_indexed_lines) do
        lines[indexed_line.index] = replacement_text .. indexed_line.line
      end
    else
      for _, indexed_line in ipairs(commented_indexed_lines) do
        lines[indexed_line.index] = utils.replace_first(indexed_line.line, replacement_text, "")
      end
    end

    utils.set_buffer_lines(0, start_line - 1, end_line, lines)
  end

  -- "FileType" triggers every time the file type of a buffer is set or changed.
  -- "BufReadPost" happens before filetype detection, so we should not use it if filetype-dependent logic is needed.
  vim.api.nvim_create_autocmd("FileType", {
    callback = function()
      set_replacement_text(vim.bo.filetype)

      if replacement_text then
        vim.keymap.set("v", "<leader>c", toggle_comments, KEY_MAP_OPTIONS_TABLE)
      end
    end
  })
end
