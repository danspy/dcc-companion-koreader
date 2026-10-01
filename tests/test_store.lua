local Store = require("cc_store")

local root = arg[0]:match("^(.*)/tests/run%.lua$") or "."
local FIXTURE = root .. "/tests/fixtures/data"
local REAL = root .. "/crawlerscompanion.koplugin/data"

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() end
  return f ~= nil
end

local S = {}

function S.the_fixture_index_loads_once()
  local store = Store.new(FIXTURE)
  local index = store:load_index()
  T.ok(index, "index loads")
  T.eq(#index.entries, 4)
  T.eq(#index.books, 8)
  T.eq(index.books[7].title, "This Inevitable Ruin")
  T.eq(store:load_index(), index, "the same table comes back")
end

function S.an_entity_file_loads_and_the_last_is_kept()
  local store = Store.new(FIXTURE)
  local carl = store:entity("carl")
  T.ok(carl, "carl.json loads")
  T.eq(#carl.beats, 4)
  T.eq(carl.beats[1].key, 1001)
  T.eq(store:entity("carl"), carl, "cached")
  T.eq(store:entity("nobody"), nil, "a missing file is nil, not an error")
end

function S.a_missing_index_says_why()
  local store = Store.new(root .. "/tests/fixtures/nowhere")
  local index, err = store:load_index()
  T.eq(index, nil)
  T.ok(err and err ~= "", "a reason is given")
end

function S.the_real_export_parses_under_this_decoder()
  if not exists(REAL .. "/index.json") then return end -- not synced yet; nothing to check
  local store = Store.new(REAL)
  local index = store:load_index()
  T.ok(index, "real index loads")
  T.ok(#index.entries > 300, "the whole cast is there")
  local carl = store:entity("carl")
  T.ok(carl and #carl.beats > 100, "carl's file loads")
  for _, e in ipairs(index.entries) do
    T.ok(type(e.revealedAt) == "number", e.id .. " revealedAt is a number")
    T.ok(type(e.aka) == "table", e.id .. " aka is a list")
    T.ok(type(e.taglines) == "table", e.id .. " taglines is a list")
  end
end

return S
