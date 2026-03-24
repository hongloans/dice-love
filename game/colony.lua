--- Procedural colony generator with branching growth and post-processing.
--- Grid values: false = empty playable, 0 = reserved impassable marker, n>=1 = colony id.

local constants = require("game.constants")

local M = {}

local WIDTH = constants.WIDTH
local HEIGHT = constants.HEIGHT
local TOTAL_CELLS = constants.TOTAL_CELLS
local CELLS_PER_COLONY = constants.CELLS_PER_COLONY
local MAX_COLONIES = constants.MAX_COLONIES

-- Growth tuning.
local BRANCH_PROBABILITY = constants.BRANCH_PROBABILITY or 0.33
local CONTINUE_PROBABILITY = constants.CONTINUE_PROBABILITY or 0.72
local LOCAL_SEED_BIAS = constants.LOCAL_SEED_BIAS or 0.7

local DIRS = {
  { 0, -1 },
  { 1, 0 },
  { 0, 1 },
  { -1, 0 },
}

local function xyToIdx(x, y)
  return y * WIDTH + x
end

local function idxToXY(idx)
  return idx % WIDTH, math.floor(idx / WIDTH)
end

local function inBounds(x, y)
  return x >= 0 and x < WIDTH and y >= 0 and y < HEIGHT
end

local function inViewport(x, y, vp)
  return x >= vp.x0 and x <= vp.x1 and y >= vp.y0 and y <= vp.y1
end

