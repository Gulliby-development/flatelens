local function read_readme()
  local handle = assert(io.open("README.md", "r"))
  local contents = handle:read("*a")
  handle:close()
  return contents
end

describe("README documentation", function()
  it("names all six commands", function()
    local contents = read_readme()
    local commands = { "info", "blocks", "tree", "dump", "check", "codes" }

    for _, command in ipairs(commands) do
      assert.is_true(string.find(contents, command, 1, true) ~= nil, command)
    end
  end)

  it("includes the mandated hello info example exactly", function()
    local contents = read_readme()
    local expected = [[$ flatelens info --hex hello.hex
format: zlib
window: 32768 bytes
level: default
blocks: 1 (1 fixed)
compressed: 7 bytes
uncompressed: 5 bytes
ratio: 140.0%
check: adler32 ok
]]

    assert.is_true(string.find(contents, expected, 1, true) ~= nil)
  end)

  it("includes the mandated RFC codes example exactly", function()
    local contents = read_readme()
    local expected = [[$ flatelens codes 3 3 3 3 3 2 4 4
0: 3 010
1: 3 011
2: 3 100
3: 3 101
4: 3 110
5: 2 00
6: 4 1110
7: 4 1111
status: complete (16/16)
]]

    assert.is_true(string.find(contents, expected, 1, true) ~= nil)
  end)

  it("includes the mandated check example exactly", function()
    local contents = read_readme()
    local expected = [[$ flatelens check --hex hello.hex bad.hex
hello.hex: ok
bad.hex: FL021 Adler-32 mismatch: stored 0x062c0214, computed 0x062c0215 at 9.0
checked 2 files, 1 problem
]]

    assert.is_true(string.find(contents, expected, 1, true) ~= nil)
  end)
end)
