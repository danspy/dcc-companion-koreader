--[[--
What the reader may be shown, given where they are.

Everything the export carries is keyed by a resolved integer, so the gate is one comparison:
`frontier >= key`. This module finds the entries a selected word names, picks the tagline and
description reached, splits a story into reached and sealed, and assembles the popup text.

Two rules are worth stating because they are the product:

- Only entries whose `revealedAt` the reader has reached are searched, and only aliases
  whose own key they have reached. An unreached name and an unknown word therefore produce
  the same reply, so the plugin cannot confirm a name exists.
- Matching is at word starts and case-insensitive, because the reader chose the word. The
  site's one-word case rule exists for unprompted screening; this is prompted.

Plain Lua, no KOReader, so it is tested on its own.
--]]

local position = require("cc_position")

local M = {}

M.LIMIT = 12 -- beats shown; the question on a small screen is "where did I last see this?"
M.MAX_HITS = 8

function M.reached(frontier, key)
  return frontier >= key
end

local function latest_reached(list, frontier)
  local best
  for _, x in ipairs(list or {}) do
    if x.key <= frontier and (not best or x.key >= best.key) then best = x end
  end
  return best
end

function M.tagline_for(entry, frontier)
  local t = latest_reached(entry.taglines, frontier)
  return t and t.text or nil
end

function M.description_for(file, frontier)
  return file and latest_reached(file.descriptions, frontier) or nil
end

-- What a long press drags in: case, curly quotes, a trailing possessive, punctuation.
function M.normalize(s)
  if type(s) ~= "string" then return "" end
  s = s:lower()
  s = s:gsub("’", "'"):gsub("‘", "'"):gsub("“", " "):gsub("”", " ")
  s = s:gsub("[%p%s]+$", "")
  s = s:gsub("'s$", "")
  s = s:gsub("%p", " "):gsub("%s+", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function starts_word(name, q)
  return (" " .. name):find(" " .. q, 1, true) ~= nil
end

-- Entries the selected text names, best first: an exact name, an exact alias, then a name
-- or alias the text starts a word of. At most MAX_HITS.
function M.match(query, entries, frontier)
  local q = M.normalize(query)
  if q == "" or type(frontier) ~= "number" or frontier <= 0 then return {} end
  local hits = {}
  for i, e in ipairs(entries or {}) do
    if e.revealedAt <= frontier then
      local rank
      local n = M.normalize(e.name)
      if n == q then rank = 0 elseif starts_word(n, q) then rank = 2 end
      for _, a in ipairs(e.aka or {}) do
        if a.key <= frontier then
          local an = M.normalize(a.name)
          if an == q then rank = math.min(rank or 9, 1)
          elseif starts_word(an, q) then rank = math.min(rank or 9, 3) end
        end
      end
      if rank then hits[#hits + 1] = { rank = rank, order = i, entry = e } end
    end
  end
  table.sort(hits, function(a, b)
    if a.rank ~= b.rank then return a.rank < b.rank end
    return a.order < b.order
  end)
  local out = {}
  for i = 1, math.min(#hits, M.MAX_HITS) do out[i] = hits[i].entry end
  return out
end

-- The beats reached, the latest `limit` of them, and what is still sealed.
function M.beats_for(file, frontier, limit)
  limit = limit or M.LIMIT
  local reached, sealed, next_key = {}, 0, nil
  for _, b in ipairs(file and file.beats or {}) do
    if b.key <= frontier then
      reached[#reached + 1] = b
    else
      sealed = sealed + 1
      if not next_key or b.key < next_key then next_key = b.key end
    end
  end
  local earlier = math.max(0, #reached - limit)
  local shown = {}
  for i = earlier + 1, #reached do shown[#shown + 1] = reached[i] end
  return { shown = shown, earlier = earlier, sealed = sealed, next_key = next_key }
end

local function entries(n)
  return n == 1 and "entry" or "entries"
end

function M.popup_text(entry, file, frontier, limit)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end

  if entry.role and entry.role ~= "" then add(entry.role) end

  local tagline = M.tagline_for(entry, frontier)
  if tagline then
    add(tagline)
  else
    local first = entry.taglines and entry.taglines[1]
    if first then
      add("*** Sealed *** The rest when you reach " .. position.stamp_key(first.key) .. ".")
    end
  end

  local d = M.description_for(file, frontier)
  if d then
    add("")
    add((d.source and d.source ~= "" and (d.source .. " · ") or "") .. position.stamp_key(d.key))
    add(d.text)
  end

  local r = M.beats_for(file, frontier, limit)
  if #r.shown > 0 or r.sealed > 0 then
    add("")
    add("Story so far · through " .. position.stamp_key(frontier))
    if r.earlier > 0 then add("… " .. r.earlier .. " earlier " .. entries(r.earlier)) end
    for _, b in ipairs(r.shown) do
      add("")
      add(position.stamp(b.book, b.chapter) .. " · " .. (b.headline or ""))
      add(b.text or "")
    end
    if r.sealed > 0 then
      add("")
      add("*** Sealed *** " .. r.sealed .. " more " .. entries(r.sealed) .. ". The next when you reach "
        .. position.stamp_key(r.next_key) .. ".")
    end
  end

  return table.concat(lines, "\n")
end

return M
