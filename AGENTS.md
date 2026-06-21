# AGENTS.md

## Purpose

This document defines the mandatory quality standards for any code generated fully or partially by Large Language Models (LLMs — Cursor, Copilot, ChatGPT, or similar) within my Godot projects.

This policy applies to:
- Code generated via Cursor (Tab, Cmd+K, Agent/Composer mode)
- Code produced by autonomous coding agents
- Refactors or modifications suggested by LLMs
- GDScript, shaders, and `.tres`/`.tscn` structural edits suggested by LLMs

LLM-generated code is **not trusted by default** and must satisfy the validation rules below before it is considered done.

This is a solo-developer project: there is no second reviewer and no CI pipeline. Every "human reviewer" requirement below is satisfied by **me, reviewing my own diffs before accepting them** — not skipped.

---

# 1. Mandatory Self-Review

1. All LLM-generated code MUST be reviewed by me before being accepted, every time — even small Tab-completions that touch gameplay logic.
2. No diff is auto-accepted. Cursor's "Accept All" on multi-file Agent changes is NOT allowed without reading each file's diff first.
3. I am fully responsible for:
   - Correctness
   - Security
   - Performance
   - Architectural consistency
4. If I cannot explain what the generated code does, it MUST NOT be accepted. Rewrite the prompt or rewrite the code by hand instead.

---

# 2. Test Coverage Requirements

Automated test coverage thresholds (90%/80%/95% style) do not apply here — there is no test suite by default in this kind of project, and chasing coverage on gameplay code produces theater, not safety.

Instead:

- Any non-trivial system (combat, inventory, save/load, dialogue state, anything touching persistent player data) SHOULD have at least a manual test checklist (a comment block or a `tests/` notes file) describing what was verified by hand in the editor.
- If/when GUT (Godot Unit Test) or another framework is introduced for a specific project, that project's own AGENTS.md should declare it and define real thresholds — this generic baseline does not assume one exists.
- LLM-generated code that silently breaks previously-working behavior (a scene that loaded fine now errors, a signal that used to fire no longer does) MUST be rejected and fixed before moving on, regardless of whether a formal test exists.

---

# 3. Cyclomatic Complexity Limits

LLMs frequently generate overly complex functions. Limits apply, adjusted for gameplay/state-machine code which is naturally more branchy than typical backend logic:

- Recommended per function: ≤ 10
- Maximum allowed per function: 15
- \> 15 requires mandatory refactor before accepting the change
- \> 20 is strictly forbidden

Refactor by:
- Splitting large functions
- Extracting helper functions or reusable components (nodes/classes with `class_name`)
- Replacing deeply nested `if/elif` dialogue/state logic with an explicit state machine (`enum` + `match`)
- Avoid premature polymorphism for one-off cases — in GDScript, an extra subclass hierarchy is often worse than a clear `match`

---

# 4. Godot/Cursor-Specific Correctness Requirements

LLM-generated GDScript MUST undergo explicit correctness validation before being accepted — this replaces generic "security review" as the highest-priority gate for this kind of project:

Review MUST verify:

- No Godot 3.x syntax leaked in (`yield()`, `onready` without `@`, `export(TYPE)` without `@`, string-based `connect()`, `.instance()` instead of `.instantiate()`)
- No invented/hallucinated nodes, methods, or properties — if Cursor wasn't certain an API exists in the project's Godot version, it should have flagged that, not asserted it confidently
- No reference to Autoloads, signals, or groups that don't actually exist in the project
- Proper input validation on anything that touches save data, user-entered text, or external files (avoid trusting malformed save files crashing the game)
- No hardcoded secrets if the project ever talks to a backend/API (API keys, leaderboard tokens, analytics keys) — these belong in environment-specific config excluded from version control, never inline in a script
- Safe error handling around file I/O (save/load) — a corrupted or missing save file must not crash the game on boot
- No sensitive data (player emails, device IDs, anything personally identifying) written into `print()`/log output

If correctness is unclear, the code MUST be rejected and re-prompted with more context rather than accepted "to see if it works."

---

# 5. Architectural Compliance

LLM-generated code MUST:

