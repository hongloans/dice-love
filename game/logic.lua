--- Pure game rules: initial state, dice rolls, battles, end turn (ports gameLogic.ts + battle from App.tsx).

local constants = require("game.constants")
local colony = require("game.colony")
local random = require("utils.random")

local M = {}

local PLAYER_COLORS = {
  { 0.937, 0.267, 0.267 }, -- #EF4444
  { 0.231, 0.510, 0.965 }, -- #3B82F6
  { 0.063, 0.725, 0.506 }, -- #10B981
  { 0.961, 0.620, 0.043 }, -- #F59E0B
  { 0.545, 0.361, 0.965 }, -- #8B5CF6
  { 0.925, 0.282, 0.600 }, -- #EC4899
  { 0.024, 0.714, 0.831 }, -- #06B6D4
  { 0.976, 0.451, 0.086 }, -- #F97316
}

local function sumRolls(rolls)
  local s = 0
  for _, v in ipairs(rolls) do
    s = s + v
  end
  return s
end

function M.rollDice(count)
  local rolls = {}
  for _ = 1, count do
    table.insert(rolls, love.math.random(6))
  end
  return rolls
end

--- Build game state after colony generation (createInitialState in gameLogic.ts).
--- allBotsMode=true: all players are bots. false: P1 is human (red), others bots.
function M.createInitialState(grid, colonies, numPlayers, allBotsMode)
  allBotsMode = allBotsMode == true
  local players = {}
  for i = 1, numPlayers do
    table.insert(players, {
      id = i - 1,
      color = PLAYER_COLORS[i],
      isBot = allBotsMode or (i ~= 1),
      isEliminated = false,
    })
  end

  local colonyIds = {}
  for id, _ in pairs(colonies) do
    table.insert(colonyIds, id)
  end
  random.shuffle(colonyIds)

  local totalGenerated = #colonyIds
  local coloniesPerPlayer = math.floor(totalGenerated / numPlayers)

  for i = 0, numPlayers - 1 do
    local playerColonies = {}
    for j = 1, coloniesPerPlayer do
      local id = colonyIds[i * coloniesPerPlayer + j]
      local c = colonies[id]
      if c then
        c.ownerId = i
        c.diceCount = 1
        table.insert(playerColonies, id)
      end
    end

    local extraDice = #playerColonies
    while extraDice > 0 do
      local targetColonyId = random.sample(playerColonies)
      local targetColony = colonies[targetColonyId]
      if targetColony.diceCount < 20 then
        targetColony.diceCount = targetColony.diceCount + 1
        extraDice = extraDice - 1
      else
        local allFull = true
        for _, pid in ipairs(playerColonies) do
          if colonies[pid].diceCount < 20 then
            allFull = false
            break
          end
        end
        if allFull then
          break
        end
      end
    end
  end

  return {
    players = players,
    colonies = colonies,
    grid = grid,
    currentPlayerIndex = 0,
    selectedColonyId = nil,
    phase = "idle",
    battleResult = nil,
  }
end

function M.handleEndTurn(state)
  local currentPlayer = state.players[state.currentPlayerIndex + 1]

  local playerColonies = {}
  for _, c in pairs(state.colonies) do
    if c.ownerId == currentPlayer.id then
      table.insert(playerColonies, c)
    end
  end

  local newDiceCount = #playerColonies
  while newDiceCount > 0 do
    local available = {}
    for _, c in ipairs(playerColonies) do
      if c.diceCount < 20 then
        table.insert(available, c)
      end
    end
    if #available == 0 then
      break
    end
    local target = random.sample(available)
    target.diceCount = target.diceCount + 1
    newDiceCount = newDiceCount - 1
  end

  local n = #state.players
  local nextIndex = (state.currentPlayerIndex + 1) % n
  while state.players[nextIndex + 1].isEliminated do
    nextIndex = (nextIndex + 1) % n
  end

  state.currentPlayerIndex = nextIndex
  state.selectedColonyId = nil
  state.phase = "idle"
  return state
end

--- Battle resolution (executeBattle in App.tsx).
function M.executeBattle(state, attackerId, defenderId)
  local attacker = state.colonies[attackerId]
  local defender = state.colonies[defenderId]

  local attackerRolls = M.rollDice(attacker.diceCount)
  local defenderRolls = M.rollDice(defender.diceCount)
  local attackerSum = sumRolls(attackerRolls)
  local defenderSum = sumRolls(defenderRolls)

  local winnerId = attacker.ownerId

  if attackerSum > defenderSum then
    state.colonies[defenderId] = {
      id = defender.id,
      cells = defender.cells,
      ownerId = attacker.ownerId,
      diceCount = attacker.diceCount - 1,
    }
    state.colonies[attackerId] = {
      id = attacker.id,
      cells = attacker.cells,
      ownerId = attacker.ownerId,
      diceCount = 1,
    }
    winnerId = attacker.ownerId
  else
    state.colonies[attackerId] = {
      id = attacker.id,
      cells = attacker.cells,
      ownerId = attacker.ownerId,
      diceCount = 1,
    }
    winnerId = defender.ownerId
  end

  for _, p in ipairs(state.players) do
    local hasColonies = false
    for _, c in pairs(state.colonies) do
      if c.ownerId == p.id then
        hasColonies = true
        break
      end
    end
    p.isEliminated = not hasColonies
  end

  local activeCount = 0
  for _, p in ipairs(state.players) do
    if not p.isEliminated then
      activeCount = activeCount + 1
    end
  end
  local isGameOver = activeCount == 1

  state.battleResult = {
    attackerId = attackerId,
    defenderId = defenderId,
    attackerOwnerId = attacker.ownerId,
    defenderOwnerId = defender.ownerId,
    attackerRolls = attackerRolls,
    defenderRolls = defenderRolls,
    winnerId = winnerId,
  }

  if attackerSum > defenderSum then
    state.selectedColonyId = defenderId
  else
    state.selectedColonyId = attackerId
  end

  if isGameOver then
    state.phase = "game-over"
  else
    state.phase = "battle-result"
  end

  return state
end

--- After battle-result timeout (useEffect in App.tsx).
function M.resolveBattleResultPhase(state)
  if state.phase ~= "battle-result" then
    return state
  end

  local currentP = state.players[state.currentPlayerIndex + 1]
  local selected = state.selectedColonyId and state.colonies[state.selectedColonyId] or nil
  local keepSelection = not currentP.isBot
    and selected
    and selected.ownerId == currentP.id
    and selected.diceCount > 1

  state.phase = "idle"
  state.battleResult = nil
  if not keepSelection then
    state.selectedColonyId = nil
  end
  return state
end

function M.getPlayerColors()
  return PLAYER_COLORS
end

return M
