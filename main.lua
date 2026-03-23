--- Love2D entry: lifecycle wiring, timers, and UI routing (App.tsx analogue).

local os = require("os")

local rules = require("game.rules")
local logic = require("game.logic")
local ai = require("game.ai")
local colony = require("game.colony")
local constants = require("game.constants")
local board = require("render.board")
local ui = require("render.ui")
local keyboard = require("input.keyboard")

local app = {
  mode = "menu",
  selectedPlayers = 2,
  logs = {},
  progress = 0,
  gameState = nil,
  pendingPlayers = 2,
  loadCo = nil,
  postLoadTimer = nil,
  battleTimer = nil,
  botTimer = nil,
  showRestartConfirm = false,
  --- 1 = slowest (watch), 2 = medium, 3 = original speed; FF button cycles 1→2→3→1
  speedTier = 3,
  loadingGrid = nil,
  loadingColonies = nil,
  loadingColonyCount = 0,
  --- When false, cells draw flush; uniform cell grid overlay is off (see # button).
  showGridLines = false,
}

local ww, hh = 1280, 800

local function findWinner(gs)
  for _, p in ipairs(gs.players) do
    if not p.isEliminated then
      return p
    end
  end
  return nil
end

local function delayMult()
  return constants.SPEED_DELAY_MULT[app.speedTier] or 1
end

local function battleDelay()
  return constants.BATTLE_RESULT_DELAY * delayMult()
end

local function botDelay()
  return constants.BOT_ACTION_DELAY * delayMult()
end

local function cycleSpeedTier()
  local oldM = delayMult()
  app.speedTier = (app.speedTier % 3) + 1
  local newM = delayMult()
  if oldM > 0 and newM > 0 then
    local ratio = newM / oldM
    if app.battleTimer then
      app.battleTimer = app.battleTimer * ratio
    end
    if app.botTimer then
      app.botTimer = app.botTimer * ratio
    end
  end
end

local function startGeneration(numPlayers)
  app.mode = "loading"
  app.logs = {}
  app.progress = 0
  app.loadingGrid = nil
  app.loadingColonies = nil
  app.loadingColonyCount = 0
  app.pendingPlayers = numPlayers
  app.loadCo = coroutine.create(function()
    local function onLog(msg)
      table.insert(app.logs, msg)
    end
    local function onProgress(g, c)
      app.loadingGrid = g
      app.loadingColonies = c
      app.loadingColonyCount = colony.countKeys(c)
      app.progress = math.min(100, (app.loadingColonyCount / constants.MAX_COLONIES) * 100)
    end
    local grid, colonies = colony.generateColonies(function()
      coroutine.yield()
    end, onLog, onProgress)
    app.loadingGrid = grid
    app.loadingColonies = colonies
    app.loadingColonyCount = colony.countKeys(colonies)
    app.progress = 100
    app.gameState = logic.createInitialState(grid, colonies, app.pendingPlayers)
    app.postLoadTimer = constants.POST_LOAD_DELAY
  end)
end

local function resetTimersForBattle(gs)
  if gs.phase == "battle-result" then
    app.battleTimer = battleDelay()
    app.botTimer = nil
  elseif gs.phase == "game-over" then
    app.battleTimer = nil
    app.botTimer = nil
  end
end

local function tryHumanCellClick(idx)
  local gs = app.gameState
  if not gs or gs.phase ~= "idle" then
    return
  end
  local cp = gs.players[gs.currentPlayerIndex + 1]
  if cp.isBot then
    return
  end
  local colonyId = gs.grid[idx]
  if type(colonyId) ~= "number" or colonyId < 1 then
    return
  end
  local clicked = gs.colonies[colonyId]
  if clicked.ownerId == gs.currentPlayerIndex then
    gs.selectedColonyId = colonyId
  elseif gs.selectedColonyId then
    local base = gs.colonies[gs.selectedColonyId]
    if base and base.diceCount > 1 and rules.isAdjacent(gs.selectedColonyId, colonyId, gs) then
      logic.executeBattle(gs, gs.selectedColonyId, colonyId)
      resetTimersForBattle(gs)
    end
  end
end

local function tryEndTurn()
  local gs = app.gameState
  if not gs or gs.phase ~= "idle" then
    return
  end
  local cp = gs.players[gs.currentPlayerIndex + 1]
  if cp.isBot then
    return
  end
  logic.handleEndTurn(gs)
  app.botTimer = nil
  local nextP = gs.players[gs.currentPlayerIndex + 1]
  if gs.phase == "idle" and nextP.isBot then
    app.botTimer = botDelay()
  end
end

function love.load()
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("nearest", "nearest")
  ww, hh = love.graphics.getDimensions()
end

function love.resize(w, h)
  ww, hh = w, h
end

function love.update(dt)
  if app.loadCo then
    local ok, err = coroutine.resume(app.loadCo)
    if not ok then
      print("Load error:", err)
      app.loadCo = nil
      app.mode = "menu"
    elseif coroutine.status(app.loadCo) == "dead" then
      app.loadCo = nil
    end
  end

  if app.postLoadTimer then
    app.postLoadTimer = app.postLoadTimer - dt
    if app.postLoadTimer <= 0 then
      app.postLoadTimer = nil
      app.mode = "play"
      local gs = app.gameState
      if gs then
        local cur = gs.players[gs.currentPlayerIndex + 1]
        if gs.phase == "idle" and cur.isBot then
          app.botTimer = botDelay()
        end
      end
    end
  end

  if app.mode ~= "play" or not app.gameState then
    return
  end

  local gs = app.gameState

  if gs.phase == "battle-result" then
    app.botTimer = nil
    if not app.battleTimer then
      app.battleTimer = battleDelay()
    end
    app.battleTimer = app.battleTimer - dt
    if app.battleTimer <= 0 then
      logic.resolveBattleResultPhase(gs)
      app.battleTimer = nil
      local p = gs.players[gs.currentPlayerIndex + 1]
      if gs.phase == "idle" and p.isBot then
        app.botTimer = botDelay()
      end
    end
    return
  end

  if gs.phase == "game-over" then
    app.botTimer = nil
    app.battleTimer = nil
    return
  end

  if gs.phase == "idle" then
    local cur = gs.players[gs.currentPlayerIndex + 1]
    if not cur.isBot or cur.isEliminated then
      app.botTimer = nil
      return
    end

    if app.botTimer == nil then
      app.botTimer = botDelay()
    end
    app.botTimer = app.botTimer - dt
    if app.botTimer <= 0 then
      app.botTimer = nil
      local action, a, b = ai.chooseBotAction(gs)
      if action == "attack" then
        logic.executeBattle(gs, a, b)
        resetTimersForBattle(gs)
      elseif action == "end_turn" then
        logic.handleEndTurn(gs)
        local nextP = gs.players[gs.currentPlayerIndex + 1]
        if gs.phase == "idle" and nextP.isBot then
          app.botTimer = botDelay()
        end
      end
    end
  end
end

function love.draw()
  local layout = ui.computeLayout(ww, hh, app.gameState)

  if app.mode == "menu" then
    ui.drawMenu(ww, hh, app.selectedPlayers)
  elseif app.mode == "loading" then
    ui.drawLoading(ww, hh, app.logs, app.progress, app.loadingGrid, app.loadingColonyCount, app.showGridLines)
  elseif app.mode == "play" and app.gameState then
    local gs = app.gameState
    ui.drawHeader(ww)
    ui.drawBattlePanel(gs, layout, ww)
    board.draw(gs, layout.grid, { showGridLines = app.showGridLines })
    local counts = board.countColoniesPerPlayer(gs)
    ui.drawPlayerBar(gs, layout, ww, counts)
    local endOk = not gs.players[gs.currentPlayerIndex + 1].isBot and gs.phase == "idle"
    ui.drawControls(layout, ww, endOk, app.speedTier, app.showGridLines)

    if gs.phase == "game-over" then
      local w = findWinner(gs)
      if w then
        ui.drawGameOver(ww, hh, w)
      end
    end

    if app.showRestartConfirm then
      ui.drawRestartConfirm(ww, hh)
    end
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  if app.mode == "menu" then
    local act, n = ui.hitTestMenu(ww, hh, x, y, app.selectedPlayers)
    if act == "set_players" then
      app.selectedPlayers = n
    elseif act == "start" then
      startGeneration(n)
    end
    return
  end

  if app.mode == "loading" then
    return
  end

  if app.mode == "play" and app.gameState then
    local gs = app.gameState

    if gs.phase == "game-over" then
      if ui.hitTestGameOver(ww, hh, x, y) == "menu" then
        app.gameState = nil
        app.mode = "menu"
        app.battleTimer = nil
        app.botTimer = nil
      end
      return
    end

    if app.showRestartConfirm then
      local r = ui.hitTestRestartConfirm(ww, hh, x, y)
      if r == "menu" then
        app.gameState = nil
        app.mode = "menu"
        app.showRestartConfirm = false
        app.battleTimer = nil
        app.botTimer = nil
      elseif r == "close" then
        app.showRestartConfirm = false
      end
      return
    end

    local layoutPlay = ui.computeLayout(ww, hh, gs)
    local hit, cellIdx = ui.hitTestGame(layoutPlay, ww, x, y)
    if hit == "end_turn" then
      tryEndTurn()
    elseif hit == "restart_prompt" then
      app.showRestartConfirm = true
    elseif hit == "speed_cycle" then
      cycleSpeedTier()
    elseif hit == "toggle_grid" then
      app.showGridLines = not app.showGridLines
    elseif hit == "cell" then
      tryHumanCellClick(cellIdx)
    end
  end
end

function love.keypressed(key)
  local act = keyboard.actionForKey(key)
  if act == "escape" then
    if app.mode == "play" and app.showRestartConfirm then
      app.showRestartConfirm = false
    elseif app.mode == "play" and app.gameState and not app.showRestartConfirm then
      app.showRestartConfirm = true
    end
    return
  end

  if act == "end_turn" and app.mode == "play" and app.gameState and not app.showRestartConfirm then
    tryEndTurn()
  end

  if key == "g" then
    if app.mode == "loading" then
      app.showGridLines = not app.showGridLines
    elseif app.mode == "play" and app.gameState and not app.showRestartConfirm then
      app.showGridLines = not app.showGridLines
    end
  end
end
