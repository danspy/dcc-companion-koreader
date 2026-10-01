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
local UIManager = {
  show = function(_, w) shown[#shown + 1] = w end,
  close = function(_, w) closed[#closed + 1] = w end,
  scheduleIn = function() end,
}

local function stub(name, mod) package.preload[name] = function() return mod end end
stub("ui/widget/container/widgetcontainer", widget("container"))
stub("ui/widget/textviewer", widget("textviewer"))
stub("ui/widget/infomessage", widget("infomessage"))
stub("ui/widget/buttondialog", widget("buttondialog"))
stub("ui/widget/inputdialog", (function()
  local W = widget("inputdialog")
  function W:getInputText() return self.input end
  function W:onShowKeyboard() end
  return W
end)())
stub("ui/uimanager", UIManager)
stub("gettext", setmetatable({}, { __call = function(_, s) return s end }))
stub("util", { cleanupSelectedText = function(t) return t end })
stub("logger", { info = function() end, warn = function() end, err = function() end, dbg = function() end })

local function fake_ui(opts)
  local hooks, settings = {}, {}
  local ui = {
    doc_props = { title = opts.title },
    menu = { registerToMainMenu = function(_, plugin) hooks.menu = plugin end },
    highlight = { addToHighlightDialog = function(_, id, fn) hooks.button = { id = id, fn = fn } end },
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

local S = {}

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
  T.contains(w.text, "through Book 1 · Ch 3")
  T.contains(w.text, "I can talk now.")
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
  T.contains(w.text, "Down we go.")
  T.lacks(w.text, "Footwear")
  T.lacks(w.text, "Larracos")
  T.contains(w.text, "2 more entries")
  T.contains(w.text, "Book 1 · end")
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

return S
