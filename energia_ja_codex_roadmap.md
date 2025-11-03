# Energia Já — Implementation Roadmap (Codex Prompts)

This Markdown file provides **step-by-step prompts** to guide Codex (or similar assistants) in implementing the project *Energia Já* phase by phase.  
Each phase includes clear goals, files to edit, and expected behaviors.

---

## 🟢 Phase 0 — Core Game State (✅ Completed)
**Goal:** Ensure base state with metrics, grid, and win/lose rules.  
**File:** `lib/game/state/game_state.dart`

**Prompt for Codex:**
> Verify and ensure that `Metrics`, `CellModel`, and `GameState` are implemented as follows:  
> - `Metrics` includes: `acessoEnergia`, `limpa`, `tarifa`, `saude`, `educacao`, `desigualdade`, `clima`.  
> - `CellModel` has `Building b` (default: `vazio`) and `bool powered`.  
> - `GameState` has: `size`, `turno`, `orcamento`, `metrics`, `grid` (2D list of `CellModel`).  
> - Methods: `reset()`, `venceu()`, and `acabou()` implemented with:  
>   - Victory if: `acessoEnergia >= 0.80`, `limpa >= 0.80`, and `tarifa <= 1.0`.  
>   - Game over if: `turno > 20` or victory.  
> Return: Final diff of file.  
>
> **Commit message:** `feat(core): ensure baseline GameState with metrics, grid and win/lose rules`

---

## 🟢 Phase 1 — Initial HUD (✅ Completed)
**Goal:** Display top bar (metrics, budget, turns), build bar with construction buttons + remove toggle, snackbar for budget warning, and result bar.  
**File:** `lib/ui/hud.dart`

**Prompt for Codex:**
> Confirm that the HUD includes:  
> - Top bar with: Turn, Budget, Acesso, Limpa, Tarifa, Saúde, Educação, Melhor Limpa, Melhor Turno.  
> - Build bar with buttons (Solar, Eólica, Eficiência, Saneamento) and a toggle for **Remove mode**.  
> - Snackbar “Orçamento insuficiente” shown when `PlaceResult.semOrcamento`.  
> - Result bar at end with “Reiniciar” button.  
> Return: File diff.  
>
> **Commit message:** `feat(ui): initial HUD with metrics, build buttons, remove toggle and result bar`

---

## 🟠 Phase 2 — Build/Remove Logic & Costs
**Goal:** Implement placing/removing buildings with costs and result tracking.  
**File:** `lib/game/energy_game.dart`

**Prompt for Codex:**
> Implement construction/removal rules and integrate with HUD.  
> - Add `enum PlaceResult { ok, semOrcamento, invalido, removido }`.  
> - In `EnergyGame`, add:  
>   ```dart
>   late GameState state;
>   Building? selecionado;
>   bool removeMode = false;
>   PlaceResult? lastPlaceResult;
>   double bestClean = 0.0;
>   int bestTurn = 999;
>   ```  
> - Methods to add:  
>   - `double costOf(Building b)` → returns fixed costs.  
>   - `void restart()` → resets state and UI vars.  
>   - `PlaceResult placeAt(int x, int y)` → applies build/remove logic.  
>   - `void endTurn()` → increments turn and updates metrics.  
> - Call `_recomputeMetrics()` after any change.  
>
> **Commit message:** `feat(core): implement building placement, removal and budget logic`

---

## 🟠 Phase 3 — Metric Recalculation
**Goal:** Update metrics dynamically after each build/remove.  
**File:** `lib/game/energy_game.dart`

**Prompt for Codex:**
> Add `_recomputeMetrics()` inside `EnergyGame`:  
> - Count total cells, built cells, clean energy sources, etc.  
> - Update: `acessoEnergia`, `limpa`, `tarifa`, `saude`, `educacao`, `desigualdade`, `clima`.  
> - Clamp all between 0 and 1.  
> - Ensure it’s called by `placeAt()` and `endTurn()`.  
>
> **Commit message:** `feat(core): add dynamic metric recomputation after player actions`

---

## 🟡 Phase 4 — Grid Input Integration
**Goal:** Make taps on grid cells trigger building/removal.  
**File:** `lib/game/cell.dart`

