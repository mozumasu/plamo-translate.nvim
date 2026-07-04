local M = {}

-- Mappings applied by the last setup() call; delete()/status() operate on these
local applied = {}

---Setup default keymappings for the plugin
---@param opts? table Optional configuration for keymaps
function M.setup(opts)
  opts = opts or {}
  local prefix = opts.prefix or "<leader>t"

  -- Default keymappings
  local mappings = {
    {
      mode = "n",
      lhs = prefix .. "t",
      rhs = "<cmd>PlamoTranslate<cr>",
      desc = "Translate text (interactive)",
    },
    {
      mode = "v",
      lhs = prefix .. "t",
      rhs = ":'<,'>PlamoTranslate<cr>",
      desc = "Translate selected text",
    },
    {
      mode = "v",
      lhs = prefix .. "r",
      rhs = ":'<,'>PlamoTranslateReplace<cr>",
      desc = "Replace with translation",
    },
    {
      mode = "n",
      lhs = prefix .. "l",
      rhs = "<cmd>PlamoTranslateLine<cr>",
      desc = "Translate current line",
    },
    {
      mode = "n",
      lhs = prefix .. "w",
      rhs = "<cmd>PlamoTranslateWord<cr>",
      desc = "Translate word under cursor",
    },
    {
      mode = "n",
      lhs = prefix .. "c",
      rhs = "<cmd>PlamoTranslateClose<cr>",
      desc = "Close translation window",
    },
    {
      mode = "n",
      lhs = prefix .. "b",
      rhs = "<cmd>PlamoTranslateBuffer<cr>",
      desc = "Translate entire buffer (split)",
    },
    {
      mode = "n",
      lhs = prefix .. "B",
      rhs = "<cmd>PlamoTranslateBufferReplace<cr>",
      desc = "Replace buffer with translation",
    },
    {
      mode = "n",
      lhs = prefix .. "v",
      rhs = "<cmd>PlamoTranslateCommentsToggle<cr>",
      desc = "Toggle comment translations (virtual text)",
    },
  }

  -- Apply mappings
  for _, mapping in ipairs(mappings) do
    vim.keymap.set(mapping.mode, mapping.lhs, mapping.rhs, {
      desc = mapping.desc,
      silent = true,
      noremap = true,
    })
  end

  applied = mappings

  -- Return the mappings for reference
  return mappings
end

---Remove keymappings applied by setup()
function M.delete()
  for _, mapping in ipairs(applied) do
    pcall(vim.keymap.del, mapping.mode, mapping.lhs)
  end
  applied = {}
end

---Print current keymapping status
function M.status()
  print("Plamo Translate Keymapping Status:")
  print("Leader key: " .. (vim.g.mapleader or "not set"))
  print("")

  if #applied == 0 then
    print("  No keymaps applied (keymaps.setup() has not been called)")
    return
  end

  for _, mapping in ipairs(applied) do
    local found = vim.fn.maparg(mapping.lhs, mapping.mode) ~= ""
    local status = found and "✓" or "✗"
    print(string.format("  %s [%s] %s - %s", status, mapping.mode, mapping.lhs, mapping.desc))
  end
end

return M