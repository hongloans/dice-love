--- Grid and colony parameters (must match dice-war / colonyGenerator.ts)
local M = {}

M.WIDTH = 100
M.HEIGHT = 50
M.TOTAL_CELLS = M.WIDTH * M.HEIGHT
M.CELLS_PER_COLONY = 8
-- Lower cap keeps open world space.
M.MAX_COLONIES = 280

--- Visual: base cell size in pixels (scaled to fit window in main.lua)
M.BASE_CELL_SIZE = 12

--- Timing (seconds), matching App.tsx setTimeout(..., 100)
M.BATTLE_RESULT_DELAY = 0.1
M.BOT_ACTION_DELAY = 0.1

-- Multipliers per speed tier (applied to battle + bot delays):
-- t1 slow watch, t2 medium, t3 original, t4 = 3x faster than t3, t5 = ultra.
M.SPEED_DELAY_MULT = { 4, 2, 1, 1 / 3, 1 / 6 }

--- Post-generation pause before play (React: 800ms after createInitialState)
M.POST_LOAD_DELAY = 0.8

return M
