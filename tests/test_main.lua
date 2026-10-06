-- main.lua under stubbed KOReader modules: the wiring, not the widgets. What is asserted is
-- that the highlight button is registered, that the position is read off a fake document,
-- and what the reader is shown for a reached name, an unreached one, and no book at all.

local root = arg[0]:match("^(.*)/tests/run%.lua$") or "."

-- KOReader's widget classes: extend() makes a class, new() makes an instance and runs init().
local function widget(kind)
  local W = { __kind = kind }
  W.__index = W
  function W:extend(o)
    o = o or {}
    o.__index = o
    return setmetatable(o, self)
  end
  function W:new(o)
    o = o or {}
    setmetatable(o, self)
    if o.init then o:init() end
    return o
  end
  return W
end

local shown, closed = {}, {}
local topmost -- what the fake UIManager says is on top, for the self-test
local UIManager = {
  show = function(_, w) shown[#shown + 1] = w end,
  close = function(_, w) closed[#closed + 1] = w end,
  scheduleIn = function(_, _, fn) fn() end, -- the stubs have no clock: run it now
  getTopmostVisibleWidget = function() return topmost end,
}

local function stub(name, mod) package.preload[name] = function() return mod end end
stub("ui/widget/container/widgetcontainer", widget("container"))
stub("ui/widget/textviewer", widget("textviewer"))
stub("ui/widget/infomessage", widget("infomessage"))
stub("ui/widget/buttondialog", widget("buttondialog"))
stub("ui/widget/menu", (function()
  -- KOReader's MenuItem flattens a newline in an item's text to a space (menu.lua:211), so a
  -- second line asked for with "\n" is a run-on line on the device. The stub does the same.
  local W = widget("menu")
  local new = W.new
  function W:new(o)
    for _, item in ipairs(o.item_table or {}) do item.text = item.text:gsub("\n", " ") end
    return new(self, o)
  end
  return W
end)())
stub("ui/widget/inputdialog", (function()
  local W = widget("inputdialog")
  function W:getInputText() return self.input end
  function W:onShowKeyboard() end
  return W
end)())
stub("ui/uimanager", UIManager)
stub("ui/event", { new = function(_, name, ...) return { name = name, args = { ... } } end })
stub("gettext", setmetatable({}, { __call = function(_, s) return s end }))
stub("util", { cleanupSelectedText = function(t) return t end })
stub("logger", { info = function() end, warn = function() end, err = function() end, dbg = function() end })

local function fake_ui(opts)
  local hooks, settings = {}, {}
  -- KOReader's ReaderDictionary: before v2026.07 it only fires DictButtonsReady at the
  -- plugins; from v2026.07 it takes a button spec through addToDictButtons instead.
  local dictionary = {}
  if opts.dict_api then
    dictionary.addToDictButtons = function(_, spec) hooks.dict = spec end
  end
  local ui = {
    doc_props = { title = opts.title },
    menu = { registerToMainMenu = function(_, plugin) hooks.menu = plugin end },
    highlight = { addToHighlightDialog = function(_, id, fn) hooks.button = { id = id, fn = fn } end },
    dictionary = dictionary,
    toc = {
      toc = opts.toc or {},
      fillToc = function() end,
      getTocIndexByPage = function() return opts.index end,
    },
    doc_settings = {
      readSetting = function(_, k) return settings[k] end,
      saveSetting = function(_, k, v) settings[k] = v end,
      delSetting = function(_, k) settings[k] = nil end,
    },
    getCurrentPage = function() return 1 end,
    handleEvent = function(_, ev) hooks.events = hooks.events or {}; hooks.events[#hooks.events + 1] = ev end,
  }
  return ui, hooks, settings
end

local TOC = { { title = "Chapter 1" }, { title = "Chapter 2" }, { title = "Chapter 3" }, { title = "Epilogue" } }

local function boot(opts)
  shown, closed = {}, {}
  local ui, hooks, settings = fake_ui(opts)
  local Companion = require("main")
  Companion.path = root .. "/tests/fixtures"
  local plugin = Companion:new{ ui = ui, document = {} }
  return plugin, hooks, settings, ui
end

local function this_for(ui, text)
  return {
    ui = ui,
    selected_text = { text = text },
    highlightFromHoldPos = function() end,
    onClose = function() end,
  }
end

local function last()
  return shown[#shown]
end

-- A DictQuickLookup as the plugin sees it: the word that was held, and a way to close it.
local function popup_for(ui, word, is_wiki)
  local p = { ui = ui, word = word, lookupword = word, is_wiki = is_wiki or false, closed = false }
  function p:onClose() self.closed = true end
  return p
end

local S = {}

-- A long-press on a single word opens KOReader's dictionary popup, not the highlight
-- menu, so the button has to be in that popup too or a reader never sees it.
function S.on_an_older_koreader_the_button_rides_in_the_dictionary_popup()
  local plugin = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  local popup = popup_for(plugin.ui, "Donut")
  local buttons = { { { id = "close" } } }
  plugin:onDictButtonsReady(popup, buttons)
  T.eq(#buttons, 2, "one row added")
  T.eq(buttons[1][1].id, "crawlers_companion")
  T.eq(buttons[1][1].text, "Crawler's Companion")
  T.eq(buttons[2][1].id, "close", "KOReader's own row is untouched")
  buttons[1][1].callback()
  T.ok(popup.closed, "the popup closes before the entry opens")
  T.eq(last().__kind, "textviewer")
  T.eq(last().title, "Princess Donut")
end

-- The self-test opens KOReader's own dictionary popup and logs the buttons it ended up with,
-- so a device with no screen to look at can still say whether the button is there.
function S.the_selftest_opens_a_real_lookup_and_logs_the_popups_buttons()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  topmost = { button_table = { button_by_id = { close = {}, crawlers_companion = {}, highlight = {} } } }
  local logged = plugin:selftest("Donut")
  T.eq(hooks.events[#hooks.events].name, "LookupWord")
  T.eq(hooks.events[#hooks.events].args[1], "Donut")
  T.eq(logged.buttons, "close crawlers_companion highlight", "sorted, so the log line is stable")
  T.eq(logged.hits, 1, "the fixture knows one Donut")
  topmost = nil
  T.eq(plugin:selftest("Donut").buttons, "", "no popup on top, nothing claimed")
end

function S.the_dictionary_button_stays_out_of_wikipedia_and_other_books()
  local plugin = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  local buttons = { { { id = "close" } } }
  plugin:onDictButtonsReady(popup_for(plugin.ui, "Donut", true), buttons)
  T.eq(#buttons, 1, "nothing added to a Wikipedia popup")
  local other = boot{ title = "Fire & Blood", toc = TOC, index = 3 }
  other:onDictButtonsReady(popup_for(other.ui, "Donut"), buttons)
  T.eq(#buttons, 1, "nothing added on another book")
end

function S.on_a_newer_koreader_the_popup_button_is_registered_once()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3, dict_api = true }
  local spec = hooks.dict
  T.ok(spec, "registered through addToDictButtons at init")
  T.eq(spec.id, "crawlers_companion")
  T.eq(spec.text, "Crawler's Companion")
  T.ok(spec.show_func(popup_for(plugin.ui, "Donut")), "shown for a crawl book")
  T.ok(not spec.show_func(popup_for(plugin.ui, "Donut", true)), "not on a Wikipedia popup")
  local popup = popup_for(plugin.ui, "Donut")
  spec.callback(popup)
  T.ok(popup.closed)
  T.eq(last().title, "Princess Donut")
  -- The event does not fire on this version, but if it ever did, no second button.
  local buttons = { { { id = "close" } } }
  plugin:onDictButtonsReady(popup_for(plugin.ui, "Donut"), buttons)
  T.eq(#buttons, 1, "the event adds nothing where the spec is registered")
  local other, ohooks = boot{ title = "Fire & Blood", toc = TOC, index = 3, dict_api = true }
  T.ok(not ohooks.dict.show_func(popup_for(other.ui, "Donut")), "not on another book")
end

function S.the_button_and_menu_are_registered_at_init()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  T.eq(hooks.menu, plugin)
  T.eq(hooks.button.id, "12_crawlers_companion")
  local btn = hooks.button.fn(this_for(plugin.ui, "Carl"))
  T.eq(btn.text, "Crawler's Companion")
  T.ok(btn.show_in_highlight_dialog_func(), "shown for a crawl book at a chapter")
end

function S.a_reached_name_opens_its_entry_gated_at_the_chapter()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Donut")).callback()
  local w = last()
  T.eq(w.__kind, "textviewer")
  T.eq(w.title, "Princess Donut")
  T.contains(w.text, "A talking cat.")
  T.contains(w.text, "Book 1 · so far")
  T.contains(w.text, "Ch 1 — Carried", "the chapter before the one the reader is on")
  T.contains(w.text, "and 1 entry in this chapter", "the beat at 1:3 is counted, not shown")
  w.buttons_table[1][1].callback()
  T.contains(last().text, "through Book 1 · Ch 3")
  T.contains(last().text, "I can talk now.", "the whole crawl is gated at the current chapter")
end

function S.an_unreached_name_reads_exactly_like_an_unknown_word()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Hamed")).callback()
  local a = last()
  hooks.button.fn(this_for(plugin.ui, "Zorblax")).callback()
  local b = last()
  T.eq(a.__kind, "infomessage")
  T.contains(a.text, "*** No record ***")
  T.lacks(a.text, "Wyrm")
  T.eq((a.text:gsub("Hamed", "X")), (b.text:gsub("Zorblax", "X")), "same shape, only the typed word differs")
end

function S.the_sealed_tail_never_names_what_is_sealed()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Carl")).callback()
  local w = last()
  T.eq(w.__kind, "buttondialog", "Carl and Carlos both match, so the reader picks")
  T.eq(#w.buttons, 2)
  w.buttons[1][1].callback()
  w = last()
  T.eq(w.title, "Carl")
  T.contains(w.text, "Ch 2 — Carl and the cat take the stairs.", "the gist on the Recap")
  T.lacks(w.text, "Footwear")
  T.lacks(w.text, "Larracos")
  T.contains(w.text, "2 more entries")
  T.contains(w.text, "Book 1 · end")
  w.buttons_table[1][1].callback()
  w = last()
  T.contains(w.text, "Down we go.", "the beat's text on the whole crawl")
  T.lacks(w.text, "Footwear")
  T.lacks(w.text, "Larracos")
  T.contains(w.text, "2 more entries")
end

function S.another_book_gets_no_button_and_a_plain_answer()
  local plugin, hooks = boot{ title = "Fire & Blood", toc = TOC, index = 3 }
  local btn = hooks.button.fn(this_for(plugin.ui, "Carl"))
  T.ok(not btn.show_in_highlight_dialog_func(), "no button on another book")
  btn.callback()
  T.contains(last().text, "*** No position ***")
end

function S.an_override_beats_detection_and_can_be_cleared()
  local plugin, hooks, settings = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  settings.crawlers_companion_position = "7:12"
  T.eq(plugin:currentPosition().frontier, 7012)
  T.eq(plugin:currentPosition().source, "override")
  hooks.button.fn(this_for(plugin.ui, "Carl")).callback()
  last().buttons[1][1].callback()
  T.contains(last().text, "Book 1\nCarl goes down the stairs after the cat.", "the finished book's paragraph")
  T.contains(last().text, "and 1 entry in this chapter", "7:12 itself is counted, not shown")
  last().buttons_table[1][1].callback()
  T.contains(last().text, "Larracos")
  T.contains(last().text, "through Book 7 · Ch 12")
  settings.crawlers_companion_position = "garbage"
  T.eq(plugin:currentPosition().frontier, 1003, "an unparseable override falls back to detection")
  settings.crawlers_companion_position = nil
  T.eq(plugin:currentPosition().source, "detected")
end

function S.the_menu_says_where_the_reader_is()
  local plugin = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  local items = {}
  plugin:addToMainMenu(items)
  local menu = items.crawlers_companion
  T.ok(menu, "a menu entry")
  T.ok(#menu.sub_item_table >= 4)
  T.contains(menu.sub_item_table[1].text_func(), "Book 1 · Ch 3")
  T.contains(menu.sub_item_table[1].text_func(), "Dungeon Crawler Carl")
  local other = boot{ title = "Fire & Blood", toc = TOC, index = 3 }
  items = {}
  other:addToMainMenu(items)
  T.contains(items.crawlers_companion.sub_item_table[1].text_func(), "No position")
end

function S.the_position_dialog_saves_only_what_parses()
  local plugin, _, settings = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  plugin:askPosition()
  local dialog = last()
  T.eq(dialog.__kind, "inputdialog")
  dialog.input = "nonsense"
  dialog.buttons[1][2].callback()
  T.eq(settings.crawlers_companion_position, nil)
  T.eq(last().__kind, "infomessage")
  dialog.input = "7:end"
  dialog.buttons[1][2].callback()
  T.eq(settings.crawlers_companion_position, "7:end")
  T.eq(plugin:currentPosition().frontier, 7999)
end


function S.a_hit_opens_the_recap_with_one_button_to_the_whole_crawl()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Donut")).callback()
  local w = last()
  T.eq(w.__kind, "textviewer")
  T.eq(w.title, "Princess Donut")
  T.contains(w.text, "A talking cat.")
  T.lacks(w.text, "I can talk now.", "the beat's text belongs to the whole crawl")
  T.eq(#w.buttons_table, 1)
  T.eq(w.buttons_table[1][1].text, "The whole crawl for Princess Donut so far")
  T.eq(w.buttons_table[1][2].text, "Close")
end

function S.the_whole_crawl_carries_every_beat_and_a_connections_button()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Donut")).callback()
  last().buttons_table[1][1].callback()
  local w = last()
  T.eq(w.__kind, "textviewer")
  T.eq(w.title, "Princess Donut · the whole crawl so far")
  T.contains(w.text, "I can talk now.")
  T.eq(w.buttons_table[1][1].text, "Connections · 1")
  T.eq(w.buttons_table[1][1].enabled, true)
  T.eq(w.buttons_table[1][2].text, "Back")
  -- Carlos has no relations: the button is there and disabled, so the row never shifts.
  local p2, h2 = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  h2.button.fn(this_for(p2.ui, "Carl")).callback()
  last().buttons[2][1].callback()
  last().buttons_table[1][1].callback()
  T.eq(last().buttons_table[1][1].text, "Connections · 0")
  T.eq(last().buttons_table[1][1].enabled, false)
end

function S.a_connection_row_opens_the_other_entrys_recap()
  local plugin, hooks = boot{ title = "Dungeon Crawler Carl", toc = TOC, index = 3 }
  hooks.button.fn(this_for(plugin.ui, "Donut")).callback()
  last().buttons_table[1][1].callback()
  last().buttons_table[1][1].callback()
  local menu = last()
  T.eq(menu.__kind, "menu")
  T.eq(menu.title, "Princess Donut · connections")
  T.eq(#menu.item_table, 1)
  T.eq(menu.item_table[1].text, "Carl — partner · Stuck together.", "one line, with a separator the widget keeps")
  T.eq(menu.item_table[1].mandatory, "Book 1 · Ch 1")
  menu.item_table[1].callback()
  T.eq(last().__kind, "textviewer")
  T.eq(last().title, "Carl")
end

return S
