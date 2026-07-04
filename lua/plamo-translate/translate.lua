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

-- Jobs cancelled via M.cancel(); their on_exit reports "cancelled" silently
local cancelled = {}

---Cancel a running translation job started by M.translate()
---@param job_id integer|nil
function M.cancel(job_id)
  if job_id and job_id > 0 then
    cancelled[job_id] = true
    pcall(vim.fn.jobstop, job_id)
  end
end

---Translate text using plamo-translate CLI
---@param text string Text to translate
---@param callback function Callback function to receive translation result
---@return integer|nil job_id Job ID usable with M.cancel(), nil on startup failure
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

  -- Channel callbacks deliver partial lines: the first element of each chunk
  -- continues the last element of the previous one, "" marks a line boundary.
  local stdout_parts = { "" }
  local stderr_parts = { "" }

  local function append_chunk(parts, data)
    parts[#parts] = parts[#parts] .. data[1]
    for i = 2, #data do
      table.insert(parts, data[i])
    end
  end

  local job_id = vim.fn.jobstart(cmd, {
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        append_chunk(stdout_parts, data)
      end
    end,
    on_exit = function(id, exit_code, _)
      if cancelled[id] then
        cancelled[id] = nil
        callback(nil, "cancelled")
        return
      end
      if exit_code == 0 then
        local result = table.concat(stdout_parts, "\n"):gsub("\n+$", "")
        if result == "" then
          util.warn("Translation succeeded but no output received")
        end
        callback(result, nil)
      else
        local error_msg = "Translation failed with exit code: " .. exit_code
        local stderr_text = vim.trim(table.concat(stderr_parts, "\n"))
        if stderr_text ~= "" then
          error_msg = error_msg .. "\n" .. stderr_text
        end
        util.error(error_msg)
        callback(nil, error_msg)
      end
    end,
    on_stderr = function(_, data, _)
      if data and #data > 0 then
        append_chunk(stderr_parts, data)
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
    return nil
  end

  -- Send text to stdin
  vim.fn.chansend(job_id, text)
  vim.fn.chanclose(job_id, "stdin")

  return job_id
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
