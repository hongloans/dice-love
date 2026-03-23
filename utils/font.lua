--- Cached fonts for stable layout across frames.

local cache = {}

local M = {}

function M.get(size)
  if not cache[size] then
    cache[size] = love.graphics.newFont(size)
  end
  return cache[size]
end

return M
