--- Lodash-style helpers using Love2D RNG (love.math.random).
--- Parity with lodash.shuffle / _.sample for gameplay distribution.

local M = {}

--- Fisher–Yates shuffle of array indices 1..#t (in place).
function M.shuffle(t)
  for i = #t, 2, -1 do
    local j = love.math.random(i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

--- Uniform random element from non-empty array t (1-based).
function M.sample(t)
  return t[love.math.random(#t)]
end

return M
