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
    -- Default display mode for :PlamoTranslate on a visual selection.
    -- "popup"   : show result in a floating window (default)
    -- "virtual" : render result as virtual text below the selection
    default_display = "popup",
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
        width = 0.5, -- 50% of screen width
        height = 0.4, -- 40% of screen height
      },
      right = {
        width = 0.4, -- Sidebar-like width
        height = 1.0, -- Full height
      },
    },
    -- Bounds (as ratios of screen) used when show() is called with
    -- `fit_content = true`. The window is sized to its content but kept
    -- within these limits so very short or very long results stay sane.
    fit = {
      min_width = 0.3,
      max_width = 0.8,
      min_height = 0.15,
      max_height = 0.6,
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
