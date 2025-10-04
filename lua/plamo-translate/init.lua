local M = {}

function M.setup(opts)
  require("plamo-translate.config").setup(opts)
  print("plamo-translate is set up!")
end

return M
