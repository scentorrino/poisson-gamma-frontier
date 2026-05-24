-- remark.lua
-- Converts .remark and .note divs to amsthm environments in LaTeX output.
-- In HTML output the divs are passed through unchanged for CSS styling.

function Div(el)
  local env = nil
  if el.classes:includes('remark') then
    env = 'remark'
  elseif el.classes:includes('note') then
    env = 'note'
  end

  if env and FORMAT:match('latex') then
    local title = el.attributes['title'] or ''
    local begin_env = title ~= ''
      and string.format('\\begin{%s}[%s]', env, title)
      or  string.format('\\begin{%s}', env)

    local result = { pandoc.RawBlock('latex', begin_env) }
    for _, block in ipairs(el.content) do
      table.insert(result, block)
    end
    table.insert(result, pandoc.RawBlock('latex', string.format('\\end{%s}', env)))
    return result
  end
end
