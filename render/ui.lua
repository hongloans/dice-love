--- Menus, HUD, panels (structure inspired by App.tsx / StartScreen / LoadingScreen).

local constants = require("game.constants")
local font = require("utils.font")
local mouse = require("input.mouse")
local boardDraw = require("render.board")

local M = {}

--- Deterministic tint per colony id for loading preview (no player ownership yet).
local function previewColonyRgb(id)
  local a = id * 1103515245 + 12345
  local r = (a % 200) / 200 * 0.62 + 0.18
  local g = (math.floor(a / 256) % 200) / 200 * 0.62 + 0.18
  local b = (math.floor(a / 65536) % 200) / 200 * 0.62 + 0.18
  return r, g, b
end

local function drawSectorPreview(grid, ox, oy, cs, showGridLines)
  local WIDTH = constants.WIDTH
  for i = 0, constants.TOTAL_CELLS - 1 do
    local cid = grid[i]
    local x = (i % WIDTH) * cs + ox
    local y = math.floor(i / WIDTH) * cs + oy
    if type(cid) == "number" and cid >= 1 then
      local pr, pg, pb = previewColonyRgb(cid)
      love.graphics.setColor(pr, pg, pb, 1)
    else
      love.graphics.setColor(0.118, 0.161, 0.231, 1)
    end
    love.graphics.rectangle("fill", x, y, cs, cs)
  end
  if showGridLines then
    boardDraw.drawUniformGrid(ox, oy, cs)
  end
  boardDraw.drawColonyBoundaries(grid, ox, oy, cs)
end

local function centeredPrint(text, cx, y)
  local f = love.graphics.getFont()
  local tw = f:getWidth(text)
  love.graphics.print(text, cx - tw / 2, y)
end

function M.computeLayout(windowW, windowH, gameState)
  local headerH = 72
  local battleH = 96
  local controlsH = 88
  local footerH = gameState and 100 or 0
  local margin = 24

  local availW = windowW - margin * 2
  local availH = windowH - headerH - battleH - controlsH - footerH - margin * 2

  local cellByW = availW / constants.WIDTH
  local cellByH = availH / constants.HEIGHT
  local cellSize = math.floor(math.min(cellByW, cellByH, constants.BASE_CELL_SIZE * 2) * 10) / 10
  cellSize = math.max(4, cellSize)

  local gridPixelW = cellSize * constants.WIDTH
  local gridPixelH = cellSize * constants.HEIGHT

  local gx = (windowW - gridPixelW) / 2
  local gy = headerH + battleH + margin

  return {
    headerH = headerH,
    battleH = battleH,
    controlsY = gy + gridPixelH + 16,
    footerY = gy + gridPixelH + 16 + controlsH,
    grid = { x = gx, y = gy, cellSize = cellSize, gridPixelW = gridPixelW, gridPixelH = gridPixelH },
    margin = margin,
  }
end

function M.drawHeader(windowW)
  love.graphics.setColor(0.06, 0.09, 0.16, 0.85)
  love.graphics.rectangle("fill", 0, 0, windowW, 72)
  love.graphics.setColor(0.95, 0.95, 1, 0.9)
  love.graphics.setFont(font.get(22))
  centeredPrint("DICE LOVE", windowW / 2, 18)
  love.graphics.setFont(font.get(10))
  love.graphics.setColor(0.5, 0.55, 0.65, 1)
  centeredPrint("Battle simulation (Dice War port)", windowW / 2, 46)
  love.graphics.setColor(1, 1, 1, 1)
end

