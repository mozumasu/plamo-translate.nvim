local M = {}
local config = require("plamo-translate.config")
local util = require("plamo-translate.util")

---Get selected text in visual mode
---@return string
function M.get_visual_selection()
  -- Get visual selection marks
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- Get selected lines
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  -- Get text from buffer
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

  -- Handle partial selection on first and last lines
  if #lines > 0 then
    local start_col = start_pos[3]
    local end_col = end_pos[3]

    -- Check if it's a line-wise selection (V mode)
    -- vim.v.maxcol (2147483647) indicates selection to end of line
    local is_line_selection = end_col >= 2147483647

    if not is_line_selection then
      -- Character-wise or block-wise selection
      if #lines == 1 then
        -- Single line: extract from start_col to end_col
        lines[1] = string.sub(lines[1], start_col, end_col)
      else
        -- Multiple lines: trim first and last lines
        lines[1] = string.sub(lines[1], start_col)
        lines[#lines] = string.sub(lines[#lines], 1, end_col)
      end
    end
    -- For line-wise selection, keep full lines as is
  end

  -- Concatenate lines with newlines
  local result = table.concat(lines, "\n")
  return result
end

---Translate text using plamo-translate CLI
---@param text string Text to translate
---@param callback function Callback function to receive translation result
function M.translate(text, callback)
  -- Build command array by combining base command with arguments
  local cmd = {}
  vim.list_extend(cmd, config.cli.cmd)

  -- Add language options only if specified (not nil or "Auto")
  if config.cli.from and config.cli.from ~= "Auto" then
    vim.list_extend(cmd, { "--from", config.cli.from })
  end

  if config.cli.to and config.cli.to ~= "Auto" then
    vim.list_extend(cmd, { "--to", config.cli.to })
  end

  local stdout_data = {}

  -- Remove debug output
  -- util.info("Running command: " .. table.concat(cmd, " "))

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        -- Filter out empty strings but keep all actual content
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stdout_data, line)
          end
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      if exit_code == 0 then
        local result = table.concat(stdout_data, "\n")
        if result == "" then
          util.warn("Translation succeeded but no output received")
        end
        callback(result, nil)
      else
        local error_msg = "Translation failed with exit code: " .. exit_code
        util.error(error_msg)
        callback(nil, error_msg)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        local stderr_msg = table.concat(data, "\n")
        util.error("Translation stderr: " .. stderr_msg)
      end
    end,
    stdin = "pipe",
  })

  if job_id <= 0 then
    local error_msg = "Failed to start translation job"
    util.error(error_msg)
    callback(nil, error_msg)
    return
  end

  -- Send text to stdin
  vim.fn.chansend(job_id, text)
  vim.fn.chanclose(job_id, "stdin")
end

return M
