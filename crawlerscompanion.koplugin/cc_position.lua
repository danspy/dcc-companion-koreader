--[[--
Where the reader is, read off the open book.

A reading position is a book and a chapter, and both collapse to one number the whole
plugin compares against: `book * 1000 + chapter`. This is the same arithmetic the site
uses (src/lib/progress.ts there); the difference is where the two numbers come from.

- The book is found in the document's title. Books 2-8 are matched by their own titles;
  book 1 only when nothing else matched, because "Dungeon Crawler Carl" sits inside every
  title. A "Book N" / "Book VII" / "#N" suffix, when present, wins.
- The chapter is the table-of-contents entry the reader is inside. Walk back from it: the
  first "Chapter N" found is the chapter - N if that entry is the current one, N + 1 if the
  current one is an interlude after it (an interlude after chapter 4 is chapter 5's text,
  because a reader "at chapter 4" may not have turned the page past it). "Epilogue" first
  means the book is finished; nothing found means chapter 1.

The gate sits at the current chapter, not the previous one: a reader partway through a
chapter may be shown a fact from a few pages ahead, and the alternative makes "who is this?"
fail on the name they have just met.

Nothing here touches KOReader. It is plain Lua so it can be tested with the real tables of
contents of the real books (tests/fixtures/).
--]]

local M = {}

M.STRIDE = 1000
M.END_OF_BOOK = 999

local ROMAN = { i = 1, ii = 2, iii = 3, iv = 4, v = 5, vi = 6, vii = 7, viii = 8, ix = 9, x = 10 }

-- A table of contents can carry a non-breaking space (the real book 8 does), which Lua's
-- %s does not know. It is a space here.
local function trim(s)
  s = s:gsub("\194\160", " ")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Lower-case, ASCII punctuation and anything outside ASCII become spaces, runs collapse.
-- Both sides of every comparison go through this, so a curly apostrophe in a title and a
-- straight one in our list still meet.
local function norm(s)
  s = s:lower():gsub("[^%w]", " "):gsub("%s+", " ")
  return trim(s)
end

local function find_book(books, id)
  for _, b in ipairs(books or {}) do
    if b.id == id then return b end
  end
end

function M.book_of(title, books)
  if type(title) ~= "string" then return nil end
  local t = norm(title)
  if t == "" then return nil end
  local padded = " " .. t .. " "

  local n = t:match("book (%d+)") or ROMAN[t:match("book ([ivx]+)") or ""] or t:match("carl (%d+)")
  n = tonumber(n)
  if n and find_book(books, n) then return n end

  for _, b in ipairs(books or {}) do
    if b.id ~= 1 and padded:find(" " .. norm(b.title) .. " ", 1, true) then return b.id end
  end
  if padded:find(" dungeon crawler carl ", 1, true) and find_book(books, 1) then return 1 end
  return nil
end

local function chapter_number(title)
  if type(title) ~= "string" then return nil end
  return tonumber(trim(title):lower():match("^chapter%s+(%d+)"))
end

local function is_epilogue(title)
  return type(title) == "string" and trim(title):lower():match("^epilogue") ~= nil
end

function M.chapter_of(toc, index)
  if type(toc) ~= "table" or #toc == 0 or type(index) ~= "number" or index < 1 then return nil end
  for i = math.min(index, #toc), 1, -1 do
    local n = chapter_number(toc[i].title)
    if n then
      if i == index then return n end
      return n + 1
    end
    if is_epilogue(toc[i].title) then return M.END_OF_BOOK end
  end
  return 1
end

-- The highest "Chapter N" in the table of contents: how this edition counts.
function M.chapter_count(toc)
  local max = 0
  for _, e in ipairs(toc or {}) do
    local n = chapter_number(e.title)
    if n and n > max then max = n end
  end
  return max
end

-- A table of contents that counts like an alternative edition is renumbered through that
-- edition's map (book 5 has 75 chapters in the Ace edition and 77 in the original). JSON
-- object keys arrive as strings, so the map is read by string first.
function M.edition_chapter(book, toc_count, chapter)
  if chapter == M.END_OF_BOOK or not book or type(book.alternates) ~= "table" then return chapter end
  for _, alt in ipairs(book.alternates) do
    if alt.chapters == toc_count and type(alt.map) == "table" then
      return alt.map[tostring(chapter)] or alt.map[chapter] or chapter
    end
  end
  return chapter
end

function M.frontier(book, chapter)
  return book * M.STRIDE + chapter
end

-- The cut the Recap screen lists this book's entries to: the chapter before the one the
-- reader is on. A finished book is told by its paragraph, so there is no cut to make.
function M.previous_chapter(p)
  if p.chapter == M.END_OF_BOOK then return p.frontier end
  return p.frontier - 1
end

local function place(book, chapter)
  return { book = book.id, chapter = chapter, frontier = M.frontier(book.id, chapter), title = book.title }
end

function M.detect(title, toc, index, books)
  local id = M.book_of(title, books)
  if not id then return nil end
  local chapter = M.chapter_of(toc, index)
  if not chapter then return nil end
  local book = find_book(books, id)
  chapter = M.edition_chapter(book, M.chapter_count(toc), chapter)
  if book.chapters and chapter ~= M.END_OF_BOOK and chapter > book.chapters then
    chapter = M.END_OF_BOOK
  end
  return place(book, chapter)
end

-- "7:12", "7:end", or a bare "7", which means finished - the reading the site gives it.
function M.parse_override(s, books)
  if type(s) ~= "string" then return nil end
  s = trim(s):lower()
  local b, c = s:match("^(%d+)%s*:%s*(%w+)$")
  if not b then
    b = s:match("^(%d+)$")
    c = "end"
  end
  if not b then return nil end
  local book = find_book(books, tonumber(b))
  if not book then return nil end
  local chapter
  if c == "end" then
    chapter = M.END_OF_BOOK
  else
    chapter = tonumber(c)
    if not chapter or chapter < 1 then return nil end
    if book.chapters and chapter > book.chapters then return nil end
  end
  return place(book, chapter)
end

function M.stamp(book, chapter)
  if chapter == M.END_OF_BOOK then return "Book " .. book .. " · end" end
  if chapter == 0 then return "Book " .. book end
  return "Book " .. book .. " · Ch " .. chapter
end

function M.stamp_key(key)
  return M.stamp(math.floor(key / M.STRIDE), key % M.STRIDE)
end

return M
