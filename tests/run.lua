-- The plugin's test runner. No busted, no luarocks: KOReader's own luajit (or any Lua 5.1+)
-- runs it from the repo root:
--
--     luajit tests/run.lua
--
-- Each tests/test_*.lua returns a table of name -> function. A test fails by raising.

local root = arg[0]:match("^(.*)/tests/run%.lua$") or "."
package.path = table.concat({
  root .. "/crawlerscompanion.koplugin/?.lua",
  root .. "/tests/?.lua",
  root .. "/tests/fixtures/?.lua",
  package.path,
}, ";")

local T = {}

function T.eq(got, want, msg)
  if got ~= want then
    error(string.format("%s\n  want: %s\n  got:  %s", msg or "values differ", tostring(want), tostring(got)), 2)
  end
end

function T.ok(cond, msg)
  if not cond then error(msg or "expected truthy", 2) end
end

function T.contains(haystack, needle, msg)
  if not tostring(haystack):find(needle, 1, true) then
    error(string.format("%s\n  expected to find: %s\n  in: %s", msg or "substring missing", needle, tostring(haystack)), 2)
  end
end

function T.lacks(haystack, needle, msg)
  if tostring(haystack):find(needle, 1, true) then
    error(string.format("%s\n  did not expect: %s\n  in: %s", msg or "substring present", needle, tostring(haystack)), 2)
  end
end

_G.T = T

local files = { "test_position", "test_gate", "test_store", "test_main" }
local only = arg[1]
local passed, failed = 0, 0
for _, file in ipairs(files) do
  if not only or only == file then
    local ok, suite = pcall(require, file)
    if not ok then
      failed = failed + 1
      print("FAIL " .. file .. " (could not load)\n  " .. tostring(suite))
    else
      local names = {}
      for name in pairs(suite) do names[#names + 1] = name end
      table.sort(names)
      for _, name in ipairs(names) do
        local good, err = pcall(suite[name])
        if good then
          passed = passed + 1
        else
          failed = failed + 1
          print("FAIL " .. file .. " / " .. name .. "\n  " .. tostring(err))
        end
      end
    end
  end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
