local position = require("cc_position")
local toc7 = require("toc_book7")
local toc8 = require("toc_book8")

local BOOKS = {
  { id = 1, title = "Dungeon Crawler Carl", chapters = 47, alternates = {} },
  { id = 2, title = "Carl's Doomsday Scenario", chapters = 25, alternates = {} },
  { id = 3, title = "The Dungeon Anarchist's Cookbook", chapters = 34, alternates = {} },
  { id = 4, title = "The Gate of the Feral Gods", chapters = 34, alternates = {} },
  { id = 5, title = "The Butcher's Masquerade", chapters = 75,
    alternates = { { chapters = 77, map = { ["62"] = 61, ["63"] = 62, ["64"] = 64, ["65"] = 64, ["66"] = 64,
      ["67"] = 65, ["68"] = 66, ["69"] = 67, ["70"] = 68, ["71"] = 69, ["72"] = 70, ["73"] = 71, ["74"] = 72,
      ["75"] = 73, ["76"] = 74, ["77"] = 75 } } } },
  { id = 6, title = "The Eye of the Bedlam Bride", chapters = 72, alternates = {} },
  { id = 7, title = "This Inevitable Ruin", chapters = 87, alternates = {} },
  { id = 8, title = "A Parade of Horribles", chapters = 98, alternates = {} },
}

local function index_of(toc, title)
  for i, e in ipairs(toc) do if e.title == title then return i end end
  error("no toc entry " .. title)
end

local function chapter(toc, title)
  return position.chapter_of(toc, index_of(toc, title))
end

local S = {}

-- book_of ---------------------------------------------------------------------------

function S.the_two_real_titles_resolve()
  T.eq(position.book_of("This Inevitable Ruin: Dungeon Crawler Carl Book VII", BOOKS), 7)
  T.eq(position.book_of("A Parade of Horribles: Dungeon Crawler Carl Book 8", BOOKS), 8)
end

function S.book_one_only_when_nothing_else_matches()
  T.eq(position.book_of("Dungeon Crawler Carl", BOOKS), 1)
  T.eq(position.book_of("Dungeon Crawler Carl: A LitRPG/Gamelit Adventure", BOOKS), 1)
  T.eq(position.book_of("Carl's Doomsday Scenario: Dungeon Crawler Carl Book 2", BOOKS), 2)
  T.eq(position.book_of("Dungeon Crawler Carl 6: The Eye of the Bedlam Bride", BOOKS), 6)
end

function S.a_book_suffix_wins_over_a_title_match()
  T.eq(position.book_of("Dungeon Crawler Carl: Book 3", BOOKS), 3)
  T.eq(position.book_of("Dungeon Crawler Carl Book IV", BOOKS), 4)
end

function S.punctuation_and_case_do_not_matter()
  T.eq(position.book_of("THE BUTCHER’S MASQUERADE (Dungeon Crawler Carl #5)", BOOKS), 5)
end

function S.not_a_crawl_book()
  T.eq(position.book_of("Fire & Blood", BOOKS), nil)
  T.eq(position.book_of("", BOOKS), nil)
  T.eq(position.book_of(nil, BOOKS), nil)
end

-- chapter_of ------------------------------------------------------------------------

function S.a_chapter_entry_is_its_own_number()
  T.eq(chapter(toc7, "Chapter 1"), 1)
  T.eq(chapter(toc7, "Chapter 42"), 42)
  T.eq(chapter(toc7, "Chapter 87"), 87)
  T.eq(chapter(toc8, "Chapter 98"), 98)
end

function S.an_interlude_belongs_to_the_next_chapter()
  T.eq(chapter(toc7, "Dante"), 5, "Dante sits between chapters 4 and 5")
  T.eq(chapter(toc7, "Milk"), 26)
  T.eq(chapter(toc7, "II. The Ramp-Up"), 20, "a part heading before chapter 20")
  T.eq(chapter(toc7, "Battalions"), 20)
  T.eq(chapter(toc7, "Several days earlier"), 69)
  T.eq(chapter(toc8, "Heat 2 of 7"), 6)
  T.eq(chapter(toc8, "Horrible Two"), 88, "the eleventh floor's opening interlude")
end

function S.everything_before_the_first_chapter_is_chapter_one()
  T.eq(chapter(toc7, "Title Page"), 1)
  T.eq(chapter(toc7, "Prologue"), 1)
  T.eq(chapter(toc7, "Tempest’s Floor 8 Recap School Report"), 1)
  T.eq(chapter(toc8, "Samantha’s Floor 7 Recap"), 1)
end

function S.the_epilogue_and_everything_after_it_is_the_end()
  T.eq(chapter(toc7, "Epilogue"), position.END_OF_BOOK)
  T.eq(chapter(toc7, "About the Author"), position.END_OF_BOOK)
  T.eq(chapter(toc8, "Mailing List! Patreon! Reddit! Twitter! Spotify!?"), position.END_OF_BOOK)
end

function S.a_non_breaking_space_is_a_space()
  -- The real book 8 table of contents has one in "Also by Matt Dinniman"; an EPUB could as
  -- easily put one in "Chapter 12".
  local toc = { { title = "Chapter\194\16012" }, { title = "Epilogue\194\160" } }
  T.eq(position.chapter_of(toc, 1), 12)
  T.eq(position.chapter_of(toc, 2), position.END_OF_BOOK)
  T.eq(position.chapter_count(toc), 12)
