--- Strategic bot turn selection using heuristic + Monte Carlo.
--- Returns: "attack", attackerId, defenderId | "end_turn" | nil (no action this frame)

local rules = require("game.rules")

local M = {}

local MAX_CANDIDATES = 5
local SIMULATIONS_PER_CANDIDATE = 30
local ATTACK_THRESHOLD = 0

local function rollSum(count)
  local s = 0
  for _ = 1, count do
    s = s + love.math.random(6)
  end
  return s
end

local function buildNeighborMap(state)
  local out = {}
  for id, c in pairs(state.colonies) do
    local set = {}
    for i = 1, #c.cells do
      local cellIdx = c.cells[i]
      local x = cellIdx % 100
      local y = math.floor(cellIdx / 100)
      if y > 0 then
        local nid = state.grid[cellIdx - 100]
        if type(nid) == "number" and nid >= 1 and nid ~= id then set[nid] = true end
      end
      if x < 99 then
        local nid = state.grid[cellIdx + 1]
        if type(nid) == "number" and nid >= 1 and nid ~= id then set[nid] = true end
      end
      if y < 49 then
        local nid = state.grid[cellIdx + 100]
        if type(nid) == "number" and nid >= 1 and nid ~= id then set[nid] = true end
      end
      if x > 0 then
        local nid = state.grid[cellIdx - 1]
        if type(nid) == "number" and nid >= 1 and nid ~= id then set[nid] = true end
      end
    end
    local arr = {}
    for nid, _ in pairs(set) do
      arr[#arr + 1] = nid
    end
    out[id] = arr
  end
  return out
end

local function cloneColoniesLight(state)
  local c2 = {}
  for id, c in pairs(state.colonies) do
    c2[id] = {
      id = id,
      ownerId = c.ownerId,
      diceCount = c.diceCount,
      -- cells are immutable for simulation
      cells = c.cells,
    }
  end
  return c2
end

local function countEnemyNeighbors(colonies, neighborMap, colonyId, ownerId)
  local n = 0
  local neigh = neighborMap[colonyId] or {}
  for i = 1, #neigh do
    local nid = neigh[i]
    local nc = colonies[nid]
    if nc and nc.ownerId ~= ownerId then
      n = n + 1
    end
  end
  return n
end

local function countFriendlyNeighbors(colonies, neighborMap, colonyId, ownerId)
  local n = 0
  local neigh = neighborMap[colonyId] or {}
  for i = 1, #neigh do
    local nid = neigh[i]
    local nc = colonies[nid]
    if nc and nc.ownerId == ownerId then
      n = n + 1
    end
  end
  return n
end

function M.getCandidateActions(state, player, neighborMap)
  local actions = {}
  for id, c in pairs(state.colonies) do
    if c.ownerId == player.id and c.diceCount > 1 then
      local neigh = neighborMap[id] or {}
      for i = 1, #neigh do
        local did = neigh[i]
        local d = state.colonies[did]
        if d and d.ownerId ~= player.id then
          actions[#actions + 1] = { attackerId = id, defenderId = did }
        end
      end
    end
  end
  return actions
end

function M.evaluateHeuristic(action, state, player, neighborMap)
  local a = state.colonies[action.attackerId]
  local d = state.colonies[action.defenderId]
  if not a or not d then
    return -1e9
  end

  local attackerDice = a.diceCount
  local defenderDice = d.diceCount
  local diceAdvantage = attackerDice - defenderDice
  local targetWeakness = 6 - defenderDice

  local expansionPotential = 0
  local targetNeigh = neighborMap[d.id] or {}
  for i = 1, #targetNeigh do
    local nid = targetNeigh[i]
    local nc = state.colonies[nid]
    if nc and nc.ownerId ~= player.id and nid ~= a.id then
      expansionPotential = expansionPotential + 1
    end
  end

  local riskExposure = countEnemyNeighbors(state.colonies, neighborMap, d.id, player.id)
  local edgePreference = 0
  local defNeighCount = #targetNeigh
  if defNeighCount <= 2 then
    edgePreference = 0.8
  elseif defNeighCount >= 5 then
    edgePreference = -0.8
  end

  local killChainBias = expansionPotential * 0.6

  -- Preserve hub strongholds: if high-dice colony is a friendly connector, penalize using it.
  local strongholdPenalty = 0
  local friendlyDeg = countFriendlyNeighbors(state.colonies, neighborMap, a.id, player.id)
  if attackerDice >= 8 and friendlyDeg >= 3 then
    strongholdPenalty = 1.8
  end

  local score =
    (diceAdvantage * 2)
    + targetWeakness
    + (expansionPotential * 1.5)
    - (riskExposure * 1.2)
    + killChainBias
    + edgePreference
    - strongholdPenalty

  return score
end

local function simulateEnemyResponse(simColonies, playerId, neighborMap, gainedColonyId)
  local gained = simColonies[gainedColonyId]
  if not gained or gained.ownerId ~= playerId then
    return false
  end
  local nearbyEnemies = {}
  local neigh = neighborMap[gainedColonyId] or {}
  for i = 1, #neigh do
    local nid = neigh[i]
    local c = simColonies[nid]
    if c and c.ownerId ~= playerId then
      nearbyEnemies[#nearbyEnemies + 1] = c
    end
  end
  if #nearbyEnemies == 0 then
    return false
  end

  local bestEnemy = nearbyEnemies[1]
  for i = 2, #nearbyEnemies do
    if nearbyEnemies[i].diceCount > bestEnemy.diceCount then
      bestEnemy = nearbyEnemies[i]
    end
  end
  if bestEnemy.diceCount <= 1 then
    return false
  end

  local enemySum = rollSum(bestEnemy.diceCount)
  local defendSum = rollSum(gained.diceCount)
  if enemySum > defendSum then
    local movedDice = bestEnemy.diceCount - 1
    bestEnemy.diceCount = 1
    gained.ownerId = bestEnemy.ownerId
    gained.diceCount = movedDice
    return true
  else
    bestEnemy.diceCount = 1
    return false
  end
end

function M.simulateAction(state, action, player, neighborMap)
  local simColonies = cloneColoniesLight(state)
  local a = simColonies[action.attackerId]
  local d = simColonies[action.defenderId]
  if not a or not d or a.ownerId ~= player.id or d.ownerId == player.id or a.diceCount <= 1 then
    return { valid = false, score = -1e9 }
  end

  local originalAttackerDice = a.diceCount
  local as = rollSum(a.diceCount)
  local ds = rollSum(d.diceCount)
  local success = as > ds
  local lostAfterCapture = false

  if success then
    d.ownerId = player.id
    d.diceCount = originalAttackerDice - 1
    a.diceCount = 1
    lostAfterCapture = simulateEnemyResponse(simColonies, player.id, neighborMap, d.id)
  else
    a.diceCount = 1
  end

  local simResult = {
    valid = true,
    success = success,
    lostAfterCapture = lostAfterCapture,
    colonies = simColonies,
    action = action,
    playerId = player.id,
  }
  simResult.score = M.evaluateSimulationResult(simResult, neighborMap)
  return simResult
end

function M.evaluateSimulationResult(simResult, neighborMap)
  local score = 0
  if simResult.success then
    score = score + 3.2
    local gainedId = simResult.action.defenderId
    local gained = simResult.colonies[gainedId]
    if gained and gained.ownerId == simResult.playerId then
      local exp = 0
      local neigh = neighborMap[gainedId] or {}
      for i = 1, #neigh do
        local n = simResult.colonies[neigh[i]]
        if n and n.ownerId ~= simResult.playerId then
          exp = exp + 1
        end
      end
      score = score + exp * 0.9
      local risk = countEnemyNeighbors(simResult.colonies, neighborMap, gainedId, simResult.playerId)
      score = score - risk * 0.8
    end
    if simResult.lostAfterCapture then
      score = score - 3.0
    end
  else
    score = score - 1.8
  end
  return score
end

local function sortCandidatesByHeuristic(cands, state, player, neighborMap)
  for i = 1, #cands do
    cands[i].heuristic = M.evaluateHeuristic(cands[i], state, player, neighborMap)
  end
  table.sort(cands, function(a, b)
    if a.heuristic == b.heuristic then
      return a.attackerId < b.attackerId
    end
    return a.heuristic > b.heuristic
  end)
end

function M.chooseBestAction(state, player, neighborMap)
  local candidates = M.getCandidateActions(state, player, neighborMap)
  if #candidates == 0 then
    return nil, -1e9
  end

  sortCandidatesByHeuristic(candidates, state, player, neighborMap)
  local n = math.min(MAX_CANDIDATES, #candidates)
  local best, bestScore = nil, -1e9

  for i = 1, n do
    local action = candidates[i]
    local total = 0
    for _ = 1, SIMULATIONS_PER_CANDIDATE do
      local sim = M.simulateAction(state, action, player, neighborMap)
      total = total + sim.score
    end
    local expected = total / SIMULATIONS_PER_CANDIDATE
    expected = expected + (action.heuristic * 0.2) -- keep heuristic tie-break momentum
    if expected > bestScore then
      bestScore = expected
      best = action
    end
  end

  return best, bestScore
end

function M.chooseBotAction(state)
  local currentPlayer = state.players[state.currentPlayerIndex + 1]
  if not currentPlayer.isBot or currentPlayer.isEliminated then
    return nil
  end

  local neighborMap = buildNeighborMap(state)
  local bestAction, bestScore = M.chooseBestAction(state, currentPlayer, neighborMap)
  if bestAction and bestScore > ATTACK_THRESHOLD then
    return "attack", bestAction.attackerId, bestAction.defenderId
  end
  -- Deadlock breaker:
  -- if legal attacks exist but all are unfavorable, force the least bad one.
  if bestAction then
    return "attack", bestAction.attackerId, bestAction.defenderId
  end
  return "end_turn"
end

return M
