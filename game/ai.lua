--- Bot turn (port of useEffect bot block in App.tsx).
--- Returns: "attack", attackerId, defenderId | "end_turn" | nil (no action this frame)

local rules = require("game.rules")

local M = {}

function M.chooseBotAction(state)
  local currentPlayer = state.players[state.currentPlayerIndex + 1]
  if not currentPlayer.isBot or currentPlayer.isEliminated then
    return nil
  end

  local botColonies = {}
  for _, c in pairs(state.colonies) do
    if c.ownerId == currentPlayer.id and c.diceCount > 1 then
      table.insert(botColonies, c)
    end
  end

  if #botColonies == 0 then
    return "end_turn"
  end

  -- _.shuffle(botColonies)
  for i = #botColonies, 2, -1 do
    local j = love.math.random(i)
    botColonies[i], botColonies[j] = botColonies[j], botColonies[i]
  end

  for _, col in ipairs(botColonies) do
    local enemyColonies = {}
    for _, c in pairs(state.colonies) do
      if c.ownerId ~= currentPlayer.id and rules.isAdjacent(col.id, c.id, state) then
        table.insert(enemyColonies, c)
      end
    end

    if #enemyColonies > 0 then
      local target = enemyColonies[1]
      for i = 2, #enemyColonies do
        if enemyColonies[i].diceCount < target.diceCount then
          target = enemyColonies[i]
        end
      end

      if col.diceCount >= target.diceCount then
        return "attack", col.id, target.id
      end
    end
  end

  return "end_turn"
end

return M
