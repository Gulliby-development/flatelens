local Failure = require("flatelens.base.failure")

local Options = {}

local function syntax_error(message)
  Failure.raise(2, "flatelens: " .. message)
end

local function option_parts(argument)
  local equals = argument:find("=", 1, true)
  local spelling = equals and argument:sub(1, equals - 1) or argument
  local value = equals and argument:sub(equals + 1) or nil
  local has_value = equals ~= nil
  local name

  if spelling:sub(1, 2) == "--" then
    name = spelling:sub(3)
  else
    name = spelling
  end

  return spelling, name, value, has_value
end

function Options.parse(args, spec)
  local flags = {}
  local values = {}
  local operands = {}
  local options_ended = false
  local index = 1

  while index <= #args do
    local argument = args[index]

    if options_ended or argument == "-" or argument:sub(1, 1) ~= "-" then
      operands[#operands + 1] = argument
      index = index + 1
    elseif argument == "--" then
      options_ended = true
      index = index + 1
    else
      local spelling, name, value, has_value = option_parts(argument)
      local kind = spec[name]

      if kind == nil then
        syntax_error("unknown option " .. spelling)
      elseif kind == "flag" then
        if has_value then
          syntax_error("option " .. spelling .. " takes no value")
        end
        flags[name] = true
        index = index + 1
      elseif kind == "value" then
        if not has_value then
          index = index + 1
          if index > #args then
            syntax_error("option " .. spelling .. " needs a value")
          end
          value = args[index]
        end

        if value == "" then
          syntax_error("option " .. spelling .. " needs a non-empty value")
        end

        values[name] = value
        index = index + 1
      else
        syntax_error("unknown option " .. spelling)
      end
    end
  end

  return {
    flags = flags,
    values = values,
    operands = operands,
  }
end

function Options.number(parsed, name, default, minimum)
  local value = parsed.values[name]
  if value == nil then
    return default
  end

  local spelling = tostring(value)
  if type(value) ~= "string" or not value:match("^[0-9]+$") or #value > 9 then
    Failure.raise(2, "flatelens: invalid --" .. name .. " value: " .. spelling)
  end

  local number = tonumber(value)
  if number < minimum then
    Failure.raise(2, "flatelens: invalid --" .. name .. " value: " .. spelling)
  end

  return number
end

return Options
