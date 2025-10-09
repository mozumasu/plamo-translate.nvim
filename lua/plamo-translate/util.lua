local M = {}

---@param msg string
---@param level? vim.log.levels
function M.notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO, { title = "PlamoTranslate" })
  end)
end

---@param msg string
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

---@param msg string
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

---@param msg string
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

return M
