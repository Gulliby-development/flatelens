local Block = {}

function Block.new(fields)
  local block = {
    lit = 0,
    match = 0,
    out = 0,
    final = false,
  }

  for key, value in pairs(fields or {}) do
    block[key] = value
  end

  return block
end

return Block