- Respect the project's existing scene/script structure (see each project's own AGENTS.md for its specific folder layout)
- Not introduce circular dependencies between Autoloads
- Not bypass the project's data layer — e.g. reaching into another scene's internal nodes via fragile `get_node("../../X")` paths instead of using signals, exported references, or unique names (`%Node`)
- Not introduce unnecessary new Autoloads when a local node or a passed reference would do
- Not duplicate logic that already exists as a component/resource elsewhere in the project

If LLM output conflicts with the existing architecture, it MUST be rewritten — Cursor does not get to silently "improve" structure while doing an unrelated task; structural changes are called out explicitly and done as their own step.

---

# 6. Dependency Policy

LLM-generated code MUST NOT:

- Add Godot Asset Library plugins/addons without explicit justification (what it solves, why hand-rolling it isn't simpler)
- Upgrade the Godot minor/major version, or bump addon versions, on its own initiative
- Introduce unmaintained or abandoned addons (check last-updated date before suggesting one)

All new dependencies require my explicit approval before being added to `addons/` or `project.godot`.

---

# 7. Code Quality Requirements

Generated code MUST:

- Be readable and maintainable — favor clarity over cleverness, this is GDScript, not a code-golf exercise
- Use descriptive naming (`snake_case` functions/variables, `PascalCase` classes/nodes, `CONSTANT_CASE` constants)
- Use static typing wherever possible (`var health: int`, `func heal(amount: int) -> void:`)
- Avoid dead code and unused imports/preloads
- Follow whatever formatting the project already uses (consistent indentation, consistent comment language within a file)

Generated code MUST NOT:

- Contain large commented-out code blocks
- Include placeholder `# TODO` logic left inside paths that are supposed to be finished/shippable
- Contain speculative optimizations for problems that don't exist yet (premature object pooling, premature multithreading)
- Leave stray `print()` debug statements in code presented as done

---

# 8. Performance Responsibility

LLM-generated code MUST:

- Avoid instantiating/freeing nodes inside `_process`/`_physics_process` loops — use object pooling for frequently spawned things (projectiles, particles, hit effects)
- Use `_physics_process` for movement/physics, `_process` for non-physics visual/UI logic — not interchangeably
- Avoid N+1-style patterns (e.g. looping over all nodes in a group every frame when a signal-based approach would do)
- Avoid unnecessary heavy lookups in hot paths (`get_node()` with long paths called every frame instead of cached `@onready` references)

Performance-sensitive systems (large TileMaps, many simultaneous AI agents, particle-heavy effects) SHOULD be profiled in the Godot profiler if a slowdown is suspected, not guessed at.

---

# 9. Traceability

For any non-trivial LLM-assisted change (multi-file Agent/Composer edits, anything touching save data or core systems), I SHOULD:

- Note in a commit message that the change was LLM-assisted
- Keep the prompt for non-trivial generations if it required real back-and-forth, in case the same bug pattern shows up again
- Briefly note how it was validated (played through manually, checked X scene in editor, etc.)

This is for my own future debugging, not for external audit — but skipping it is how "why did I write this" debt builds up.

---

# 10. Local Enforcement (no CI)

There is no CI pipeline for most of these solo projects. In its place:

- Before considering a change "done," open the project in the Godot editor and actually run the affected scene(s) — a script with no syntax errors is not the same as a script that works.
- Check the Godot **Output** and **Debugger** panels for new warnings/errors after any Cursor Agent change, not just the scene you were focused on — multi-file edits can silently break an unrelated scene.
- If a project later adds CI (e.g. headless Godot export checks, GUT tests in GitHub Actions), that project's own AGENTS.md should document it — this baseline assumes none exists.
- No bypassing whatever local checks *do* exist (linter, `gdformat`, export validation) just because no one else will see the diff.

---

# 11. Responsibility Model

LLMs are productivity tools.

They are not:
- Autonomous decision-makers on game design or architecture
- Authorities on what Godot APIs currently exist
- Security auditors
- Performance experts

Final responsibility always belongs to me, the human developer — Cursor accelerates typing and exploration, it doesn't own the decisions.

---

# 12. Guiding Principle

Speed without quality increases long-term cost — and on a solo project, there's no one else to catch what slips through.

LLM-generated code is acceptable only when it:
- Improves my actual iteration speed (not just produces more code faster)
- Maintains system integrity (doesn't quietly break what already worked)
- Does not introduce technical debt I won't recognize in three months
- Meets or exceeds what I'd write by hand, given the same time
