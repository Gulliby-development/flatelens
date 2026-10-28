local Failure = {}
Failure.__index = Failure

function Failure.new(exit_code, message)
  return setmetatable({
    exit_code = exit_code,
    message = message,
  }, Failure)
end

function Failure.raise(exit_code, message)
  error(Failure.new(exit_code, message), 0)
end

function Failure.is(value)
  return type(value) == "table" and getmetatable(value) == Failure
end

return Failure
