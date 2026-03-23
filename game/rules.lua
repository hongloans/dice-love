--- Grid adjacency rules (port of isAdjacent in gameLogic.ts).

local constants = require("game.constants")

local M = {}

function M.isAdjacent(colony1Id, colony2Id, state)
  local colony1 = state.colonies[colony1Id]
  if not colony1 then
    return false
  end

  local WIDTH = constants.WIDTH
  local HEIGHT = constants.HEIGHT
  local grid = state.grid

  for _, cellIdx in ipairs(colony1.cells) do
    local x = cellIdx % WIDTH
    local y = math.floor(cellIdx / WIDTH)

    local neighbors = {}
    if y > 0 then table.insert(neighbors, cellIdx - WIDTH) end
    if x < WIDTH - 1 then table.insert(neighbors, cellIdx + 1) end
    if y < HEIGHT - 1 then table.insert(neighbors, cellIdx + WIDTH) end
    if x > 0 then table.insert(neighbors, cellIdx - 1) end

    for _, n in ipairs(neighbors) do
      if grid[n] == colony2Id then
        return true
      end
    end
  end

  return false
end

return M
