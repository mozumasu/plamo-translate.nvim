local M = {}

local defaults = {
  PlamoTranslateNormal = { link = "Pmenu" },
  PlamoTranslateBorder = { link = "Pmenu" },
  PlamoTranslateTitle = { link = "Title" },
}

---Define the plugin's highlight groups with `default = true` so users can
---override them via `vim.api.nvim_set_hl` without us clobbering their choice.
function M.setup()
  for name, opts in pairs(defaults) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("keep", { default = true }, opts))
  end
end

---winhighlight string applied to every floating window the plugin creates.
---This makes the popup opaque even when the user has `NormalFloat` set to a
---transparent background globally.
M.winhighlight = table.concat({
  "Normal:PlamoTranslateNormal",
  "NormalFloat:PlamoTranslateNormal",
  "FloatBorder:PlamoTranslateBorder",
  "FloatTitle:PlamoTranslateTitle",
}, ",")

return M
