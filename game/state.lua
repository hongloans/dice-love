--- Phase identifiers and state shape notes (matches `GameState` in dice-war `types/index.ts`).
--- Game data lives in a single table updated by `game/logic.lua` and `main.lua`.

return {
  PHASE = {
    idle = "idle",
    battle_result = "battle-result",
    game_over = "game-over",
  },
}