function M.drawBattlePanel(gameState, layout, windowW)
  local y = 72
  local h = layout.battleH - 8
  love.graphics.setColor(0.08, 0.1, 0.15, 0.9)
  love.graphics.rectangle("fill", layout.margin, y, windowW - layout.margin * 2, h)

  if gameState.battleResult then
    local br = gameState.battleResult
    local as = 0
    for _, v in ipairs(br.attackerRolls) do
      as = as + v
    end
    local ds = 0
    for _, v in ipairs(br.defenderRolls) do
      ds = ds + v
    end
    love.graphics.setFont(font.get(14))
    love.graphics.setColor(0.6, 0.65, 0.75, 1)
    love.graphics.print("ATTACKER", layout.margin + 40, y + 16)
    love.graphics.print("DEFENDER", windowW - 200, y + 16)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font.get(28))
    love.graphics.print(tostring(as), layout.margin + 80, y + 36)
    love.graphics.print(tostring(ds), windowW - 160, y + 36)
    love.graphics.setFont(font.get(18))
    love.graphics.setColor(0.55, 0.6, 1, 1)
    centeredPrint("VS", windowW / 2, y + 40)
    local label = br.winnerId == gameState.currentPlayerIndex and "VICTORY" or "DEFEAT"
    love.graphics.setColor(0.6, 0.65, 1, 1)
    love.graphics.setFont(font.get(12))
    love.graphics.print(label, windowW / 2 - 40, y + 56)
  else
    love.graphics.setColor(0.25, 0.28, 0.35, 1)
    love.graphics.setFont(font.get(10))
    centeredPrint("Awaiting Engagement", windowW / 2, y + h / 2 - 6)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

function M.drawPlayerBar(gameState, layout, windowW, counts)
  local y = layout.footerY
  local pad = 8
  local n = #gameState.players
  local boxW = math.min(160, (windowW - layout.margin * 2 - pad * (n - 1)) / n)

  for idx, p in ipairs(gameState.players) do
    local x = layout.margin + (idx - 1) * (boxW + pad)
    local active = gameState.currentPlayerIndex == idx - 1
    if active then
      love.graphics.setColor(0.35, 0.38, 0.65, 0.5)
    else
      love.graphics.setColor(0.12, 0.14, 0.18, 0.45)
    end
    love.graphics.rectangle("fill", x, y, boxW, 56, 8, 8)
    love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.isEliminated and 0.35 or 1)
    love.graphics.circle("fill", x + 16, y + 28, 6)
    love.graphics.setColor(1, 1, 1, p.isEliminated and 0.4 or 0.95)
    love.graphics.setFont(font.get(11))
    local tag = string.format("P%d %s", p.id + 1, p.isBot and "BOT" or "YOU")
    love.graphics.print(tag, x + 28, y + 12)
    love.graphics.print(tostring(counts[p.id] or 0), x + boxW - 28, y + 22)
  end
end

