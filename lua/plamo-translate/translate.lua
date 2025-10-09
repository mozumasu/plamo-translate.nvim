local M = {}
local config = require("plamo-translate.config")
local util = require("plamo-translate.util")

---Get selected text in visual mode
---@return string
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("v")
  -- Get selection end position
  local end_pos = vim.fn.getpos(".")
  -- Get text from selected region
  local lines = vim.fn.getregion(start_pos, end_pos, { type = "v" })
  -- Concatenate lines with newlines
  local result = table.concat(lines, "\n")
  return result
end

---Translate text using plamo-translate CLI
---@param text string Text to translate
---@param callback function Callback function to receive translation result
function M.translate(text, callback)
  local cmd = vim.tbl_deep_extend("force", config.cli.cmd, {
    "--from",
    config.cli.from,
    "--to",
    config.cli.to,
  })

  local stdout_data = {}

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        -- Exclude the last empty line
        if not (data[#data] == "" and #data == 1) then
          vim.list_extend(stdout_data, data)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        local result = table.concat(stdout_data, "\n")
        -- Remove trailing newline
        result = result:gsub("\n$", "")
        callback(result)
      else
        util.error("Translation failed with exit code: " .. exit_code)
        callback(nil)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        util.error("Translation error: " .. table.concat(data, "\n"))
      end
    end,
    stdin = "pipe",
  })

  if job_id <= 0 then
    util.error("Failed to start translation job")
    callback(nil)
    return
  end

  -- Send text to stdin
  vim.fn.chansend(job_id, text)
  vim.fn.chanclose(job_id, "stdin")
end

return M
