--[[--
Crawler's Companion for KOReader.

Long-press a name in a Dungeon Crawler Carl book, tap "Crawler's Companion", and get the
entry: who or what it is and what has happened so far, sealed past the chapter the book is
open at. The position is read off the document (cc_position.lua); what may be shown is
decided by cc_gate.lua; this file is only the wiring to KOReader's menu, highlight dialog
and widgets.

@module koplugin.CrawlersCompanion
--]]--

local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local util = require("util")
local _ = require("gettext")

local gate = require("cc_gate")
local position = require("cc_position")
local Store = require("cc_store")

local SETTING = "crawlers_companion_position" -- per document, in its own KOReader settings
local BUTTON_ID = "12_crawlers_companion"      -- sorts just before KOReader's own 12_search

local Companion = WidgetContainer:extend{
    name = "crawlerscompanion",
    is_doc_only = true,
}

function Companion:init()
    self.store = Store.new((self.path or ".") .. "/data")
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    if self.ui and self.ui.highlight then
        self:addToHighlightDialog()
    end
end

-- Where the reader is: an override they typed for this document, or the book and chapter
-- read off the title and the table of contents. nil when neither gives a crawl book.
function Companion:currentPosition()
    local index, err = self.store:load_index()
    if not index then
        logger.warn("crawlerscompanion: no data:", err)
        return nil
    end
    local books = index.books

    local override = self.ui.doc_settings and self.ui.doc_settings:readSetting(SETTING)
    if override then
        local p = position.parse_override(override, books)
        if p then
            p.source = "override"
            return p
        end
    end

    local title = self.ui.doc_props and self.ui.doc_props.title
    local toc, idx = {}, nil
    if self.ui.toc then
        self.ui.toc:fillToc()
        toc = self.ui.toc.toc or {}
        local page = self.ui.getCurrentPage and self.ui:getCurrentPage()
        if page and #toc > 0 then
            idx = self.ui.toc:getTocIndexByPage(page)
        end
    end
    local p = position.detect(title, toc, idx, books)
    if p then p.source = "detected" end
    return p
end

function Companion:addToHighlightDialog()
    self.ui.highlight:addToHighlightDialog(BUTTON_ID, function(this)
        return {
            text = _("Crawler's Companion"),
            show_in_highlight_dialog_func = function()
                return self:currentPosition() ~= nil
            end,
            callback = function()
                -- As qrclipboard.koplugin does: a single-word hold becomes a selection first.
                if this.highlightFromHoldPos then this:highlightFromHoldPos() end
                local text = this.selected_text and this.selected_text.text
                this:onClose()
                self:lookup(text)
            end,
        }
    end)
end

function Companion:say(text)
    UIManager:show(InfoMessage:new{ text = text, monospace_font = true })
end

function Companion:lookup(text)
    text = util.cleanupSelectedText(text or "")
    local p = self:currentPosition()
    if not p then
        self:say(_("*** No position ***") .. "\n" ..
            _("This does not look like a Dungeon Crawler Carl book. If it is one, set a position under Crawler's Companion in the menu."))
        return
    end
    local index = self.store:load_index()
    local hits = gate.match(text, index.entries, p.frontier)
    local where = position.stamp(p.book, p.chapter)

    if #hits == 0 then
        -- The same reply whether the name is unknown or merely not yet reached.
        self:say(_("*** No record ***") .. "\n" ..
            string.format(_("Nothing on file for “%s” through %s."), text, where))
        return
    end
    if #hits == 1 then
        self:showEntry(hits[1], p)
        return
    end

    local dialog
    local buttons = {}
    for i, e in ipairs(hits) do
        buttons[i] = { {
            text = e.role ~= "" and (e.name .. " — " .. e.role) or e.name,
            callback = function()
                UIManager:close(dialog)
                self:showEntry(e, p)
            end,
        } }
    end
    dialog = ButtonDialog:new{
        title = string.format(_("“%s” could be:"), text),
        buttons = buttons,
    }
    UIManager:show(dialog)
end

function Companion:showEntry(entry, p)
    local file = self.store:entity(entry.id)
    UIManager:show(TextViewer:new{
        title = entry.name,
        text = gate.popup_text(entry, file, p.frontier, gate.LIMIT),
    })
end

-- Menu --------------------------------------------------------------------------------

function Companion:positionLine()
    local p = self:currentPosition()
    if not p then
        return _("*** No position *** Not a Dungeon Crawler Carl book, as far as I can tell.")
    end
    local line = p.title .. " · " .. position.stamp(p.book, p.chapter)
    if p.source == "override" then line = line .. _(" (set by you)") end
    return line
end

function Companion:addToMainMenu(menu_items)
    menu_items.crawlers_companion = {
        text = _("Crawler's Companion"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text_func = function() return self:positionLine() end,
                keep_menu_open = true,
                callback = function() self:say(self:positionLine()) end,
            },
            {
                text = _("Set position…"),
                keep_menu_open = true,
                callback = function() self:askPosition() end,
            },
            {
                text = _("Use detected position"),
                enabled_func = function()
                    return self.ui.doc_settings and self.ui.doc_settings:readSetting(SETTING) ~= nil
                end,
                keep_menu_open = true,
                callback = function()
                    self.ui.doc_settings:delSetting(SETTING)
                    self:say(self:positionLine())
                end,
            },
            {
                text = _("Look up a name…"),
                callback = function() self:askLookup() end,
            },
            {
                text = _("About"),
                keep_menu_open = true,
                callback = function() self:about() end,
            },
        },
    }
end

function Companion:askPosition()
    local index = self.store:load_index()
    local books = index and index.books or {}
    local current = self.ui.doc_settings and self.ui.doc_settings:readSetting(SETTING)
    local dialog
    dialog = InputDialog:new{
        title = _("Where are you?"),
        input = current or "",
        input_hint = _("7:12 or 7:end"),
        description = _("Book and chapter, as book:chapter. A bare book number means you have finished it. The chapter you name counts as read, so a name from a few pages ahead may already answer."),
        buttons = { {
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("Save"),
                is_enter_default = true,
                callback = function()
                    local raw = (dialog:getInputText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
                    local p = position.parse_override(raw, books)
                    if not p then
                        self:say(_("*** No such position ***") .. "\n" .. _("Try 7:12, or 7:end for a finished book."))
                        return
                    end
                    self.ui.doc_settings:saveSetting(SETTING, raw)
                    UIManager:close(dialog)
                    self:say(self:positionLine())
                end,
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Companion:askLookup()
    local dialog
    dialog = InputDialog:new{
        title = _("Look up a name"),
        input = "",
        input_hint = _("Donut"),
        buttons = { {
            {
                text = _("Cancel"),
                id = "close",
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = _("Look up"),
                is_enter_default = true,
                callback = function()
                    local text = dialog:getInputText()
                    UIManager:close(dialog)
                    self:lookup(text)
                end,
            },
        } },
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end

function Companion:about()
    local index = self.store:load_index()
    local stamp = index and index.generatedAt and index.generatedAt:sub(1, 10) or "?"
    local source = index and index.source or ""
    self:say(_("Crawler's Companion") .. "\n" ..
        _("A reader's companion to Dungeon Crawler Carl: every name, sealed past the chapter you are on.") .. "\n" ..
        source .. "\n" ..
        string.format(_("Data exported %s."), stamp))
end

return Companion
