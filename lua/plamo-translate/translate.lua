local M = {}
local config = require("plamo-translate.config")
local util = require("plamo-translate.util")

---Get selected text in visual mode (requires Neovim 0.10+)
---@return string
function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  -- visualmode() is "" until visual mode has been used at least once
  local mode = vim.fn.visualmode()
  if mode == "" then
    mode = "v"
  end

  local lines = vim.fn.getregion(start_pos, end_pos, { type = mode })
  return table.concat(lines, "\n")
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
    if util.contains_japanese(text) then
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
    env = {
      TMPDIR = vim.env.TMPDIR ~= nil and vim.env.TMPDIR ~= "" and vim.env.TMPDIR or "/tmp",
    },
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
