--- Grid and battle visualization (port of GameBoard.tsx canvas drawing).

local constants = require("game.constants")
local font = require("utils.font")

local M = {}

function M.countColoniesPerPlayer(gameState)
  local counts = {}
  for _, p in ipairs(gameState.players) do
    counts[p.id] = 0
  end
  for _, c in pairs(gameState.colonies) do
    if c.ownerId >= 0 and counts[c.ownerId] then
      counts[c.ownerId] = counts[c.ownerId] + 1
    end
  end
  return counts
end

local function isChokeVoid(g)
  return g == 0
end

--- Colony vs colony / colony vs empty (`false`); no lines along choke (`0`) so moat & spine stay visually flat.
function M.drawColonyBoundaries(grid, ox, oy, cs)
  local WIDTH = constants.WIDTH
  local HEIGHT = constants.HEIGHT
  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.setLineWidth(1.5)
  for i = 0, constants.TOTAL_CELLS - 1 do
    local id = grid[i]
    local xi = i % WIDTH
    local yi = math.floor(i / WIDTH)
    local x = xi * cs + ox
    local y = yi * cs + oy
    if xi < WIDTH - 1 then
      local nid = grid[i + 1]
      if not isChokeVoid(id) and not isChokeVoid(nid) and id ~= nid then
        love.graphics.line(x + cs, y, x + cs, y + cs)
      end
    end
    if yi < HEIGHT - 1 then
      local nid = grid[i + WIDTH]
      if not isChokeVoid(id) and not isChokeVoid(nid) and id ~= nid then
        love.graphics.line(x, y + cs, x + cs, y + cs)
      end
    end
  end
end

--- Full rectangular grid (every cell edge), subtle — only when toggled on.
function M.drawUniformGrid(ox, oy, cs)
  local WIDTH = constants.WIDTH
  local HEIGHT = constants.HEIGHT
  love.graphics.setColor(1, 1, 1, 0.12)
  love.graphics.setLineWidth(1)
  local x1 = ox + WIDTH * cs
  local y1 = oy + HEIGHT * cs
  for k = 1, WIDTH - 1 do
    local lx = ox + k * cs
    love.graphics.line(lx, oy, lx, y1)
  end
  for k = 1, HEIGHT - 1 do
    local ly = oy + k * cs
    love.graphics.line(ox, ly, x1, ly)
  end
end

--- layout: { x, y, cellSize, gridPixelW, gridPixelH }
--- opts.showGridLines: when true, faint line on every cell edge. When false, tiles stay flush (no per-cell grid).
function M.draw(gameState, layout, opts)
  opts = opts or {}
  local showGridLines = opts.showGridLines == true

  local WIDTH = constants.WIDTH
  local HEIGHT = constants.HEIGHT
  local cs = layout.cellSize
  local ox, oy = layout.x, layout.y
  local grid = gameState.grid

  for i = 0, constants.TOTAL_CELLS - 1 do
    local g = grid[i]
    local x = (i % WIDTH) * cs + ox
    local y = math.floor(i / WIDTH) * cs + oy

    if type(g) == "number" and g >= 1 then
      local colonyId = g
      local col = gameState.colonies[colonyId]
      local pid = col and col.ownerId
      local player = pid and gameState.players[pid + 1]

      if player then
        love.graphics.setColor(player.color[1], player.color[2], player.color[3], 1)
      else
        love.graphics.setColor(0.2, 0.255, 0.333, 1)
      end
      love.graphics.rectangle("fill", x, y, cs, cs)

      if col and col.cells[1] == i then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(font.get(9))
        local f = love.graphics.getFont()
        local text = tostring(col.diceCount)
        local tw = f:getWidth(text)
        local th = f:getHeight()
        love.graphics.print(text, x + (cs - tw) / 2, y + (cs - th) / 2)
      end
    else
      -- false (empty) and 0 (impassable): same look; rules differ only in logic.
      love.graphics.setColor(0.118, 0.161, 0.231, 1)
      love.graphics.rectangle("fill", x, y, cs, cs)
    end
  end

  if showGridLines then
    M.drawUniformGrid(ox, oy, cs)
  end
  M.drawColonyBoundaries(grid, ox, oy, cs)

  for i = 0, constants.TOTAL_CELLS - 1 do
    local colonyId = grid[i]
    if type(colonyId) ~= "number" or colonyId < 1 then
      -- skip
    else
      local x = (i % WIDTH) * cs + ox
      local y = math.floor(i / WIDTH) * cs + oy

      if gameState.selectedColonyId == colonyId then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, cs - 1, cs - 1)
      end

      if gameState.phase == "battle-result" and gameState.battleResult then
        local br = gameState.battleResult
        if colonyId == br.attackerId then
          love.graphics.setColor(0.984, 0.749, 0.141, 1)
          love.graphics.setLineWidth(2)
          love.graphics.rectangle("line", x, y, cs, cs)
        elseif colonyId == br.defenderId then
          love.graphics.setColor(0.973, 0.443, 0.443, 1)
          love.graphics.setLineWidth(2)
          love.graphics.rectangle("line", x, y, cs, cs)
        end
      end
    end
  end

  love.graphics.setLineWidth(1)

  if gameState.phase == "battle-result" and gameState.battleResult then
    local br = gameState.battleResult
    local ac = gameState.colonies[br.attackerId]
    local dc = gameState.colonies[br.defenderId]
    if ac and dc then
      local function drawRollBox(cellIdx, rolls, r, g, b)
        local rx = (cellIdx % WIDTH) * cs + ox
        local ry = math.floor(cellIdx / WIDTH) * cs + oy
        local sum = 0
        for _, v in ipairs(rolls) do
          sum = sum + v
        end
        love.graphics.setColor(0.059, 0.09, 0.165, 0.8)
        love.graphics.rectangle("fill", rx - 20, ry - 30, 50, 25)
        love.graphics.setColor(r, g, b, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", rx - 20, ry - 30, 50, 25)
        love.graphics.setFont(font.get(12))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(tostring(sum), rx + 5, ry - 17 - 6)
      end
      drawRollBox(ac.cells[1], br.attackerRolls, 0.984, 0.749, 0.141)
      drawRollBox(dc.cells[1], br.defenderRolls, 0.973, 0.443, 0.443)
    end
  end

  love.graphics.setColor(1, 1, 1, 1)
end

return M