end

function S.chapter_titles_may_carry_a_name()
  local toc = { { title = "Chapter 1: The Stairs" }, { title = "CHAPTER 2 - Down" }, { title = "Interlude" } }
  T.eq(position.chapter_of(toc, 1), 1)
  T.eq(position.chapter_of(toc, 2), 2)
  T.eq(position.chapter_of(toc, 3), 3)
end

function S.no_toc_means_no_chapter()
  T.eq(position.chapter_of({}, nil), nil)
  T.eq(position.chapter_of({}, 1), nil)
  T.eq(position.chapter_of(toc7, nil), nil)
end

-- edition ---------------------------------------------------------------------------

function S.the_chapter_count_of_a_toc_is_its_highest_chapter()
  T.eq(position.chapter_count(toc7), 87)
  T.eq(position.chapter_count(toc8), 98)
  T.eq(position.chapter_count({}), 0)
end

local function fake_toc(n)
  local t = { { title = "Title Page" } }
  for i = 1, n do t[#t + 1] = { title = "Chapter " .. i } end
  t[#t + 1] = { title = "Epilogue" }
  return t
end

function S.a_toc_with_the_alternate_count_is_renumbered()
  local five = BOOKS[5]
  T.eq(position.edition_chapter(five, 77, 70), 68, "original edition chapter 70 is the Ace 68")
  T.eq(position.edition_chapter(five, 77, 10), 10, "early chapters agree")
  T.eq(position.edition_chapter(five, 75, 70), 70, "the Ace count applies no map")
  T.eq(position.edition_chapter(five, 60, 70), 70, "an unknown count is used as is")
  T.eq(position.edition_chapter(five, 77, position.END_OF_BOOK), position.END_OF_BOOK)
  T.eq(position.edition_chapter(BOOKS[1], 47, 12), 12, "a book with no alternates")
end

-- detect ----------------------------------------------------------------------------

function S.detect_puts_it_together()
  local p = position.detect("This Inevitable Ruin: Dungeon Crawler Carl Book VII", toc7, index_of(toc7, "Chapter 12"), BOOKS)
  T.eq(p.book, 7)
  T.eq(p.chapter, 12)
  T.eq(p.frontier, 7012)
  T.eq(p.title, "This Inevitable Ruin")
end

function S.detect_applies_the_edition_map()
  local toc = fake_toc(77)
  local p = position.detect("The Butcher's Masquerade", toc, 71, BOOKS) -- entry 71 is "Chapter 70"
  T.eq(toc[71].title, "Chapter 70")
  T.eq(p.chapter, 68)
  T.eq(p.frontier, 5068)
end

function S.detect_clamps_past_the_last_chapter_to_the_end()
  local toc = { { title = "Chapter 47" }, { title = "Afterword" } }
  local p = position.detect("Dungeon Crawler Carl", toc, 2, BOOKS)
  T.eq(p.chapter, position.END_OF_BOOK)
end

function S.detect_gives_nothing_for_another_book_or_no_toc()
  T.eq(position.detect("Fire & Blood", toc7, 10, BOOKS), nil)
  T.eq(position.detect("This Inevitable Ruin", {}, nil, BOOKS), nil)
end

-- overrides and stamps --------------------------------------------------------------

function S.an_override_is_book_colon_chapter()
  local p = position.parse_override("7:12", BOOKS)
  T.eq(p.book, 7); T.eq(p.chapter, 12); T.eq(p.frontier, 7012)
  p = position.parse_override("7:end", BOOKS)
  T.eq(p.chapter, position.END_OF_BOOK); T.eq(p.frontier, 7999)
  p = position.parse_override(" 3 ", BOOKS)
  T.eq(p.book, 3); T.eq(p.chapter, position.END_OF_BOOK, "a bare book means finished, as on the site")
  T.eq(position.parse_override("9:1", BOOKS), nil, "no such book")
  T.eq(position.parse_override("7:0", BOOKS), nil)
  T.eq(position.parse_override("7:88", BOOKS), nil, "past the count")
  T.eq(position.parse_override("carl", BOOKS), nil)
  T.eq(position.parse_override("", BOOKS), nil)
end

function S.a_stamp_reads_like_the_site()
  T.eq(position.stamp(7, 12), "Book 7 · Ch 12")
  T.eq(position.stamp(7, position.END_OF_BOOK), "Book 7 · end")
  T.eq(position.stamp(7, 0), "Book 7")
  T.eq(position.stamp_key(7012), "Book 7 · Ch 12")
  T.eq(position.stamp_key(1999), "Book 1 · end")
end


function S.previous_chapter_is_the_cut_the_plugin_reads_to()
  T.eq(position.previous_chapter({ chapter = 6, frontier = 4006 }), 4005)
  T.eq(position.previous_chapter({ chapter = 1, frontier = 4001 }), 4000, "chapter 1: nothing before it in this book")
  T.eq(position.previous_chapter({ chapter = position.END_OF_BOOK, frontier = 4999 }), 4999, "a finished book is told by its paragraph")
end

return S