local function getNeighbors(idx)
  local x, y = idxToXY(idx)
  local out = {}
  if y > 0 then out[#out + 1] = idx - WIDTH end
  if x < WIDTH - 1 then out[#out + 1] = idx + 1 end
  if y < HEIGHT - 1 then out[#out + 1] = idx + WIDTH end
  if x > 0 then out[#out + 1] = idx - 1 end
  return out
end

local function isPlayableEmpty(grid, idx, vp)
  if idx < 0 or idx >= TOTAL_CELLS then
    return false
  end
  if grid[idx] ~= false then
    return false
  end
  if vp then
    local x, y = idxToXY(idx)
    if not inViewport(x, y, vp) then
      return false
    end
  end
  return true
end

local function isDirLegal(x, y, dir, vp)
  local nx = x + DIRS[dir][1]
  local ny = y + DIRS[dir][2]
  if not inBounds(nx, ny) then
    return false
  end
  if vp and not inViewport(nx, ny, vp) then
    return false
  end
  return true
end

-- =========================
-- Growth logic
-- =========================

--- Probabilistic branching growth (tree/root/spider-like).
--- Returns a flat list of cell indices (size = targetSize on success).
function M.growColonyBranching(seedIndex, grid, targetSize, vp)
  targetSize = targetSize or CELLS_PER_COLONY
  if not isPlayableEmpty(grid, seedIndex, vp) then
    return {}
  end

  local used = { [seedIndex] = true }
  local cells = { seedIndex }
  local tips = { { idx = seedIndex, dir = love.math.random(1, 4) } }
  local stallCount = 0
  local maxStall = targetSize * 8

  while #cells < targetSize and #tips > 0 and stallCount < maxStall do
    local progressed = false
    local initialTipCount = #tips

    for t = initialTipCount, 1, -1 do
      if #cells >= targetSize then
        break
      end
      local tip = tips[t]
      local x, y = idxToXY(tip.idx)

      local dirOrder = {}
      if love.math.random() <= CONTINUE_PROBABILITY and isDirLegal(x, y, tip.dir, vp) then
        dirOrder[#dirOrder + 1] = tip.dir
      end
      local d1 = ((tip.dir + love.math.random(1, 2) - 2) % 4) + 1
      local d2 = ((tip.dir + 4 - (love.math.random(1, 2) - 1) - 1) % 4) + 1
      local d3 = ((tip.dir + 1) % 4) + 1
      local candidates = { d1, d2, d3, 1, 2, 3, 4 }
      for _, d in ipairs(candidates) do
        local exists = false
        for i = 1, #dirOrder do
          if dirOrder[i] == d then
            exists = true
            break
          end
        end
        if not exists and isDirLegal(x, y, d, vp) then
          dirOrder[#dirOrder + 1] = d
        end
      end

      local expandedDir = nil
      for i = 1, #dirOrder do
        local d = dirOrder[i]
        local nx = x + DIRS[d][1]
        local ny = y + DIRS[d][2]
        local nidx = xyToIdx(nx, ny)
        if isPlayableEmpty(grid, nidx, vp) and not used[nidx] then
          used[nidx] = true
          cells[#cells + 1] = nidx
          tip.idx = nidx
          tip.dir = d
          expandedDir = d
          progressed = true
          break
        end
      end

      if expandedDir and #cells < targetSize and love.math.random() <= BRANCH_PROBABILITY then
        local bx, by = idxToXY(tip.idx)
        local bdir = love.math.random(1, 4)
        for _ = 1, 4 do
          if isDirLegal(bx, by, bdir, vp) then
            break
          end
          bdir = (bdir % 4) + 1
        end
        tips[#tips + 1] = { idx = tip.idx, dir = bdir }
      elseif not expandedDir then
        tips[t] = tips[#tips]
        tips[#tips] = nil
      end
    end

    if progressed then
      stallCount = 0
    else
      stallCount = stallCount + 1
    end
  end

  if #cells ~= targetSize then
    return {}
  end
  return cells
end

local function pickRandomPlayableSeed(grid, vp)
  for _ = 1, 900 do
    local idx = math.floor(love.math.random() * TOTAL_CELLS)
    if isPlayableEmpty(grid, idx, vp) then
      return idx
    end
  end
  for i = 0, TOTAL_CELLS - 1 do
    if isPlayableEmpty(grid, i, vp) then
      return i
    end
  end
  return nil
end

local function pickSeedBiased(grid, occupiedCells, vp)
  if #occupiedCells == 0 or love.math.random() > LOCAL_SEED_BIAS then
    return pickRandomPlayableSeed(grid, vp)
  end

  for _ = 1, 90 do
    local base = occupiedCells[love.math.random(#occupiedCells)]
    local bx, by = idxToXY(base)
    local rx = bx + love.math.random(-6, 6)
    local ry = by + love.math.random(-6, 6)
    if inBounds(rx, ry) then
      local idx = xyToIdx(rx, ry)
      if isPlayableEmpty(grid, idx, vp) then
        return idx
      end
    end
  end
  return pickRandomPlayableSeed(grid, vp)
end

local function commitColony(grid, colonies, id, cells, occupiedCells)
  for i = 1, #cells do
    local idx = cells[i]
    grid[idx] = id
    occupiedCells[#occupiedCells + 1] = idx
  end
  colonies[id] = {
    id = id,
    cells = cells,
    ownerId = -1,
    diceCount = 0,
  }
end

local function clearColonyCells(grid, cells)
  for i = 1, #cells do
    local idx = cells[i]
    if grid[idx] ~= 0 then
      grid[idx] = false
    end
  end
end

-- =========================
-- Post-processing
-- =========================

function M.computeCentroid(colonies)
  local sx, sy, n = 0, 0, 0
  for _, c in pairs(colonies) do
    for i = 1, #c.cells do
      local x, y = idxToXY(c.cells[i])
      sx = sx + x
      sy = sy + y
      n = n + 1
    end
  end
  if n == 0 then
    return WIDTH / 2, HEIGHT / 2
  end
  return sx / n, sy / n
end

local function buildViewport(cx, cy, size)
  local half = math.floor(size / 2)
  local x0 = math.floor(cx) - half
  local y0 = math.floor(cy) - half
  return {
    x0 = x0,
    y0 = y0,
    x1 = x0 + size - 1,
    y1 = y0 + size - 1,
  }
end

local function countComponents(cells)
  if #cells == 0 then
    return 0
  end
  local set = {}
  for i = 1, #cells do
    set[cells[i]] = true
  end
  local seen = {}
  local comps = 0
  for i = 1, #cells do
    local start = cells[i]
    if not seen[start] then
      comps = comps + 1
      local q = { start }
      seen[start] = true
      local qi = 1
      while qi <= #q do
        local cur = q[qi]
        qi = qi + 1
        local neigh = getNeighbors(cur)
        for k = 1, #neigh do
          local nidx = neigh[k]
          if set[nidx] and not seen[nidx] then
            seen[nidx] = true
            q[#q + 1] = nidx
          end
        end
      end
    end
  end
  return comps
end

function M.cropToViewport(grid, colonies, vp)
  local affected = {}
  for i = 0, TOTAL_CELLS - 1 do
    local g = grid[i]
    local x, y = idxToXY(i)
    if not inViewport(x, y, vp) then
      if type(g) == "number" and g >= 1 then
        affected[g] = true
      end
      grid[i] = 0
    end
  end

  for id, c in pairs(colonies) do
    local kept = {}
    for i = 1, #c.cells do
      local idx = c.cells[i]
      local x, y = idxToXY(idx)
      if inViewport(x, y, vp) and grid[idx] == id then
        kept[#kept + 1] = idx
      end
    end
    if #kept ~= #c.cells then
      affected[id] = true
    end
    c.cells = kept
    if #c.cells > 0 and countComponents(c.cells) > 1 then
      affected[id] = true
    end
  end
  return affected
end

local function tryRespawnColony(id, grid, colonies, vp, biasIdx)
  local targetSize = CELLS_PER_COLONY
  for _ = 1, 240 do
    local seed
    if biasIdx then
      local bx, by = idxToXY(biasIdx)
      local rx = bx + love.math.random(-8, 8)
      local ry = by + love.math.random(-8, 8)
      if inBounds(rx, ry) and inViewport(rx, ry, vp) then
        local idx = xyToIdx(rx, ry)
        if isPlayableEmpty(grid, idx, vp) then
          seed = idx
        end
      end
    end
    if not seed then
      seed = pickRandomPlayableSeed(grid, vp)
    end
    if not seed then
      break
    end
    local cells = M.growColonyBranching(seed, grid, targetSize, vp)
    if #cells == targetSize then
      colonies[id].cells = cells
      for i = 1, #cells do
        grid[cells[i]] = id
      end
      return true
    end
  end
  return false
end

function M.relocateColonies(grid, colonies, affectedIds, vp, onLog)
  for id, _ in pairs(affectedIds) do
    local c = colonies[id]
    if c then
      clearColonyCells(grid, c.cells)
      c.cells = {}
    end
  end
  for id, _ in pairs(affectedIds) do
    local c = colonies[id]
    if c then
      local ok = tryRespawnColony(id, grid, colonies, vp, nil)
      if not ok then
        onLog(string.format("[WARN] Respawn failed for sector #%03d; dropping sector.", id))
        colonies[id] = nil
      end
    end
  end
end

local function buildAdjacencyMap(grid, colonies)
  local adj = {}
  for id, _ in pairs(colonies) do
    adj[id] = {}
  end
  for id, c in pairs(colonies) do
    for i = 1, #c.cells do
      local nbs = getNeighbors(c.cells[i])
      for k = 1, #nbs do
        local nid = grid[nbs[k]]
        if type(nid) == "number" and nid >= 1 and nid ~= id and colonies[nid] then
          adj[id][nid] = true
        end
      end
    end
  end
  return adj
end

local function nearestColonyId(colonies, fromId)
  local c = colonies[fromId]
  if not c or #c.cells == 0 then
    return nil
  end
  local fx, fy = idxToXY(c.cells[1])
  local best, bestD = nil, nil
  for id, other in pairs(colonies) do
    if id ~= fromId and #other.cells > 0 then
      local ox, oy = idxToXY(other.cells[1])
      local d = math.abs(ox - fx) + math.abs(oy - fy)
      if not bestD or d < bestD then
        bestD = d
        best = id
      end
    end
  end
  return best
end

function M.enforceAdjacency(grid, colonies, vp, onLog)
  local attempts = 0
  while attempts < 6 do
    attempts = attempts + 1
    local adj = buildAdjacencyMap(grid, colonies)
    local isolated = {}
    for id, c in pairs(colonies) do
      if #c.cells > 0 and not next(adj[id]) then
        isolated[#isolated + 1] = id
      end
    end
    if #isolated == 0 then
      return
    end

    for i = 1, #isolated do
      local id = isolated[i]
      local c = colonies[id]
      if c and #c.cells > 0 then
        clearColonyCells(grid, c.cells)
        c.cells = {}
        local nearId = nearestColonyId(colonies, id)
        local bias = nearId and colonies[nearId] and colonies[nearId].cells[1] or nil
        local ok = tryRespawnColony(id, grid, colonies, vp, bias)
        if not ok then
          local mergeInto = nearId or nearestColonyId(colonies, id)
          if mergeInto and colonies[mergeInto] and c then
            onLog(string.format("[WARN] Sector #%03d merged into #%03d (adjacency fallback).", id, mergeInto))
            colonies[id] = nil
          end
        end
      end
    end
  end
end

local function connectedComponentsFromAdj(adj)
  local seen = {}
  local comps = {}
  for id, _ in pairs(adj) do
    if not seen[id] then
      local stack = { id }
      seen[id] = true
      local comp = {}
      while #stack > 0 do
        local cur = stack[#stack]
        stack[#stack] = nil
        comp[#comp + 1] = cur
        for n, _ in pairs(adj[cur]) do
          if not seen[n] then
            seen[n] = true
            stack[#stack + 1] = n
          end
        end
      end
      comps[#comps + 1] = comp
    end
  end
  return comps
end

local function largestComponentIndex(comps)
  local bestI, bestN = 1, 0
  for i = 1, #comps do
    if #comps[i] > bestN then
      bestN = #comps[i]
      bestI = i
    end
  end
  return bestI
end

function M.enforceConnectedGraph(grid, colonies, vp, onLog)
  local rounds = 0
  while rounds < 6 do
    rounds = rounds + 1
    local adj = buildAdjacencyMap(grid, colonies)
    local comps = connectedComponentsFromAdj(adj)
    if #comps <= 1 then
      return
    end

    local keepIdx = largestComponentIndex(comps)
    local keep = {}
    for i = 1, #comps[keepIdx] do
      keep[comps[keepIdx][i]] = true
    end

    for ci = 1, #comps do
      if ci ~= keepIdx then
        local comp = comps[ci]
        for j = 1, #comp do
          local id = comp[j]
          local c = colonies[id]
          if c and #c.cells > 0 then
            clearColonyCells(grid, c.cells)
            c.cells = {}
            local nearId = nearestColonyId(colonies, id)
            local bias = nearId and colonies[nearId] and colonies[nearId].cells[1] or nil
            local ok = tryRespawnColony(id, grid, colonies, vp, bias)
            if not ok then
              local mergeInto = nearId or nearestColonyId(colonies, id)
              if mergeInto and colonies[mergeInto] then
                onLog(string.format("[WARN] Sector #%03d removed (connectivity fallback near #%03d).", id, mergeInto))
                colonies[id] = nil
              end
            end
          end
        end
      end
    end
  end

  local adj = buildAdjacencyMap(grid, colonies)
  local comps = connectedComponentsFromAdj(adj)
  if #comps > 1 then
    local keepIdx = largestComponentIndex(comps)
    local keep = {}
    for i = 1, #comps[keepIdx] do
      keep[comps[keepIdx][i]] = true
    end
    for ci = 1, #comps do
      if ci ~= keepIdx then
        for j = 1, #comps[ci] do
          local id = comps[ci][j]
          local c = colonies[id]
          if c then
            clearColonyCells(grid, c.cells)
            colonies[id] = nil
          end
        end
      end
    end
    onLog("[WARN] Disconnected island components removed by final connectivity clamp.")
  end
end

-- =========================
-- Generation loop
-- =========================

--- `onProgress(grid, colonies)` optional: called after each committed colony so the UI can preview.
--- `yieldFn` optional: called after each commit or heavy post step so Love can render.
function M.generateColonies(yieldFn, onLog, onProgress)
  onProgress = onProgress or function() end
  onLog = onLog or function() end

  local grid = {}
  for i = 0, TOTAL_CELLS - 1 do
    grid[i] = false
  end

  local colonies = {}
  local occupied = {}

  onLog("[SYSTEM] Initializing strategic grid (" .. WIDTH .. "x" .. HEIGHT .. ")...")

  local created = 0
  local nextId = 1
  local failures = 0
  local maxFailures = MAX_COLONIES * 30

  while created < MAX_COLONIES and failures < maxFailures do
    local seed = pickSeedBiased(grid, occupied, nil)
    if not seed then
      break
    end

    local cells = M.growColonyBranching(seed, grid, CELLS_PER_COLONY, nil)
    if #cells == CELLS_PER_COLONY then
      commitColony(grid, colonies, nextId, cells, occupied)
      created = created + 1
      if nextId % 20 == 0 or nextId == 1 then
        onLog(string.format("[INFO] Sector #%03d established.", nextId))
      end
      if nextId == math.floor(MAX_COLONIES * 0.25) then
        onLog("[PROGRESS] 25% expansion complete.")
      elseif nextId == math.floor(MAX_COLONIES * 0.50) then
        onLog("[PROGRESS] 50% expansion complete.")
      elseif nextId == math.floor(MAX_COLONIES * 0.75) then
        onLog("[PROGRESS] 75% expansion complete.")
      end
      nextId = nextId + 1
      onProgress(grid, colonies)
      if yieldFn then
        yieldFn()
      end
    else
      failures = failures + 1
    end
  end

  -- Post-process: centroid crop -> relocate truncated/disconnected -> enforce adjacency.
  local cx, cy = M.computeCentroid(colonies)
  local viewport = buildViewport(cx, cy, 100)
  local affected = M.cropToViewport(grid, colonies, viewport)
  onProgress(grid, colonies)
  if yieldFn then
    yieldFn()
  end

  M.relocateColonies(grid, colonies, affected, viewport, onLog)
  onProgress(grid, colonies)
  if yieldFn then
    yieldFn()
  end

  M.enforceAdjacency(grid, colonies, viewport, onLog)
  M.enforceConnectedGraph(grid, colonies, viewport, onLog)
  onProgress(grid, colonies)

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
