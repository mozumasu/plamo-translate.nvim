---@class plamo-translate.config: plamo-translate.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("plamo-translate")

---@class plamo-translate.Config
local defaults = {
  cli = {
    cmd = { "plamo-translate", "--no-stream" }, --based command
    from = "English", -- source language
    to = "Japanese", -- target language
  },
  window = {
    -- floating window config
    width = 0.8,
    height = 0.6,
    border = "rounded", -- border style: "single", "double", "rounded", "solid", "shadow"
  },
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
