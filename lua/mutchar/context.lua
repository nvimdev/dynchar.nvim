local nvim_buf_get_text = vim.api.nvim_buf_get_text
local util = require('mutchar.util')
local ctx = {}

local function factory(fn)
  return function(opt)
    return fn(opt)
  end
end

---check diagnostic have the string
function ctx.diagnostic_match(patterns)
  patterns = type(patterns) == 'string' and { patterns } or patterns
  local function check_diag(opt)
    local diagnostics = vim.diagnostic.get(opt.buf, { lnum = opt.lnum - 1 })
    if next(diagnostics) == nil then
      return false
    end
    local it = vim.iter(diagnostics):find(function(item)
      return vim.iter(patterns):any(function(pattern)
        return item.message:find(pattern)
      end)
    end)
    return it and true or false
  end
  return factory(check_diag)
end

local function find_space(opt)
  local before = vim.api.nvim_buf_get_text(opt.buf, opt.lnum, opt.col - 1, opt.lnum, opt.col, {})[1]
  if before == ' ' then
    return true
  end
  return false
end

function ctx.non_space_before(opt)
  if not find_space(opt) then
    return true
  end
  return false
end

function ctx.has_space_before(opt)
  return find_space(opt)
end

function ctx.semicolon_in_lua(opt)
  local text = vim.api.nvim_get_current_line()
  if text:sub(#text - 3, #text) == 'self' then
    return true
  end
end

function ctx.rust_match_arrow(opt)
  local char = util.char_before(opt)
  if char == ')' then
    return true
  end
  local line = nvim_buf_get_text(opt.buf, opt.lnum - 1, 0, opt.lnum - 1, opt.col, {})[1]
  if line:match('^%s+_$') then
    return true
  end
  local res = util.ts_cursor_hl(opt)
  if not res then
    return
  end
  local match = {}
  local target = { 'type', 'constant' }
  for _, item in ipairs(res) do
    if vim.tbl_contains(target, item.capture) then
      match[#match + 1] = true
    end
  end

  if #match ~= 2 or #vim.tbl_filter(function(item)
    return item == true
  end, match) ~= 2 then
    return false
  end
  return true
end

function ctx.rust_single_colon(opt)
  local word = util.word_before(opt)
  if not word or word:find('%d') then
    return
  end
  if not word then
    return
  end
  local it = vim.iter(util.ts_cursor_hl(opt))
  local match = {}
  it:map(function(item)
    if item.capture == 'variable' then
      match.variable = true
    end
    if item.capture == 'constant' then
      match.constant = true
    end
  end)
  if match.variable and not match.constant then
    return true
  end
  if ctx.diagnostic_match('expected COLON')(opt) then
    return true
  end
end

function ctx.rust_double_colon(opt)
  local word = util.word_before(opt)
  if not word then
    return
  end
  --match builtin type
  local list = { 'Option', 'String', 'std' }
  if vim.tbl_contains(list, word) then
    return true
  end

  local type = { 'enum', 'namespace' }
  --match module/enum
  if util.ts_hl_match(type, word, opt) then
    return true
  end
end

function ctx.generic_in_cpp()
  local text = vim.api.nvim_get_current_line()
  if text == 'template' then
    return true
  end
  return false
end

return ctx
