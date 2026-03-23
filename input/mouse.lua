--- Pixel → grid cell index (0-based), matching GameBoard canvas mapping.

local constants = require("game.constants")

local M = {}

function M.pixelToCell(mx, my, layout)
  local g = layout.grid
  if mx < g.x or my < g.y or mx >= g.x + g.gridPixelW or my >= g.y + g.gridPixelH then
    return nil
  end
  local cx = math.floor((mx - g.x) / g.cellSize)
  local cy = math.floor((my - g.y) / g.cellSize)
  if cx < 0 or cx >= constants.WIDTH or cy < 0 or cy >= constants.HEIGHT then
    return nil
  end
  return cy * constants.WIDTH + cx
end

return M
