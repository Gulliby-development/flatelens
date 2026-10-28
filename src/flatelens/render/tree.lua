-- Renders a dynamic block's transmitted lengths and supplied code statistics.
local Text = require("flatelens.base.text")

local Tree = {}

local function render_runs(lengths)
  local runs = {}
  local run_start
  local run_length

  local function finish_run(last_symbol)
    if run_start == last_symbol then
      runs[#runs + 1] = string.format("%d:%d", run_start, run_length)
    else
      runs[#runs + 1] = string.format("%d-%d:%d", run_start, last_symbol, run_length)
    end
    run_start = nil
  end

  for index, length in ipairs(lengths) do
    local symbol = index - 1
    if length == 0 then
      if run_start ~= nil then
        finish_run(symbol - 1)
      end
    elseif run_start == nil then
      run_start = symbol
      run_length = length
    elseif length ~= run_length then
      finish_run(symbol - 1)
      run_start = symbol
      run_length = length
    end
  end

  if run_start ~= nil then
    finish_run(#lengths - 1)
  end

  if #runs == 0 then
    return "none"
  end
  return table.concat(runs, " ")
end

local function render_code_summary(name, info)
  return string.format(
    "%s code: %s, max length %d, %s",
    name,
    Text.plural(info.used, "symbol"),
    info.max,
    info.status
  )
end

-- Returns six fresh lines for a dynamic block, preserving its original block index.
function Tree.render(block, index)
  local transmitted = {}
  for _, pair in ipairs(block.cl_lengths) do
    transmitted[#transmitted + 1] = string.format("%d:%d", pair[1], pair[2])
  end

  return {
    string.format(
      "block %d: dynamic, HLIT %d, HDIST %d, HCLEN %d",
      index,
      block.hlit,
      block.hdist,
      block.hclen
    ),
    "code length code lengths: " .. table.concat(transmitted, " "),
    "literal/length lengths: " .. render_runs(block.lit_lengths),
    "distance lengths: " .. render_runs(block.dist_lengths),
    render_code_summary("literal/length", block.lit_info),
    render_code_summary("distance", block.dist_info),
  }
end

return Tree
