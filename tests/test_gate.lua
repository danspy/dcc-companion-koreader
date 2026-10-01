local gate = require("cc_gate")

-- A tiny index in the export's shape. Keys are book * 1000 + chapter.
local ENTRIES = {
  { id = "carl", kind = "character", name = "Carl", role = "Protagonist", revealedAt = 1001,
    aka = { { name = "Carl the Compensated Anarchist", key = 1001 }, { name = "Crawler Carl", key = 1001 } },
    taglines = { { key = 1001, book = 1, chapter = 1, text = "I'm Carl." } } },
  { id = "princess-donut", kind = "character", name = "Princess Donut", role = "Carl's cat", revealedAt = 1001,
    aka = { { name = "Donut", key = 1001 }, { name = "Princess Donut the Queen Anne Chonk", key = 1020 } },
    taglines = { { key = 1001, book = 1, chapter = 1, text = "A cat." }, { key = 1003, book = 1, chapter = 3, text = "A talking cat." } } },
  { id = "hamed", kind = "character", name = "The Night Wyrm", role = "", revealedAt = 3019,
    aka = { { name = "Hamed", key = 6032 } },
    taglines = { { key = 3019, book = 3, chapter = 19, text = "A name on a ring." } } },
  { id = "milk", kind = "character", name = "Milk", role = "", revealedAt = 3027, aka = {},
    taglines = { { key = 3027, book = 3, chapter = 27, text = "Milk." } } },
  { id = "floor-3", kind = "floor", name = "The Over City", role = "Floor 3", revealedAt = 1044, aka = {},
    taglines = { { key = 2002, book = 2, chapter = 2, text = "Welcome to the Over City!" } } },
  { id = "donut-hole", kind = "item", name = "Donut Hole", role = "", revealedAt = 2005, aka = {},
    taglines = { { key = 2005, book = 2, chapter = 5, text = "An item." } } },
}

local CARL = {
  id = "carl", descriptions = {},
  beats = {
    { key = 1001, book = 1, chapter = 1, headline = "Pink Crocs", text = "I went out after the cat.", voice = "self" },
    { key = 1002, book = 1, chapter = 2, headline = "The stairs", text = "Down we go.", voice = "self" },
    { key = 1005, book = 1, chapter = 5, headline = "Mordecai", text = "A guide.", voice = "self" },
    { key = 1999, book = 1, chapter = 999, headline = "Footwear", text = "Still none.", voice = "self" },
    { key = 2003, book = 2, chapter = 3, headline = "A class", text = "Compensated Anarchist.", voice = "self" },
    { key = 4012, book = 4, chapter = 12, headline = "Later", text = "Open to most.", voice = "self" },
  },
}

local S = {}

function S.reached_is_one_comparison()
  T.ok(gate.reached(4012, 4012))
  T.ok(gate.reached(4013, 4012))
  T.ok(not gate.reached(4011, 4012))
  T.ok(not gate.reached(0, 1001), "no position reaches nothing")
end

function S.tagline_is_the_latest_reached()
  local donut = ENTRIES[2]
  T.eq(gate.tagline_for(donut, 1001), "A cat.")
  T.eq(gate.tagline_for(donut, 1002), "A cat.")
  T.eq(gate.tagline_for(donut, 1003), "A talking cat.")
  T.eq(gate.tagline_for(donut, 8999), "A talking cat.")
  T.eq(gate.tagline_for(ENTRIES[5], 1050), nil, "a floor's premise waits for arrival")
  T.eq(gate.tagline_for(ENTRIES[5], 2002), "Welcome to the Over City!")
end

function S.normalize_strips_what_a_long_press_drags_in()
  T.eq(gate.normalize("Donut"), "donut")
  T.eq(gate.normalize("  Donut’s "), "donut")
  T.eq(gate.normalize("Donut's"), "donut")
  T.eq(gate.normalize("“Carl!”"), "carl")
  T.eq(gate.normalize("Princess  Donut,"), "princess donut")
  T.eq(gate.normalize("Carl's."), "carl")
  T.eq(gate.normalize(""), "")
  T.eq(gate.normalize(nil), "")
end

