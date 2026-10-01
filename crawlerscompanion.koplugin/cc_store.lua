--[[--
The exported data on disk: `index.json`, read once, and `entities/<id>.json`, read on a hit.

The decoder is the vendored cc_json (rxi/json.lua, MIT) rather than KOReader's, so the
plugin's data path is the same under the test runner and on the device.
--]]

local json = require("cc_json")

local M = {}
M.__index = M

local function read(path)
  local f, err = io.open(path, "rb")
  if not f then return nil, err end
  local s = f:read("*a")
  f:close()
  return s
end

local function parse(path)
  local s, err = read(path)
  if not s then return nil, err end
  local ok, data = pcall(json.decode, s)
  if not ok then return nil, tostring(data) end
  return data
end

function M.new(dir)
  return setmetatable({ dir = dir, index = nil, last_id = nil, last = nil }, M)
end

-- The index, or nil and a reason. Cached for the life of the store.
function M:load_index()
  if self.index then return self.index end
  local data, err = parse(self.dir .. "/index.json")
  if not data then return nil, err end
  self.index = data
  return data
end

-- One entry's file. Only the last one read is kept; a reader looks up one name at a time.
function M:entity(id)
  if self.last_id == id then return self.last end
  local data = parse(self.dir .. "/entities/" .. id .. ".json")
  self.last_id, self.last = id, data
  return data
end

return M
