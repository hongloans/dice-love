# Dice War (React) → Dice Love (Lua / Love2D)

This document explains how the MVP from `dev/dice-war` was translated into `dev/dice-love`, and where to extend the code.

## Project layout

```
dice-love/
  main.lua              # love.load / update / draw; timers; screen flow (≈ App.tsx)
  conf.lua              # window & identity
  game/
    constants.lua       # WIDTH×HEIGHT, colony caps, delays (TS constants)
    state.lua           # phase name reference (optional schema hints)
    colony.lua          # generateColonies, growColony (colonyGenerator.ts)
    rules.lua           # isAdjacent (gameLogic.ts)
    logic.lua           # createInitialState, rollDice, handleEndTurn, executeBattle, resolveBattleResultPhase
    ai.lua              # bot policy (App.tsx bot useEffect)
  render/
    board.lua           # grid + battle overlays (GameBoard.tsx canvas)
    ui.lua              # menu, loading, HUD, overlays (StartScreen, LoadingScreen, App chrome)
  input/
    mouse.lua           # pixel → cell index (GameBoard click mapping)
    keyboard.lua        # shortcuts (optional; React had none)
  utils/
    random.lua          # shuffle, sample (lodash)
    font.lua            # cached fonts
  MAPPING.md            # this file
```

## React concept → Lua mapping

| React / JS | Lua / Love2D |
|------------|----------------|
| `useState<GameState \| null>` | Single `app` table in `main.lua` (`gameState`, `mode`, timers, UI flags). |
| `useReducer` / immutable updates | In-place mutation of one `gameState` table inside `game/logic.lua` (same as TS shallow copy + shared `Map` references). |
| `useEffect` + `setTimeout(100)` (battle auto-clear, bot) | `love.update(dt)` decrements `battleTimer` / `botTimer` (`constants.BATTLE_RESULT_DELAY`, `BOT_ACTION_DELAY`). |
| `async createInitialState` + `await generateColonies` yields | Coroutine in `main.lua` + `coroutine.yield()` every 5 colonies (`colony.generateColonies`). |
| `LoadingScreen` + `onLog` | Same log strings; progress from `[INFO] Sector #NNN` and `[SUCCESS]`. |
| `onClick` on canvas | `love.mousepressed` → `ui.hitTestGame` + `input/mouse.pixelToCell`. |
| `executeBattle` in `App.tsx` | `logic.executeBattle(state, attackerId, defenderId)` (same rules). |
| `_.shuffle` / `_.sample` | `utils/random.lua` (`shuffle`, `sample`) via `love.math.random`. |
| `Math.random()` dice | `love.math.random(6)` in `logic.rollDice`. |
| 0-based grid indices | Preserved (`0 .. TOTAL_CELLS - 1`) to avoid off-by-one drift. |

## Rules parity checklist (from source)

- Grid **100×50**, colonies **8 cells**, up to **450** colonies (`game/constants.lua`, `game/colony.lua`).
- Initial ownership: shuffled colony IDs split evenly; **remainder** territories stay unclaimed (`ownerId == -1`), matching the TS loops.
- Extra starting dice: **one per colony in slice**, placed with random `sample` under cap **20**.
- Combat: roll **attacker.diceCount** vs **defender.diceCount** d6; **strict greater** wins for attacker; else defender holds territory, attacker reset to **1** die.
- Win: **tie** goes to defender (not strictly greater on attack).
- Post-win elimination: any player with **no colonies** is eliminated.
- Game over when **one** active player remains; last battle sets `phase` to `game-over` immediately (no `battle-result` phase in that frame), matching the TS spread order.
- End turn: gain **dice equal to colony count**, distributed randomly to colonies under **20**; advance to next **non-eliminated** player.
- Adjacency: **4-neighbor** on the flat grid (`game/rules.lua`).
- Selection after battle: cleared unless human still owns selected colony and **dice > 1** (`logic.resolveBattleResultPhase`).
- Bot: shuffle own colonies with **dice > 1**; adjacent enemies; pick **min enemy dice**; attack if `ownDice >= enemyDice`; else **end turn**; **100 ms** delay between actions (`main.lua` + `game/ai.lua`).

## Architectural decisions

1. **Pure data + functions** — `game/logic.lua` and `game/rules.lua` have no `love.graphics` imports; rendering is confined to `render/`.
2. **Constants in one place** — `game/constants.lua` avoids magic numbers in draw code (grid size still single source for logic + layout).
3. **Timers in `main.lua`** — mirrors React effects as explicit state (`battleTimer`, `botTimer`) so AI and battle resolution stay testable without the draw path.
4. **Coroutine loading** — keeps the UI responsive during generation without threads, analogous to `await` + `setTimeout(0)`.

## Extension points

### New features (gameplay)

- **`game/logic.lua`** — add phases (e.g. reinforcement cards), new win conditions, or combat variants; keep `executeBattle` / `handleEndTurn` as single entry points.
- **`game/rules.lua`** — alternate adjacency (diagonals), bridges, or terrain if the grid model grows.
- **`game/constants.lua`** — expose tuning (max dice, grid size) for scenarios.

### AI

- **`game/ai.lua`** — replace `chooseBotAction` with minimax, heuristics, or difficulty tiers; keep the return protocol (`"attack"`, ids, or `"end_turn"`) so `main.lua` stays thin.
- **`main.lua`** — adjust `BOT_ACTION_DELAY` or add separate delays per difficulty.

### Performance

- **`render/board.lua`** — today: one rectangle per cell (5000 draws). **Improvements:** canvas snapshot for static terrain, `SpriteBatch`, or mesh quads; dirty-rect only for changed cells after a battle.
- **`game/colony.lua`** — generation is O(colonies × cells); profiling hotspot is frontier `pairs` → consider array frontier + swap-pop if needed.

### UI / polish

- **`render/ui.lua`** — layout is computed from window size; safe place for scaling, themes, and localization.
- **`utils/font.lua`** — swap in bitmap fonts or SDF text.

### Persistence / networking

- Add **`game/state.lua`** (or `save.lua`) to serialize `gameState` + RNG seed if you add deterministic replays.

## Running

From the project directory:

```bash
love .
```

Ensure [Love2D 11.x](https://love2d.org/) is installed.
