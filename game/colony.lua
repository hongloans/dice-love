--- Procedural colony / grid generation (port of colonyGenerator.ts).
--- Cell indices are 0-based (0 .. TOTAL_CELLS - 1) to match the React implementation.
--- Grid values: false = empty playable, 0 = impassable choke void, n>=1 = colony id.

local constants = require("game.constants")
local random = require("utils.random")

local M = {}

local function getNeighbors(idx)
  local WIDTH = constants.WIDTH
  local HEIGHT = constants.HEIGHT
  local x = idx % WIDTH
  local y = math.floor(idx / WIDTH)
  local neighbors = {}
  if y > 0 then table.insert(neighbors, idx - WIDTH) end
  if x < WIDTH - 1 then table.insert(neighbors, idx + 1) end
  if y < HEIGHT - 1 then table.insert(neighbors, idx + WIDTH) end
  if x > 0 then table.insert(neighbors, idx - 1) end
  return neighbors
end

--- Only cells still `false` can host colony growth.
local function isPlayableEmpty(grid, idx)
  return grid[idx] == false
end

--- Horizontal moats + optional center spine; bridges create narrow crossings (chokepoints).
local function applyStrategicChokepoints(grid, onLog)
  local w = constants.WIDTH
  local h = constants.HEIGHT
  local pitch = constants.CHOKE_BRIDGE_PITCH
  local bw = constants.CHOKE_BRIDGE_WIDTH
  local blocked = 0

  local function blockIdx(idx)
    if grid[idx] == false then
      grid[idx] = 0
      blocked = blocked + 1
    end
  end

  local thick = math.max(1, math.floor(constants.CHOKE_MOAT_THICKNESS or 1))
  local halfLo = math.floor((thick - 1) / 2)
  local halfHi = thick - 1 - halfLo

  for _, rel in ipairs(constants.CHOKE_MOAT_REL_Y) do
    local y0 = math.floor(h * rel)
    for dy = -halfLo, halfHi do
      local y = y0 + dy
      if y > 0 and y < h - 1 then
        for x = 0, w - 1 do
          local inBridge = (x % pitch) < bw
          if not inBridge then
            blockIdx(y * w + x)
          end
        end
      end
    end
  end

  if constants.CHOKE_VERTICAL_SPINE then
    local cx = math.floor(w / 2)
    for y = 0, h - 1 do
      local rowOpen = (y % pitch) < bw
      if not rowOpen then
        for dx = 0, 1 do
          local x = cx - 1 + dx
          if x >= 0 and x < w then
            blockIdx(y * w + x)
          end
        end
      end
    end
  end

  onLog(string.format("[STRATEGY] Choke geography: %d impassable cells (moats + spine).", blocked))
end

local function pickRandomPlayableSeed(grid)
  for _ = 1, 800 do
    local idx = math.floor(love.math.random() * constants.TOTAL_CELLS)
    if isPlayableEmpty(grid, idx) then
      return idx
    end
  end
  for i = 0, constants.TOTAL_CELLS - 1 do
    if isPlayableEmpty(grid, i) then
      return i
    end
  end
  return nil
end

local function growColony(seedIndex, grid)
  if not isPlayableEmpty(grid, seedIndex) then
    return {}
  end

  local colonyCells = { seedIndex }
  local queue = { seedIndex }
  local visited = { [seedIndex] = true }

  while #queue > 0 and #colonyCells < constants.CELLS_PER_COLONY do
    local qIdx = love.math.random(#queue)
    local current = table.remove(queue, qIdx)
    local neighbors = random.shuffle(getNeighbors(current))

    for _, n in ipairs(neighbors) do
      if isPlayableEmpty(grid, n) and not visited[n] then
        visited[n] = true
        table.insert(colonyCells, n)
        table.insert(queue, n)
        if #colonyCells == constants.CELLS_PER_COLONY then
          break
        end
      end
    end
  end

  return colonyCells
end

--- `onProgress(grid, colonies)` optional: called after each colony is committed so the UI can preview.
--- `yieldFn` optional: called after each committed colony so Love can render (replaces TS setTimeout every 5).
function M.generateColonies(yieldFn, onLog, onProgress)
  onProgress = onProgress or function() end
  local grid = {}
  for i = 0, constants.TOTAL_CELLS - 1 do
    grid[i] = false
  end

  local colonies = {}
  local frontier = {}

  onLog = onLog or function() end

  onLog("[SYSTEM] Initializing strategic grid (" .. constants.WIDTH .. "x" .. constants.HEIGHT .. ")...")
  applyStrategicChokepoints(grid, onLog)

  local currentColonyId = 1
  local firstSeed = pickRandomPlayableSeed(grid)
  if not firstSeed then
    onLog("[CRITICAL] No playable cell for initial sector.")
    return grid, colonies
  end

  local firstCells = growColony(firstSeed, grid)
  if #firstCells ~= constants.CELLS_PER_COLONY then
    onLog("[CRITICAL] Initial colony growth failed — not enough contiguous playable cells.")
    return grid, colonies
  end
  for _, idx in ipairs(firstCells) do
    grid[idx] = currentColonyId
    for _, n in ipairs(getNeighbors(idx)) do
      if isPlayableEmpty(grid, n) then
        frontier[n] = true
      end
    end
  end

  colonies[currentColonyId] = {
    id = currentColonyId,
    cells = firstCells,
    ownerId = -1,
    diceCount = 0,
  }

  onLog("[INFO] Sector #001 established.")

  onProgress(grid, colonies)
  if yieldFn then
    yieldFn()
  end

  currentColonyId = currentColonyId + 1

  while currentColonyId <= constants.MAX_COLONIES and next(frontier) ~= nil do
    local frontierArray = {}
    for k, _ in pairs(frontier) do
      table.insert(frontierArray, k)
    end

    local seedIndex = random.sample(frontierArray)
    frontier[seedIndex] = nil

    if not isPlayableEmpty(grid, seedIndex) then
      -- taken or void
    else
      local colonyCells = growColony(seedIndex, grid)

      if #colonyCells == constants.CELLS_PER_COLONY then
        for _, idx in ipairs(colonyCells) do
          grid[idx] = currentColonyId
          for _, n in ipairs(getNeighbors(idx)) do
            if isPlayableEmpty(grid, n) then
              frontier[n] = true
            end
          end
        end

        colonies[currentColonyId] = {
          id = currentColonyId,
          cells = colonyCells,
          ownerId = -1,
          diceCount = 0,
        }

        if currentColonyId % 20 == 0 then
          onLog(string.format("[INFO] Sector #%03d established.", currentColonyId))
        end

        if currentColonyId == math.floor(constants.MAX_COLONIES * 0.25) then
          onLog("[PROGRESS] 25% expansion complete.")
        end
        if currentColonyId == math.floor(constants.MAX_COLONIES * 0.50) then
          onLog("[PROGRESS] 50% expansion complete.")
        end
        if currentColonyId == math.floor(constants.MAX_COLONIES * 0.75) then
          onLog("[PROGRESS] 75% expansion complete.")
        end

        currentColonyId = currentColonyId + 1
        onProgress(grid, colonies)
        if yieldFn then
          yieldFn()
        end
      end
    end
  end

  onLog("[SUCCESS] Frontier expansion complete. " .. tostring(M.countKeys(colonies)) .. " colonies distributed.")

  return grid, colonies
end

function M.countKeys(t)
  local n = 0
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

M.getNeighbors = getNeighbors

return M
