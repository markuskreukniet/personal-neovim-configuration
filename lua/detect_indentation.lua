return function()
  local previous_indentation_expand_tab = false
  local previous_indentation_space_indent_size = -1

  local function count_indentation_types()
    local space_indents = {}
    local tab_count = 0

    -- Retrieve all lines starting from 60% into the current buffer and iterate over them.
    -- `false` disables strict indexing, preventing errors if the requested range exceeds the buffer size.
    for _, line in ipairs(vim.api.nvim_buf_get_lines(0, math.floor(vim.api.nvim_buf_line_count(0) * 0.6), -1, false)) do
      local leading_white_space = line:match("^(%s+)")
      if leading_white_space then
        if leading_white_space:match("^\t") then
          tab_count = tab_count + 1
        else
          local space_count = #leading_white_space
          space_indents[space_count] = (space_indents[space_count] or 0) + 1
        end
      end
    end

    return tab_count, space_indents
  end

  local function has_key_1_the_highest_count(space_indents)
    local highest_count = -1

    for _, value in pairs(space_indents) do
      if value > highest_count then
        highest_count = value
      end
    end

    if space_indents[1] == highest_count then
      return true
    else
      return false
    end
  end

  local function find_lowest_key(space_indents)
    local lowest_key = nil

    for key in pairs(space_indents) do
      if lowest_key == nil or key < lowest_key then
        lowest_key = key
      end
    end

    return lowest_key
  end

  local function sum_space_indent_counts(space_indents)
    local total_space_indents = 0

    for _, value in pairs(space_indents) do
      total_space_indents = total_space_indents + value
    end

    return total_space_indents
  end

  local function calculate_space_indent_size(space_indents)
    local highest_total_space_indents = -1
    local highest_space_indents = nil

    while next(space_indents) do
      local new_space_indents = {}
      local lowest_key = find_lowest_key(space_indents)
      for key, value in pairs(space_indents) do
        if key % lowest_key == 0 then
          new_space_indents[key] = value
          space_indents[key] = nil
        end
      end
      local total_space_indents = sum_space_indent_counts(new_space_indents)
      if total_space_indents > highest_total_space_indents then
        highest_total_space_indents = total_space_indents
        highest_space_indents = new_space_indents
      end
    end

    return find_lowest_key(highest_space_indents)
  end

  local function set_indentation(expand_tab, space_indent_size)
    -- vim.schedule() delays execution to ensure Neovim does not override the setting.
    vim.schedule(function()
      vim.bo.expandtab = expand_tab -- Converts tab characters into spaces when typing
      vim.bo.shiftwidth = space_indent_size -- Sets the number of spaces for indentation levels
      vim.bo.tabstop = space_indent_size -- Sets the number of spaces a tab character represents
    end)
  end

  local function set_indentation_style(tab_count, total_space_indents, space_indent_size)
    local expand_tab = true

    if tab_count > total_space_indents then
      expand_tab = false
    end

    set_indentation(expand_tab, space_indent_size)

    previous_indentation_expand_tab = expand_tab
    previous_indentation_space_indent_size = space_indent_size
  end

  local function detect_indentation()
    local tab_count, space_indents = count_indentation_types()
    local total_space_indents = sum_space_indent_counts(space_indents)

    if total_space_indents == 0 then
      -- When the indentation consists only of tabs, detecting a space indent size is impossible.
      if tab_count > 0 then
        set_indentation(false, 4)
      elseif previous_indentation_space_indent_size > -1 then
        set_indentation(previous_indentation_expand_tab, previous_indentation_space_indent_size)
      end
      return
    end

    if space_indents[1] ~= nil then
      if has_key_1_the_highest_count(space_indents) then
        set_indentation_style(tab_count, total_space_indents, 1)
        return
      end
      space_indents[1] = nil
    end

    if next(space_indents) then
      set_indentation_style(tab_count, total_space_indents, calculate_space_indent_size(space_indents))
    end
  end

  vim.api.nvim_create_autocmd({"BufReadPost", "BufNewFile"}, {
    callback = detect_indentation
  })
end
