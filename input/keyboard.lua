--- Optional shortcuts mirroring primary UI actions.

local M = {}

--- Returns: "end_turn" | "escape" | nil
--- Note: "g" grid toggle is handled in main.lua (play mode only).
function M.actionForKey(key)
  if key == "return" or key == "space" then
    return "end_turn"
  end
  if key == "escape" then
    return "escape"
  end
  return nil
end

return M
