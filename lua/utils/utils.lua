local M = {}

function M.isEmpty(s)
  return s == ""
end

function M.startsWith(s, sub_s)
  return s:sub(1, #sub_s) == sub_s
end

function M.replaceFirst(s, old, new)
  return s:gsub(old, new, 1)
end

return M
