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

M.STORY_LINES = 8 -- lines of the current book on the Recap before the rest fold into a count
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

-- The beats reached, the latest `limit` of them (all, by default), and what is still sealed.
function M.beats_for(file, frontier, limit)
  limit = limit or math.huge
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

-- The story so far: a paragraph per finished book, then the current book one line per beat
-- up to `cut`. A pure copy of src/lib/story.ts in the site's repo, held to the same cases
-- (its `thisChapter` is `this_chapter` here); change one and change the other.
function M.story_so_far(file, frontier, cut, max)
  cut = cut or frontier
  max = max or M.STORY_LINES
  local beats = file and file.beats or {}
  local sealed = nil
  do
    local count, next_key = 0, nil
    for _, b in ipairs(beats) do
      if b.key > frontier then
        count = count + 1
        if not next_key or b.key < next_key then next_key = b.key end
      end
    end
    if count > 0 then sealed = { count = count, next_key = next_key } end
  end
  if frontier <= 0 then return { books = {}, current = nil, sealed = sealed } end

  local books, have = {}, {}
  for _, r in ipairs(file and file.recap or {}) do
    if r.key <= frontier then
      books[#books + 1] = { book = r.book, text = r.text }
      have[r.book] = true
    end
  end

  -- The current book: the frontier is inside it (not at its start, not past its end) and
  -- its own paragraph is not reached — a finished book is told by its paragraph, not its list.
  local chapter = frontier % position.STRIDE
  local book = math.floor(frontier / position.STRIDE)
  local current = nil
  if chapter ~= 0 and chapter ~= position.END_OF_BOOK and not have[book] then
    local reached, this_chapter = {}, 0
    for _, b in ipairs(beats) do
      if b.book == book then
        if b.key <= cut then reached[#reached + 1] = b
        elseif b.key <= frontier then this_chapter = this_chapter + 1 end
      end
    end
    local lines = {}
    for i = math.max(1, #reached - max + 1), #reached do
      local b = reached[i]
      lines[#lines + 1] = { chapter = b.chapter, text = b.gist or b.headline or "" }
    end
    current = { book = book, lines = lines, earlier = #reached - #lines, this_chapter = this_chapter }
  end
  return { books = books, current = current, sealed = sealed }
end

-- The connections reached, each resolved to the other entry's index record. An `other` the
-- index does not know is dropped: a row with no name is nothing to open.
function M.relations_for(file, index, frontier)
  local by_id = {}
  for _, e in ipairs(index and index.entries or {}) do by_id[e.id] = e end
  local out = {}
  for _, r in ipairs(file and file.relations or {}) do
    if r.key <= frontier and by_id[r.other] then
      out[#out + 1] = { other = by_id[r.other], kind = r.kind, note = r.note or "", key = r.key }
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

local function chapter_label(ch)
  if ch == position.END_OF_BOOK then return "end" end
  return tostring(ch)
end

local function sealed_line(sealed)
  return "*** Sealed *** " .. sealed.count .. " more " .. entries(sealed.count) .. ". The next when you reach "
    .. position.stamp_key(sealed.next_key) .. "."
end

local function opening(entry, frontier, add)
  if entry.role and entry.role ~= "" then add(entry.role) end
  local tagline = M.tagline_for(entry, frontier)
  if tagline then
    add(tagline)
  else
    local first = entry.taglines and entry.taglines[1]
    if first then add("*** Sealed *** The rest when you reach " .. position.stamp_key(first.key) .. ".") end
  end
end

-- The Recap: role and tagline, a paragraph per finished book, this book one line per beat
-- to the cut, what is still sealed. The short answer a tap opens.
function M.recap_text(entry, file, frontier, cut)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  opening(entry, frontier, add)
  local s = M.story_so_far(file, frontier, cut)
  for _, b in ipairs(s.books) do
    add("")
    add("Book " .. b.book)
    add(b.text)
  end
  if s.current and (#s.current.lines > 0 or s.current.this_chapter > 0) then
    add("")
    add("Book " .. s.current.book .. " · so far")
    if s.current.earlier > 0 then add("… " .. s.current.earlier .. " earlier this book") end
    for _, l in ipairs(s.current.lines) do add("Ch " .. chapter_label(l.chapter) .. " — " .. l.text) end
    if s.current.this_chapter > 0 then
      add("and " .. s.current.this_chapter .. " " .. entries(s.current.this_chapter) .. " in this chapter")
    end
  end
  if s.sealed then
    add("")
    add(sealed_line(s.sealed))
  end
  return table.concat(lines, "\n")
end

-- The whole crawl so far: the System's description where there is one, then every reached
-- beat in voice with its stamp, then what is still sealed.
function M.crawl_text(entry, file, frontier)
  local lines = {}
  local function add(s) lines[#lines + 1] = s end
  opening(entry, frontier, add)
  local d = M.description_for(file, frontier)
  if d then
    add("")
    add((d.source and d.source ~= "" and (d.source .. " · ") or "") .. position.stamp_key(d.key))
    add(d.text)
  end
  local r = M.beats_for(file, frontier)
  if #r.shown > 0 or r.sealed > 0 then
    add("")
    add("The whole crawl so far · through " .. position.stamp_key(frontier))
    for _, b in ipairs(r.shown) do
      add("")
      add(position.stamp(b.book, b.chapter) .. " · " .. (b.headline or ""))
      add(b.text or "")
    end
    if r.sealed > 0 then
      add("")
      add(sealed_line({ count = r.sealed, next_key = r.next_key }))
    end
  end
  return table.concat(lines, "\n")
end

return M