local function ids(hits)
  local out = {}
  for _, h in ipairs(hits) do out[#out + 1] = h.id end
  return table.concat(out, ",")
end

function S.a_name_matches_at_a_word_start()
  T.eq(ids(gate.match("Donut", ENTRIES, 1001)), "princess-donut", "an alias, exact")
  T.eq(ids(gate.match("Princess", ENTRIES, 1001)), "princess-donut")
  T.eq(ids(gate.match("Donut", ENTRIES, 2005)), "princess-donut,donut-hole", "the exact alias ranks above a prefix of a name")
  T.eq(ids(gate.match("carl", ENTRIES, 1001)), "carl", "case does not matter")
  T.eq(ids(gate.match("Carl's", ENTRIES, 1001)), "carl")
  T.eq(ids(gate.match("arl", ENTRIES, 1001)), "", "three letters inside a word is not a word start")
end

function S.an_unreached_name_is_the_same_as_an_unknown_word()
  T.eq(ids(gate.match("Hamed", ENTRIES, 6031)), "", "the alias has its own point")
  T.eq(ids(gate.match("Hamed", ENTRIES, 6032)), "hamed")
  T.eq(ids(gate.match("Wyrm", ENTRIES, 3018)), "")
  T.eq(ids(gate.match("Wyrm", ENTRIES, 3019)), "hamed")
  T.eq(ids(gate.match("Milk", ENTRIES, 3026)), "")
  T.eq(ids(gate.match("milk", ENTRIES, 3027)), "milk", "the reader chose the word, so case is not a rule here")
  T.eq(ids(gate.match("Over City", ENTRIES, 1044)), "floor-3", "a floor's name opens at nameAt")
  T.eq(ids(gate.match("Over City", ENTRIES, 1043)), "")
  T.eq(ids(gate.match("Chonk", ENTRIES, 1019)), "", "a timed alias is not searched before its point")
  T.eq(ids(gate.match("Chonk", ENTRIES, 1020)), "princess-donut")
  T.eq(ids(gate.match("Carl", ENTRIES, 0)), "", "no position, no names")
end

function S.beats_for_splits_reached_from_sealed()
  local r = gate.beats_for(CARL, 1005, 12)
  T.eq(#r.shown, 3)
  T.eq(r.earlier, 0)
  T.eq(r.sealed, 3)
  T.eq(r.next_key, 1999)
  r = gate.beats_for(CARL, 8999, 12)
  T.eq(#r.shown, 6)
  T.eq(r.sealed, 0)
  T.eq(r.next_key, nil)
  r = gate.beats_for(CARL, 8999, 2)
  T.eq(#r.shown, 2, "only the latest two")
  T.eq(r.shown[1].headline, "A class")
  T.eq(r.shown[2].headline, "Later")
  T.eq(r.earlier, 4)
end

function S.popup_text_shows_only_what_is_reached()
  local text = gate.popup_text(ENTRIES[1], CARL, 1005, 12)
  T.contains(text, "Protagonist")
  T.contains(text, "I'm Carl.")
  T.contains(text, "through Book 1 · Ch 5")
  T.contains(text, "Book 1 · Ch 2 · The stairs")
  T.contains(text, "Down we go.")
  T.lacks(text, "Footwear")
  T.lacks(text, "Compensated")
  T.lacks(text, "Sealed to most")
  T.contains(text, "*** Sealed ***")
  T.contains(text, "3 more entries")
  T.contains(text, "Book 1 · end")
  T.lacks(text, "self", "voice is data, never shown")
end

function S.popup_text_at_the_end_has_no_seal()
  local text = gate.popup_text(ENTRIES[1], CARL, 8999, 12)
  T.lacks(text, "Sealed")
  T.contains(text, "Book 4 · Ch 12 · Later")
  local short = gate.popup_text(ENTRIES[1], CARL, 8999, 2)
  T.contains(short, "4 earlier entries")
  T.lacks(short, "Pink Crocs")
end

function S.popup_text_without_a_file_or_beats_still_reads()
  local text = gate.popup_text(ENTRIES[4], { id = "milk", descriptions = {}, beats = {} }, 3027, 12)
  T.contains(text, "Milk.")
  T.lacks(text, "Sealed")
  T.lacks(text, "Story so far")
  local floor = gate.popup_text(ENTRIES[5], nil, 1044, 12)
  T.contains(floor, "Floor 3")
  T.contains(floor, "*** Sealed ***")
  T.contains(floor, "Book 2 · Ch 2", "a sealed premise says when it opens")
end

function S.the_latest_description_reached_is_quoted()
  local file = { id = "x", beats = {}, descriptions = {
    { key = 2005, book = 2, chapter = 5, source = "System AI", text = "An item. Eventually useful." },
    { key = 3001, book = 3, chapter = 1, source = "System AI", text = "An upgraded item." },
  } }
  local text = gate.popup_text(ENTRIES[6], file, 2010, 12)
  T.contains(text, "Eventually useful")
  T.lacks(text, "upgraded")
  T.contains(text, "Book 2 · Ch 5")
  text = gate.popup_text(ENTRIES[6], file, 3001, 12)
  T.contains(text, "upgraded")
  T.lacks(text, "Eventually")
end

return S
