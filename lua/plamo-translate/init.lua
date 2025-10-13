local M = {}

---Setup the plugin
---@param opts? table Configuration options
function M.setup(opts)
  opts = opts or {}

  -- Setup configuration
  require("plamo-translate.config").setup(opts)

  -- Register all commands
  require("plamo-translate.commands").setup()

  -- Setup keymaps if requested
  if opts.keymaps then
    if opts.keymaps == true then
      -- Use default keymaps
      require("plamo-translate.keymaps").setup()
    elseif type(opts.keymaps) == "table" then
      -- Use custom keymap options
      require("plamo-translate.keymaps").setup(opts.keymaps)
    end
  end
end

-- Export keymap utilities for manual use
M.keymaps = require("plamo-translate.keymaps")

return M
