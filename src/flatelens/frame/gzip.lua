local Problem = require("flatelens.model.problem")
local Text = require("flatelens.base.text")
local Checksum = require("flatelens.sums.checksum")

local Gzip = {}

local OS_NAMES = {
  "fat",
  "amiga",
  "vms",
  "unix",
  "vm/cms",
  "atari tos",
  "hpfs",
  "macintosh",
  "z-system",
  "cp/m",
  "tops-20",
  "ntfs",
  "qdos",
  "acorn riscos",
}

local function truncated(data)
  error(Problem.truncated(#data), 0)
end

local function find_field(data, offset)
  local terminator = data:find("\0", offset + 1, true)
  if not terminator then
    truncated(data)
  end

  return data:sub(offset + 1, terminator - 1), terminator
end

function Gzip.header(data)
  if #data < 2 then
    truncated(data)
  end

  if data:byte(1) ~= 0x1F or data:byte(2) ~= 0x8B then
    error(Problem.not_gzip(), 0)
  end

  if #data < 10 then
    truncated(data)
  end

  local method = data:byte(3)
  if method ~= 8 then
    error(Problem.bad_method(method), 0)
  end

  local flags = data:byte(4)
  local reserved = flags & 0xE0
  if reserved ~= 0 then
    error(Problem.reserved_flags(reserved), 0)
  end

  local mtime = string.unpack("<I4", data, 5)
  local os = data:byte(10)
  local cursor = 10
  local extra_length
  local name
  local comment
  local has_header_crc = (flags & 2) ~= 0

  if (flags & 4) ~= 0 then
    if #data - cursor < 2 then
      truncated(data)
    end

    extra_length = string.unpack("<I2", data, cursor + 1)
    cursor = cursor + 2
    if #data - cursor < extra_length then
      truncated(data)
    end
    cursor = cursor + extra_length
  end

  if (flags & 8) ~= 0 then
    name, cursor = find_field(data, cursor)
  end

  if (flags & 16) ~= 0 then
    comment, cursor = find_field(data, cursor)
  end

  if has_header_crc then
    if #data - cursor < 2 then
      truncated(data)
    end

    local stored = string.unpack("<I2", data, cursor + 1)
    local computed = Checksum.crc32(data:sub(1, cursor)) & 0xFFFF
    if stored ~= computed then
      error(Problem.header_crc(stored, computed), 0)
    end
    cursor = cursor + 2
  end

  local os_name = OS_NAMES[os + 1]
  if os_name == nil then
    os_name = os == 255 and "unknown" or string.format("other (%d)", os)
  end

  local lines = {
    string.format("mtime: %d", mtime),
    "os: " .. os_name,
  }
  if name ~= nil then
    lines[#lines + 1] = 'name: "' .. Text.shown(name) .. '"'
  end
  if comment ~= nil then
    lines[#lines + 1] = 'comment: "' .. Text.shown(comment) .. '"'
  end
  if extra_length ~= nil then
    lines[#lines + 1] = "extra: " .. Text.plural(extra_length, "byte")
  end
  if has_header_crc then
    lines[#lines + 1] = "header crc: ok"
  end

  return { start = cursor, lines = lines }
end

function Gzip.trailer(data, pos, out)
  if #data - pos < 8 then
    truncated(data)
  end

  local stored_crc = string.unpack("<I4", data, pos + 1)
  local stored_size = string.unpack("<I4", data, pos + 5)
  local computed_crc = Checksum.crc32(out)
  local computed_size = #out & 0xFFFFFFFF
  local problems = {}
  local crc_status = "ok"
  local size_status = "ok"

  if stored_crc ~= computed_crc then
    crc_status = "mismatch"
    problems[#problems + 1] = Problem.checksum(pos * 8, "CRC-32", stored_crc, computed_crc)
  end
  if stored_size ~= computed_size then
    size_status = "mismatch"
    problems[#problems + 1] = Problem.size(pos * 8, stored_size, computed_size)
  end

  return string.format("crc32 %s, size %s", crc_status, size_status), problems
end

return Gzip
