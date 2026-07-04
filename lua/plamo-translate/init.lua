local M = {}

---Setup the plugin
---@param opts? table Configuration options
function M.setup(opts)
  opts = opts or {}

  -- Setup configuration
  require("plamo-translate.config").setup(opts)

  -- Define default highlight groups and re-apply them on colorscheme changes
  -- so popups stay opaque even when the user customises NormalFloat.
  require("plamo-translate.highlights").setup()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("PlamoTranslateHighlights", { clear = true }),
    callback = function()
      require("plamo-translate.highlights").setup()
    end,
  })

  -- Register all commands
  require("plamo-translate.commands").setup()

  -- Setup keymaps if requested (true = defaults, table = custom options)
  if opts.keymaps then
    require("plamo-translate.keymaps").setup(type(opts.keymaps) == "table" and opts.keymaps or nil)
  end
end

-- Export keymap utilities for manual use
M.keymaps = require("plamo-translate.keymaps")

return M
