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

---Detect if text contains Japanese characters
---@param text string Text to check
---@return boolean True if text contains Japanese characters
local function contains_japanese(text)
  -- Check for Hiragana (U+3040-U+309F), Katakana (U+30A0-U+30FF),
  -- CJK Unified Ideographs (U+4E00-U+9FFF), and CJK symbols (U+3000-U+303F)
  return text:find("[\228-\233][\128-\191][\128-\191]") ~= nil
    or text:find("[\227][\129-\130][\128-\191]") ~= nil
    or text:find("[\227][\131][\128-\191]") ~= nil
end

---Translate text using plamo-translate CLI
---@param text string Text to translate
---@param callback function Callback function to receive translation result
function M.translate(text, callback)
  -- Build command array by combining base command with arguments
  local cmd = {}
  vim.list_extend(cmd, config.cli.cmd)

  -- Determine source and target languages
  local from_lang = config.cli.from
  local to_lang = config.cli.to

  -- Auto-detect language direction when target is "Auto"
  if to_lang == "Auto" or to_lang == nil then
    if contains_japanese(text) then
      -- Japanese to English
      to_lang = "English"
      if from_lang == "Auto" or from_lang == nil then
        from_lang = "Japanese"
      end
    else
      -- English to Japanese
      to_lang = "Japanese"
      if from_lang == "Auto" or from_lang == nil then
        from_lang = "English"
      end
    end
  end

  -- Add language options only if specified (not nil or "Auto")
  if from_lang and from_lang ~= "Auto" then
    vim.list_extend(cmd, { "--from", from_lang })
  end

  if to_lang and to_lang ~= "Auto" then
    vim.list_extend(cmd, { "--to", to_lang })
  end

  local stdout_data = {}
  local stderr_data = {}

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
        if #stderr_data > 0 then
          error_msg = error_msg .. "\n" .. table.concat(stderr_data, "\n")
        end
        util.error(error_msg)
        callback(nil, error_msg)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 and data[1] ~= "" then
        for _, line in ipairs(data) do
          if line ~= "" then
            table.insert(stderr_data, line)
          end
        end
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

---Split text into paragraphs by empty lines
---@param text string Text to split
---@return table List of paragraphs (empty strings represent blank lines)
function M.split_into_paragraphs(text)
  local paragraphs = {}
  local current = {}

  for _, line in ipairs(vim.split(text, "\n")) do
    if line:match("^%s*$") then -- Empty or whitespace-only line
      if #current > 0 then
        table.insert(paragraphs, table.concat(current, "\n"))
        current = {}
      end
      table.insert(paragraphs, "") -- Preserve empty line
    else
      table.insert(current, line)
    end
  end

  -- Don't forget the last paragraph
  if #current > 0 then
    table.insert(paragraphs, table.concat(current, "\n"))
  end

  return paragraphs
end

---Translate paragraphs sequentially
---@param paragraphs table List of paragraphs to translate
---@param on_progress function Progress callback (current, total)
---@param on_complete function Completion callback (result, err)
function M.translate_paragraphs(paragraphs, on_progress, on_complete)
  local results = {}
  local index = 1

  -- Count non-empty paragraphs for progress display
  local total_paragraphs = 0
  for _, para in ipairs(paragraphs) do
    if para ~= "" then
      total_paragraphs = total_paragraphs + 1
    end
  end

  local current_paragraph = 0

  local function translate_next()
    if index > #paragraphs then
      on_complete(table.concat(results, "\n"), nil)
      return
    end

    local para = paragraphs[index]

    -- Preserve empty lines as-is
    if para == "" then
      table.insert(results, "")
      index = index + 1
      -- Use vim.schedule to avoid stack overflow with many empty lines
      vim.schedule(translate_next)
      return
    end

    current_paragraph = current_paragraph + 1
    on_progress(current_paragraph, total_paragraphs)

    M.translate(para, function(result, err)
      if err then
        on_complete(nil, err)
        return
      end
      table.insert(results, result)
      index = index + 1
      translate_next()
    end)
  end

  translate_next()
end

return M
