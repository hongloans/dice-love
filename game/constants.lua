--- Grid and colony parameters (must match dice-war / colonyGenerator.ts)
local M = {}

M.WIDTH = 100
M.HEIGHT = 50
M.TOTAL_CELLS = M.WIDTH * M.HEIGHT
M.CELLS_PER_COLONY = 8
--- Lower cap + choke geography leaves more open space and narrow crossings (see colony.lua).
M.MAX_COLONIES = 280

--- Strategic chokepoints: `grid[i] == 0` = impassable void (colonies never claim).
M.CHOKE_BRIDGE_PITCH = 16
M.CHOKE_BRIDGE_WIDTH = 2
--- Relative row positions (0..1) for horizontal moats; thickness = rows blocked (bridges still every PITCH).
M.CHOKE_MOAT_REL_Y = { 0.28, 0.72 }
M.CHOKE_MOAT_THICKNESS = 3
--- Center vertical 2-column barrier with horizontal gaps aligned to bridge pitch.
M.CHOKE_VERTICAL_SPINE = true

--- Visual: base cell size in pixels (scaled to fit window in main.lua)
M.BASE_CELL_SIZE = 12

--- Timing (seconds), matching App.tsx setTimeout(..., 100)
M.BATTLE_RESULT_DELAY = 0.1
M.BOT_ACTION_DELAY = 0.1

--- Multipliers per speed tier (applied to battle + bot delays). Tier 3 = 1 = original pace.
M.SPEED_DELAY_MULT = { 4, 2, 1 }

--- Post-generation pause before play (React: 800ms after createInitialState)
M.POST_LOAD_DELAY = 0.8

return M