**Prompt for Codex:**
> Modify tap handlers so tapping a cell calls:  
> ```dart
> gameRef.placeAt(cx, cy);
> ```  
> or removal when in removeMode.  
> Ensure correct mapping between screen position and grid index.  
>
> **Commit message:** `feat(input): connect grid cell taps to game placement logic`

---

## 🟢 Phase 5 — Next Turn Button (⏳ Pending)
**Goal:** Allow manual turn advancement from HUD.  
**File:** `lib/ui/hud.dart`

**Prompt for Codex:**
> Add a “Avançar turno” button at the end of `_buildBar(GameState s)` Row:  
> ```dart
> FilledButton(
>   onPressed: () => setState(() => widget.game.endTurn()),
>   child: const Text('Avançar turno'),
> ),
> ```  
> Return: full updated `hud.dart`.  
>
> **Commit message:** `feat(ui): add manual end-turn button in HUD`

---

## 🟡 Phase 6 — Best Record Persistence (✅ Partial)
**Goal:** Save/load best scores with shared_preferences.  
**File:** `lib/game/energy_game.dart`

**Prompt for Codex:**
> Add persistence for `bestClean` and `bestTurn`:  
> - Import `shared_preferences`.  
> - Implement `_loadProgress()` and `_saveProgress()` (store as doubles/ints).  
> - Call `_loadProgress()` in `onLoad()`, `_saveProgress()` in `endTurn()` when new record.  
>
> **Commit message:** `feat(progress): persist bestClean and bestTurn using shared_preferences`

---

## 🟡 Phase 7 — Asset Declaration
**Goal:** Ensure assets are declared for icons.  
**File:** `pubspec.yaml`

**Prompt for Codex:**
> In the `flutter:` section, ensure:  
> ```yaml
> assets:
>   - assets/images/icons/icon_solar.png
>   - assets/images/icons/icon_wind.png
>   - assets/images/icons/icon_efficiency.png
>   - assets/images/icons/icon_sanitation.png
> ```  
> Return: `pubspec.yaml` diff.  
>
> **Commit message:** `chore(assets): declare icon assets for HUD buttons`

---

## 🟠 Phase 8 — Balance Tuning
**Goal:** Adjust costs and metric weights for better gameplay balance.  
**File:** `lib/game/energy_game.dart`

**Prompt for Codex:**
> Tune numeric parameters in `_recomputeMetrics()`:  
> - Adjust efficiency, sanitation, and clean energy weight multipliers.  
> - Rebalance tariffs and inequality penalties for gameplay pacing.  
>
> **Commit message:** `balance: adjust metric weights and building costs for improved gameplay`

---

## ⚪ Phase 9 — UX Enhancements
**Goal:** Improve user feedback (button disable, tooltips, animations).  
**File:** `lib/ui/hud.dart`

**Prompt for Codex:**
> Add polish to HUD:  
> - Disable build buttons when insufficient budget.  
> - Add tooltips with cost/effect info.  
> - Use soft animations (e.g., highlight selected button).  
>
> **Commit message:** `feat(ui): add button states, tooltips and minor UX polish`

---

## ⚪ Phase 10 — Save/Load Full Game State
**Goal:** Allow full game persistence (turn, grid, metrics).  
**Files:** `lib/game/state/game_state.dart`, `lib/game/energy_game.dart`

**Prompt for Codex:**
> Implement save/load of full `GameState`:  
> - Serialize fields to JSON.  
> - Persist locally via `shared_preferences` or local file.  
> - Add `loadGame()` and `saveGame()` in `EnergyGame`.  
>
> **Commit message:** `feat(save): implement full save/load of game state`

---

## ⚪ Phase 11 — Automated Testing
**Goal:** Add tests for logic and metrics.  
**Files:** `test/` directory

**Prompt for Codex:**
> Write unit tests for:  
> - `placeAt()` (budget deduction, invalid placement, removal refunds).  
> - `_recomputeMetrics()` (metric evolution).  
> - `venceu()` and `acabou()`.  
> Use Dart’s `test` package.  
>
> **Commit message:** `test(core): add unit tests for placement and metric logic`
