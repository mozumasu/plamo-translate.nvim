local M = {}

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
  }

  -- Apply mappings
  for _, mapping in ipairs(mappings) do
    vim.keymap.set(mapping.mode, mapping.lhs, mapping.rhs, {
      desc = mapping.desc,
      silent = true,
      noremap = true,
    })
  end

  -- Return the mappings for reference
  return mappings
end

---Remove default keymappings
function M.delete()
  local prefix = "<leader>t"
  local keys = { "t", "r", "l", "w", "c" }

  for _, key in ipairs(keys) do
    pcall(vim.keymap.del, { "n", "v" }, prefix .. key)
    pcall(vim.keymap.del, "n", prefix .. key)
    pcall(vim.keymap.del, "v", prefix .. key)
  end
end

---Print current keymapping status
function M.status()
  local prefix = "<leader>t"
  local keys = {
    { key = "t", modes = { "n", "v" }, desc = "Translate text" },
    { key = "r", modes = { "v" }, desc = "Replace with translation" },
    { key = "l", modes = { "n" }, desc = "Translate current line" },
    { key = "w", modes = { "n" }, desc = "Translate word under cursor" },
    { key = "c", modes = { "n" }, desc = "Close translation window" },
  }

  print("Plamo Translate Keymapping Status:")
  print("Leader key: " .. (vim.g.mapleader or "not set"))
  print("")

  for _, item in ipairs(keys) do
    local found = false
    for _, mode in ipairs(item.modes) do
      local ok, _ = pcall(vim.fn.maparg, prefix .. item.key, mode)
      if ok and vim.fn.maparg(prefix .. item.key, mode) ~= "" then
        found = true
        break
      end
    end
    local status = found and "✓" or "✗"
    print(string.format("  %s %s%s - %s", status, prefix, item.key, item.desc))
  end
end

return M