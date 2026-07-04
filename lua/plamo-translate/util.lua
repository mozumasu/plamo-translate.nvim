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

---Create a progress notifier that overwrites its own notification instead of
---stacking new ones. nvim-notify replaces via opts.replace (previous record),
---snacks.nvim via opts.id; the built-in vim.notify ignores both and falls
---back to one message per update.
---@param id string Stable identifier for backends that replace by id
---@return { update: fun(msg: string, level?: vim.log.levels) }
function M.progress(id)
  local last
  local handle = {}

  ---@param msg string
  ---@param level? vim.log.levels
  function handle.update(msg, level)
    vim.schedule(function()
      local ok, ret = pcall(vim.notify, msg, level or vim.log.levels.INFO, {
        title = "PlamoTranslate",
        id = id,
        replace = last,
      })
      if ok then
        last = ret
      end
    end)
  end

  return handle
end

---Detect if text contains Japanese characters
---(Hiragana, Katakana, CJK ideographs; byte-pattern heuristic)
---@param text string
---@return boolean
function M.contains_japanese(text)
  return text:find("[\228-\233][\128-\191][\128-\191]") ~= nil
    or text:find("[\227][\129-\130][\128-\191]") ~= nil
    or text:find("[\227][\131][\128-\191]") ~= nil
end

---Strip common comment markers (//, /*, #, --, ;, <!-- -->, """ etc.) from text
---@param text string
---@return string
function M.strip_comment_markers(text)
  text = text:gsub("^/%*+", ""):gsub("%*+/$", "")
  text = text:gsub("^<!%-%-", ""):gsub("%-%->$", "")
  text = text:gsub('^"""', ""):gsub('"""$', "")
  text = text:gsub("^'''", ""):gsub("'''$", "")

  local lines = vim.split(text, "\n")
  for i, line in ipairs(lines) do
    lines[i] = line:gsub("^%s*([/#;%-%*]+)%s*", "")
  end

  while #lines > 0 and lines[1]:match("^%s*$") do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end

  return vim.trim(table.concat(lines, "\n"))
end

---Append chars from src into result lines, breaking when width exceeds max_width
---@param result string[]
---@param src string
---@param max_width integer
local function break_by_char(result, src, max_width)
  local current = ""
  -- iterate over UTF-8 characters
  for char in src:gmatch("[%z\1-\127\194-\253][\128-\191]*") do
    local candidate = current .. char
    if vim.fn.strdisplaywidth(candidate) <= max_width then
      current = candidate
    else
      if current ~= "" then
        table.insert(result, current)
      end
      current = char
    end
  end
  if current ~= "" then
    table.insert(result, current)
  end
end

---Wrap a string to fit within max_width, breaking at spaces then by character
---@param text string
---@param max_width integer
---@return string[]
function M.wrap_text(text, max_width)
  local result = {}
  for _, line in ipairs(vim.split(text, "\n")) do
    if vim.fn.strdisplaywidth(line) <= max_width then
      table.insert(result, line)
    else
      local current = ""
      for _, word in ipairs(vim.split(line, " ")) do
        -- word itself is wider than max_width: break it by character
        if vim.fn.strdisplaywidth(word) > max_width then
          if current ~= "" then
            table.insert(result, current)
            current = ""
          end
          break_by_char(result, word, max_width)
        else
          local candidate = current == "" and word or (current .. " " .. word)
          if vim.fn.strdisplaywidth(candidate) <= max_width then
            current = candidate
          else
            if current ~= "" then
              table.insert(result, current)
            end
            current = word
          end
        end
      end
      if current ~= "" then
        table.insert(result, current)
      end
    end
  end
  return result
end

return M
