return function()
-- local function is_double_forward_slash_comment(filetype)
--   -- double forward slash comments filetypes
--   if filetype == "cpp" or
--     filetype == "go" or
--     filetype == "java" or
--     filetype == "javascript" or
--     filetype == "typescript" or
--     filetype == "kotlin" then
--     return "//", "\\/\\/"
--   end

--   return false
-- end

-- local function is_double_dash_comment(filetype)
--   if filetype == "lua" then
--     return true
--   end

--   return false
-- end

-- local function is_hash_comment(filetype)
--   if filetype == "python" then
--     return true
--   end

--   return false
-- end

--   local filetype = nil
  -- TODO: should also be possible to uncomment
  -- This function adds key mappings for '<leader>--', '<leader>//', and '<leader>#' in visual mode.
  -- When we select one or multiple lines and press one of these mappings,
  -- each line is prefixed with '-- ', '// ', or '# '.
  -- If the key sequence is pressed too slowly,
  -- Neovim may interpret the input as separate key presses instead of executing the mapping.
  local function add_line_comment_key_map(keybinding_suffix, replacement_text_part)
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

--   vim.api.nvim_create_autocmd("BufReadPost", {
--     callback = function()
--       filetype = vim.bo.filetype
--       if filetype == "lua" then
--         print("Lua file detected.")
--       elseif filetype == "python" then
--         print("Python file detected.")
--       end
--     end
--   })
end
