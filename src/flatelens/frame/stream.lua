local Problem = require("flatelens.model.problem")
local Decoder = require("flatelens.inflate.decoder")
local Gzip = require("flatelens.frame.gzip")
local Zlib = require("flatelens.frame.zlib")

local Stream = {}

local function detect_format(data)
  if #data < 2 then
    return "raw"
  end

  local first = data:byte(1)
  local second = data:byte(2)
  if first == 0x1F and second == 0x8B then
    return "gzip"
  end

  if (first & 0x0F) == 8 and (first * 256 + second) % 31 == 0 then
    return "zlib"
  end

  return "raw"
end

local function call_container(report, callback)
  local ok, value, extra = pcall(callback)
  if ok then
    return value, extra
  end

  if not Problem.is(value) then
    error(value, 0)
  end

  report.problems[#report.problems + 1] = value
  report.fatal = true
  return nil
end

local function append_problems(report, problems)
  for _, problem in ipairs(problems) do
    report.problems[#report.problems + 1] = problem
  end
end

function Stream.analyse(data, requested)
  local format = requested == "auto" and detect_format(data) or requested
  local report = {
    format = format,
    header = {},
    blocks = {},
    out = "",
    problems = {},
    fatal = false,
    cstart = 0,
    cend = 0,
    check = format == "raw" and "none" or nil,
    trailing = 0,
  }

  local trailer
  if format == "gzip" then
    local header = call_container(report, function()
      return Gzip.header(data)
    end)
    if header == nil then
      return report
    end

    report.header = header.lines
    report.cstart = header.start
    trailer = Gzip.trailer
  elseif format == "zlib" then
    local header = call_container(report, function()
      return Zlib.header(data)
    end)
    if header == nil then
      return report
    end

    report.header = header.lines
    report.cstart = header.start
    trailer = Zlib.trailer
  end

  local blocks, out, end_bit, problem = Decoder.run(data, report.cstart * 8)
  report.blocks = blocks
  report.out = out
  report.cend = (end_bit + 7) // 8
  if problem ~= nil then
    report.problems[#report.problems + 1] = problem
    report.fatal = true
    return report
  end

  if trailer == nil then
    report.trailing = #data - report.cend
    if report.trailing > 0 then
      report.problems[#report.problems + 1] = Problem.trailing(report.cend * 8, report.trailing)
    end
    return report
  end

  local check, problems = call_container(report, function()
    return trailer(data, report.cend, report.out)
  end)
  if check == nil then
    return report
  end

  report.check = check
  append_problems(report, problems)

  local trailer_size = format == "gzip" and 8 or 4
  local trailer_end = report.cend + trailer_size
  report.trailing = #data - trailer_end
  if report.trailing > 0 then
    report.problems[#report.problems + 1] = Problem.trailing(trailer_end * 8, report.trailing)
  end

  return report
end

return Stream
