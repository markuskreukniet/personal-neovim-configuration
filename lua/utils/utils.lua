local M = {}

function M.is_empty(s)
  return s == ""
end

function M.starts_with(s, sub_s)
  return s:sub(1, #sub_s) == sub_s
end

function M.replace_first(s, old, new)
  return s:gsub(old, new, 1)
end

function M.set_buffer_lines(buffer, start_line, end_line, lines)
  -- Replaces lines in the given buffer from `start_line` to `end_line - 1` (exclusive)
  -- with the provided list of lines.
  -- Both `start_line` and `end_line` use 0-based indexing.
  -- `vim.api.nvim_buf_set_lines` modifies multiple lines in a single operation.
  -- `silent!` suppresses messages that could slow down execution.
  -- `noautocmd` prevents autocommands (e.g., syntax highlighting updates) from triggering during bulk changes.
  vim.cmd("silent! noautocmd")

  -- `false` allows the buffer to grow if `end_line` exceeds its current size.
  vim.api.nvim_buf_set_lines(buffer, start_line, end_line, false, lines)

  -- `doautocmd` restores normal autocommand behavior after the update.
  vim.cmd("doautocmd")
end

return M