function M.drawControls(layout, windowW, endTurnEnabled, speedTier, showGridLines)
  speedTier = speedTier or 3
  local y = layout.controlsY
  local bw, bh = 220, 52
  local bx = windowW / 2 - bw - 12
  local rx = windowW / 2 + 12
  local gap = 12
  local sx = rx + bh + gap
  local gx = sx + bh + gap
  love.graphics.setColor(endTurnEnabled and 0.35 or 0.15, endTurnEnabled and 0.38 or 0.15, 0.55, endTurnEnabled and 1 or 0.45)
  love.graphics.rectangle("fill", bx, y, bw, bh, 10, 10)
  love.graphics.setColor(1, 1, 1, endTurnEnabled and 1 or 0.45)
  love.graphics.setFont(font.get(16))
  centeredPrint("END TURN", bx + bw / 2, y + 16)

  love.graphics.setColor(0.2, 0.22, 0.28, 1)
  love.graphics.rectangle("fill", rx, y, bh, bh, 10, 10)
  love.graphics.setColor(0.75, 0.78, 0.85, 1)
  love.graphics.setFont(font.get(22))
  -- Default bitmap font often omits U+21BB (↻); use ASCII so the label always draws.
  local fnt = love.graphics.getFont()
  local restartLabel = "↻"
  local ok_hg, hasGlyph = pcall(function()
    return fnt:hasGlyphs(restartLabel)
  end)
  if ok_hg and hasGlyph == false then
    restartLabel = "R"
  end
  local th = fnt:getHeight()
  local printY = y + (bh - th) / 2
  centeredPrint(restartLabel, rx + bh / 2, printY)

  -- Fast-forward / speed: tier 1 black, 2 white, 3 yellow, 4 red, 5 cyan (instant battle)
  local bgR, bgG, bgB, symR, symG, symB
  if speedTier == 1 then
    bgR, bgG, bgB = 0.88, 0.88, 0.91
    symR, symG, symB = 0, 0, 0
  elseif speedTier == 2 then
    bgR, bgG, bgB = 0.2, 0.22, 0.28
    symR, symG, symB = 1, 1, 1
  elseif speedTier == 3 then
    bgR, bgG, bgB = 0.12, 0.14, 0.18
    symR, symG, symB = 1, 0.9, 0.2
  elseif speedTier == 4 then
    bgR, bgG, bgB = 0.16, 0.08, 0.08
    symR, symG, symB = 1, 0.35, 0.35
  else
    bgR, bgG, bgB = 0.06, 0.14, 0.16
    symR, symG, symB = 0.35, 0.95, 1
  end
  love.graphics.setColor(bgR, bgG, bgB, 1)
  love.graphics.rectangle("fill", sx, y, bh, bh, 10, 10)
  love.graphics.setFont(font.get(20))
  local ff = love.graphics.getFont()
  local ffH = ff:getHeight()
  love.graphics.setColor(symR, symG, symB, 1)
  centeredPrint(">>", sx + bh / 2, y + (bh - ffH) / 2)

  -- Cell grid overlay toggle (#): off = seamless tiles; on = faint per-cell grid
  if showGridLines then
    love.graphics.setColor(0.25, 0.55, 0.75, 1)
  else
    love.graphics.setColor(0.22, 0.24, 0.3, 1)
  end
  love.graphics.rectangle("fill", gx, y, bh, bh, 10, 10)
  love.graphics.setFont(font.get(18))
  local gf = love.graphics.getFont()
  local gfh = gf:getHeight()
  love.graphics.setColor(showGridLines and 0.85 or 0.55, showGridLines and 0.95 or 0.6, 1, 1)
  centeredPrint("#", gx + bh / 2, y + (bh - gfh) / 2)
  love.graphics.setColor(1, 1, 1, 1)
end

function M.drawMenu(windowW, windowH, selectedPlayers, allBotsMode)
  love.graphics.setColor(0.07, 0.09, 0.14, 1)
  love.graphics.rectangle("fill", 0, 0, windowW, windowH)
  love.graphics.setColor(0.55, 0.6, 1, 1)
  love.graphics.setFont(font.get(44))
  centeredPrint("DICE LOVE", windowW / 2, windowH * 0.18)
  love.graphics.setColor(0.55, 0.6, 0.7, 1)
  love.graphics.setFont(font.get(14))
  centeredPrint("Conquer the grid, one roll at a time.", windowW / 2, windowH * 0.18 + 52)

  love.graphics.setColor(0.15, 0.18, 0.24, 1)
  local panelW, panelH = 420, 380
  love.graphics.rectangle("fill", (windowW - panelW) / 2, windowH * 0.32, panelW, panelH, 16, 16)

  love.graphics.setColor(0.85, 0.88, 0.95, 1)
  love.graphics.setFont(font.get(12))
  love.graphics.print("NUMBER OF PLAYERS", windowW / 2 - 140, windowH * 0.32 + 28)

  for i, n in ipairs({ 2, 3, 4, 5, 6, 7, 8 }) do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local bx = windowW / 2 - 140 + col * 68
    local by = windowH * 0.32 + 56 + row * 48
    local sel = selectedPlayers == n
    love.graphics.setColor(sel and 0.35 or 0.22, sel and 0.4 or 0.25, sel and 0.65 or 0.3, 1)
    love.graphics.rectangle("fill", bx, by, 60, 40, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font.get(16))
    centeredPrint(tostring(n), bx + 30, by + 10)
  end

  local modeY = windowH * 0.32 + 162
  love.graphics.setColor(0.85, 0.88, 0.95, 1)
  love.graphics.setFont(font.get(12))
  love.graphics.print("PLAY MODE", windowW / 2 - 140, modeY - 20)
  local modeW = 136
  local m1x = windowW / 2 - 140
  local m2x = windowW / 2 + 4
  local isHuman = not allBotsMode
  love.graphics.setColor(isHuman and 0.28 or 0.2, isHuman and 0.52 or 0.24, isHuman and 0.65 or 0.28, 1)
  love.graphics.rectangle("fill", m1x, modeY, modeW, 40, 8, 8)
  love.graphics.setColor((not isHuman) and 0.28 or 0.2, (not isHuman) and 0.52 or 0.24, (not isHuman) and 0.65 or 0.28, 1)
  love.graphics.rectangle("fill", m2x, modeY, modeW, 40, 8, 8)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(font.get(12))
  centeredPrint("RED PLAYER", m1x + modeW / 2, modeY + 12)
  centeredPrint("ALL BOTS", m2x + modeW / 2, modeY + 12)

  local startY = windowH * 0.32 + 214
  love.graphics.setColor(0.35, 0.38, 0.65, 1)
  love.graphics.rectangle("fill", windowW / 2 - 140, startY, 280, 56, 12, 12)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(font.get(18))
  centeredPrint("START GAME", windowW / 2, startY + 16)

  love.graphics.setFont(font.get(11))
  love.graphics.setColor(0.45, 0.5, 0.58, 1)
  local ty = startY + 80
  local modeText = allBotsMode and "• All players are bots (autoplay)." or "• You are P1 (Red). Others are bots."
  love.graphics.print(modeText, windowW / 2 - 160, ty)
  love.graphics.print("• Each colony is 8 adjacent cells.", windowW / 2 - 160, ty + 18)
  love.graphics.print("• Max 20 dice per colony.", windowW / 2 - 160, ty + 36)
  love.graphics.print("• Win by eliminating all opponents.", windowW / 2 - 160, ty + 54)
end

function M.drawLoading(windowW, windowH, logs, progress, loadingGrid, loadingColonyCount, showGridLines)
  loadingColonyCount = loadingColonyCount or 0
  love.graphics.setColor(0.04, 0.06, 0.1, 1)
  love.graphics.rectangle("fill", 0, 0, windowW, windowH)
  love.graphics.setColor(0.9, 0.92, 1, 1)
  love.graphics.setFont(font.get(22))
  centeredPrint("INITIALIZING SECTOR", windowW / 2, 40)
  love.graphics.setFont(font.get(11))
  love.graphics.setColor(0.45, 0.5, 0.58, 1)
  centeredPrint("Frontier expansion — live preview", windowW / 2, 72)

  love.graphics.setColor(0.55, 0.6, 1, 1)
  love.graphics.print(string.format("Sectors: %d / %d", loadingColonyCount, constants.MAX_COLONIES), 48, 98)
  love.graphics.print(string.format("Expansion: %.0f%%", progress), windowW - 220, 98)
  love.graphics.setColor(0.12, 0.14, 0.18, 1)
  love.graphics.rectangle("fill", 48, 122, windowW - 96, 8, 4, 4)
  love.graphics.setColor(0.35, 0.4, 0.85, 1)
  love.graphics.rectangle("fill", 48, 122, (windowW - 96) * (math.min(100, progress) / 100), 8, 4, 4)

  local marginX = 48
  local previewTop = 144
  local previewH = math.min(280, math.max(120, windowH * 0.30))
  local previewW = windowW - 96
  love.graphics.setColor(0.06, 0.08, 0.11, 1)
  love.graphics.rectangle("fill", marginX, previewTop, previewW, previewH, 8, 8)
  love.graphics.setColor(0.2, 0.25, 0.35, 0.6)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", marginX, previewTop, previewW, previewH, 8, 8)

  if loadingGrid then
    local cellW = previewW / constants.WIDTH
    local cellH = previewH / constants.HEIGHT
    local cs = math.min(cellW, cellH)
    local drawW = cs * constants.WIDTH
    local drawH = cs * constants.HEIGHT
    local px = marginX + (previewW - drawW) / 2
    local py = previewTop + (previewH - drawH) / 2
    drawSectorPreview(loadingGrid, px, py, cs, showGridLines == true)
  else
    love.graphics.setColor(0.45, 0.5, 0.58, 1)
    love.graphics.setFont(font.get(11))
    centeredPrint("Preparing grid…", windowW / 2, previewTop + previewH / 2 - 6)
  end

  local logTop = previewTop + previewH + 14
  local logH = math.max(80, windowH - logTop - 24)
  love.graphics.setColor(0.08, 0.1, 0.14, 0.95)
  love.graphics.rectangle("fill", 48, logTop, windowW - 96, logH, 8, 8)
  love.graphics.setFont(font.get(11))
  local ly = logTop + 14
  local maxLines = math.floor((logH - 20) / 15)
  local start = math.max(1, #logs - maxLines + 1)
  for i = start, #logs do
    local line = logs[i]
    local r, g, b = 0.75, 0.78, 0.85
    if line:find("CRITICAL", 1, true) then
      r, g, b = 0.95, 0.35, 0.35
    elseif line:find("WARN", 1, true) then
      r, g, b = 0.95, 0.85, 0.35
    elseif line:find("SUCCESS", 1, true) then
      r, g, b = 0.35, 0.85, 0.65
    elseif line:find("SYSTEM", 1, true) then
      r, g, b = 0.45, 0.55, 0.95
    end
    love.graphics.setColor(r, g, b, 1)
    love.graphics.print(string.format("[%03d] %s", i - 1, line), 64, ly)
    ly = ly + 15
    if ly > logTop + logH - 12 then
      break
    end
  end
  love.graphics.setColor(1, 1, 1, 1)
end

local function drawSeriesChart(x, y, w, h, title, stats, key)
  love.graphics.setColor(0.13, 0.15, 0.2, 1)
  love.graphics.rectangle("fill", x, y, w, h, 8, 8)
  love.graphics.setColor(0.24, 0.27, 0.34, 1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, 8, 8)
  love.graphics.setColor(0.75, 0.8, 0.9, 1)
  love.graphics.setFont(font.get(10))
  love.graphics.print(title, x + 8, y + 6)

  if not stats then
    return
  end

  local maxLen, maxV = 0, 0
  for _, p in pairs(stats.players or {}) do
    local arr = p[key] or {}
    if #arr > maxLen then maxLen = #arr end
    for i = 1, #arr do
      if arr[i] > maxV then maxV = arr[i] end
    end
  end
  if maxLen < 2 or maxV <= 0 then
    return
  end

  local px, py = x + 8, y + 22
  local pw, ph = w - 16, h - 30
  for _, p in pairs(stats.players or {}) do
    local arr = p[key] or {}
    if #arr >= 2 then
      love.graphics.setColor(p.color[1], p.color[2], p.color[3], 0.95)
      love.graphics.setLineWidth(1.5)
      for i = 2, #arr do
        local x1 = px + ((i - 2) / (maxLen - 1)) * pw
        local y1 = py + ph - (arr[i - 1] / maxV) * ph
        local x2 = px + ((i - 1) / (maxLen - 1)) * pw
        local y2 = py + ph - (arr[i] / maxV) * ph
        love.graphics.line(x1, y1, x2, y2)
      end
    end
  end
  love.graphics.setLineWidth(1)
end

function M.drawGameOver(windowW, windowH, winner, stats)
  love.graphics.setColor(0.04, 0.06, 0.1, 0.88)
  love.graphics.rectangle("fill", 0, 0, windowW, windowH)
  love.graphics.setColor(0.12, 0.14, 0.18, 1)
  love.graphics.rectangle("fill", windowW / 2 - 450, windowH / 2 - 290, 900, 580, 24, 24)
  love.graphics.setColor(0.55, 0.6, 1, 1)
  love.graphics.setFont(font.get(36))
  local title = winner.id == 0 and "DOMINATION!" or "DEFEATED!"
  centeredPrint(title, windowW / 2, windowH / 2 - 248)
  love.graphics.setFont(font.get(14))
  love.graphics.setColor(0.65, 0.68, 0.75, 1)
  centeredPrint(string.format("P%d has conquered all territories. Battle timeline analytics:", winner.id + 1), windowW / 2, windowH / 2 - 206)

  local gx = windowW / 2 - 420
  local gy = windowH / 2 - 180
  local cw = 268
  local ch = 120
  local gapX = 16
  local gapY = 14
  drawSeriesChart(gx, gy, cw, ch, "Colonies (time)", stats, "colonies")
  drawSeriesChart(gx + (cw + gapX), gy, cw, ch, "Total Dice (time)", stats, "totalDice")
  drawSeriesChart(gx + (cw + gapX) * 2, gy, cw, ch, "Rolled Dice (cum)", stats, "rolledDice")
  drawSeriesChart(gx, gy + ch + gapY, cw, ch, "Rolled Sum (cum)", stats, "rolledSum")
  drawSeriesChart(gx + (cw + gapX), gy + ch + gapY, cw, ch, "Avg Roll Face", stats, "avgRoll")

  love.graphics.setColor(0.95, 0.96, 1, 1)
  love.graphics.rectangle("fill", windowW / 2 - 120, windowH / 2 + 206, 240, 48, 12, 12)
  love.graphics.setColor(0.08, 0.09, 0.12, 1)
  love.graphics.setFont(font.get(16))
  centeredPrint("GLORY AWAITS", windowW / 2, windowH / 2 + 218)
end

function M.drawRestartConfirm(windowW, windowH)
  love.graphics.setColor(0.04, 0.06, 0.1, 0.82)
  love.graphics.rectangle("fill", 0, 0, windowW, windowH)
  love.graphics.setColor(0.12, 0.14, 0.18, 1)
  love.graphics.rectangle("fill", windowW / 2 - 200, windowH / 2 - 120, 400, 240, 20, 20)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(font.get(22))
  centeredPrint("Abandon Battle?", windowW / 2, windowH / 2 - 88)
  love.graphics.setFont(font.get(12))
  love.graphics.setColor(0.65, 0.68, 0.75, 1)
  centeredPrint("Your current progress will be lost.", windowW / 2, windowH / 2 - 44)

  love.graphics.setColor(0.75, 0.2, 0.22, 1)
  love.graphics.rectangle("fill", windowW / 2 - 160, windowH / 2 - 8, 320, 44, 8, 8)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.setFont(font.get(14))
  centeredPrint("RETREAT TO MENU", windowW / 2, windowH / 2 + 4)

  love.graphics.setColor(0.18, 0.2, 0.26, 1)
  love.graphics.rectangle("fill", windowW / 2 - 160, windowH / 2 + 48, 320, 44, 8, 8)
  love.graphics.setColor(0.85, 0.88, 0.92, 1)
  centeredPrint("STAY AND FIGHT", windowW / 2, windowH / 2 + 60)
end

--- Hit regions for menus / controls; returns action strings for main.lua
function M.hitTestMenu(windowW, windowH, mx, my, selectedPlayers, allBotsMode)
  local panelLeft = windowW / 2 - 140
  local panelTop = windowH * 0.32
  for i, n in ipairs({ 2, 3, 4, 5, 6, 7, 8 }) do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local bx = panelLeft + col * 68
    local by = panelTop + 56 + row * 48
    if mx >= bx and mx <= bx + 60 and my >= by and my <= by + 40 then
      return "set_players", n
    end
  end
  local modeY = panelTop + 162
  local modeW = 136
  local m1x = windowW / 2 - 140
  local m2x = windowW / 2 + 4
  if mx >= m1x and mx <= m1x + modeW and my >= modeY and my <= modeY + 40 then
    return "set_mode", false
  end
  if mx >= m2x and mx <= m2x + modeW and my >= modeY and my <= modeY + 40 then
    return "set_mode", true
  end

  local startY = panelTop + 214
  local sx = windowW / 2 - 140
  if mx >= sx and mx <= sx + 280 and my >= startY and my <= startY + 56 then
    return "start", selectedPlayers
  end
  return nil
end

function M.hitTestGame(layout, windowW, mx, my)
  local idx = mouse.pixelToCell(mx, my, layout)
  if idx then
    return "cell", idx
  end

  local y = layout.controlsY
  local bw, bh = 220, 52
  local bx = windowW / 2 - bw - 12
  local rx = windowW / 2 + 12
  local gap = 12
  local sx = rx + bh + gap
  if mx >= bx and mx <= bx + bw and my >= y and my <= y + bh then
    return "end_turn"
  end
  if mx >= rx and mx <= rx + bh and my >= y and my <= y + bh then
    return "restart_prompt"
  end
  if mx >= sx and mx <= sx + bh and my >= y and my <= y + bh then
    return "speed_cycle"
  end
  local gx = sx + bh + gap
  if mx >= gx and mx <= gx + bh and my >= y and my <= y + bh then
    return "toggle_grid"
  end
  return nil
end

function M.hitTestGameOver(windowW, windowH, mx, my)
  if mx >= windowW / 2 - 120 and mx <= windowW / 2 + 120 and my >= windowH / 2 + 32 and my <= windowH / 2 + 80 then
    return "menu"
  end
  return nil
end

function M.hitTestRestartConfirm(windowW, windowH, mx, my)
  if mx >= windowW / 2 - 160 and mx <= windowW / 2 + 160 and my >= windowH / 2 - 8 and my <= windowH / 2 + 36 then
    return "menu"
  end
  if mx >= windowW / 2 - 160 and mx <= windowW / 2 + 160 and my >= windowH / 2 + 48 and my <= windowH / 2 + 92 then
    return "close"
  end
  return nil
end

return M
