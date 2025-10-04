---@class plamo-translate.config: plamo-translate.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("plamo-translate")

---@class plamo-translate.Config
local defaults = {
  -- TODO: Add default configuration options
  -- Configuration settings for the plamo-translate command
  -- Configuration settings for popup windows
  -- Language configuration settings
}

local config = vim.deepcopy(defaults) ---@as plamo-translate.Config

---@param opts? plamo-translate.Config
function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
end

setmetatable(M, {
  __index = function(_, key)
    return config[key]
  end,
})

return M
