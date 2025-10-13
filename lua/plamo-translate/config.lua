---@class plamo-translate.config: plamo-translate.Config
local M = {}

M.ns = vim.api.nvim_create_namespace("plamo-translate")

---@class plamo-translate.Config
local defaults = {
  cli = {
    cmd = { "plamo-translate", "--no-stream" }, -- base command
    from = "Auto", -- source language ("Auto" = auto detect)
    to = "Auto", -- target language ("Auto" = auto detect)
  },
  window = {
    -- floating window config
    position = "cursor", -- default window position: "center", "cursor", "right"
    border = "rounded", -- border style: "single", "double", "rounded", "solid", "shadow"
    wrap = true, -- wrap long lines
    title = " Translation ",
    title_pos = "center", -- title position: "left", "center", "right"
    -- Position-specific window sizes
    positions = {
      center = {
        width = 0.8, -- 80% of screen for readability
        height = 0.6, -- 60% of screen
      },
      cursor = {
        width = 0.4, -- Smaller, less intrusive
        height = 0.2, -- Compact size
      },
      right = {
        width = 0.4, -- Sidebar-like width
        height = 1.0, -- Full height
      },
    },
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
