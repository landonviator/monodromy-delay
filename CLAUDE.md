# CLAUDE.md

Guidance for Claude Code when working in this repo. Kept short on purpose — detail lives in the skills under `.claude/skills/`.

Monodromy Delay is an open-source (AGPLv3) JUCE delay whose feedback loop multiplies the signal by a twist `r` on every pass, made for the Freqlab plugin jam. The design, build order, and paper plan live in the research vault note `~/dev/research/notes/Monodromy Delay.md`.

## Rules

- **Autonomous mode**: no GO gate — act on requests without waiting for explicit approval. Guardrails are enforced by the `PreToolUse` guard hook (`.claude/hooks/pre-tool-guard.sh`), which hard-blocks irreversible actions: destructive git (`reset --hard`, `clean -f`, `rebase`, `branch -D`, `checkout/restore .`), recursive `rm`, `sudo`/`dd`/`mkfs`, touching/emptying the macOS Trash, and writes to the JUCE submodule or build output.
- **Question vs. action**: if Landon asks a question or is exploring an idea, answer it — do **not** start writing code or making edits. Only take action when he makes a statement or gives a directive. A question clearly phrased as a request to act ("can you fix X?") counts as a directive; when it's genuinely ambiguous, answer first and ask before editing.
- **Do the asked-for thing, not the ceremony around it**: deliver the core artifact the request names and stop. Don't spin up eval harnesses, benchmarks, subagent fan-outs, or background jobs unless Landon explicitly asks. If deeper validation might help, offer it in one line.
- Do not build or run the program, and do not ask to — Landon builds and runs it himself.
- Never push git changes unless explicitly told to. Don't commit unless explicitly asked either.
- Never add a `Co-Authored-By` trailer (or any co-author) to commits. Every commit must be authored solely by Landon Viator.
- After each commit, update `ROADMAP.md` — move finished items to `CHANGELOG.md` (newest first), and add any new follow-ups under Now/Next/Someday. Keep each roadmap item self-contained since the `SessionStart` hook injects the `- [ ]` lines without their headers.
- Record a notable design choice the code can't show in `docs/decisions.md` (create it when first needed). Docs that just narrate the code aren't worth keeping.
- **Real-time safety in `processBlock`**: never allocate on the heap, take locks, do file I/O, or log on the audio thread. Pre-allocate in `prepareToPlay`, delay buffers included.
- **Loop stability**: keep loop gain strictly below 1 and every twist at exactly unit magnitude; smooth twist phase and feedback changes.
- **Keep `Parameters.h` and `createParameterLayout()` in sync**: adding or renaming a parameter means updating both, or the cached pointers will be null. See the `add-parameter` skill.
- Never edit generated build output (`cmake-build-*/`, `build/`).
- Don't modify the `libs/JUCE` submodule.
- **Open source**: everything committed here is public. Don't copy code from Plugin-Vault's `libs/dsp` or `libs/gui` (or any other closed repo) into this one without Landon saying so.
- Match `.clang-format` before considering an edit done.

## Build

JUCE is a submodule — initialize before any build: `git submodule update --init --recursive`.

```bash
cmake -B build
cmake --build build --config Release
```

## Layout

- `source/PluginProcessor.*`, `source/PluginEditor.*` — `viator::MonodromyDelayProcessor` / `MonodromyDelayEditor`.
- `source/Engine/Parameters.h` — parameter IDs/names and the cached `parameters` pointer struct.
- `source/DSP/ProcessBlock.h` — the DSP chain the processor forwards to.
- `source/DSP/<Category>/<Name>.{h,cpp}` — DSP modules (`viatordsp` namespace). See `dsp-module` / `scaffold-dsp-class`.

## Code style

- **Namespaces**: `viator` for plugin code, `viatordsp` for DSP modules.
- **Types & files**: PascalCase, **no underscores**; keep acronyms fully capitalized (`SVFilter`, `DCBlocker`). Each file is named for its primary class.
- **Naming**: `m_` prefix for members (`m_tree_state`); `snake_case` locals/params (`sample_rate`); `camelCase` methods (`prepareToPlay`); `k`-prefixed enum constants with a trailing `num_*` count (`kLeft`, `num_channels`).
- **Pointers**: `*` on the name, brace-init raw pointers (`juce::AudioParameterFloat *gainParam{nullptr};`).
- **Parameters**: paired `inline const juce::String fooID = "fooID";` / `fooName`, plus typed `juce::AudioParameter*` pointers in the `parameters` struct.
- **Immutability**: `constexpr` if compile-time constant, else `const`, else mutable — for locals, members, read-only params, and non-mutating methods.
- **Constants**: name non-trivial numeric literals as `constexpr` (group DSP magic numbers in a `Params` struct); bare `0`/`1` identities may stay inline.
- **`auto`**: liberal — use `auto`/`const auto` when the type is clear from the initializer.
- **const style**: west const (`const SampleType`, `const juce::String&`).
- **Init**: brace-init `{}` by default; in-class default member initializers; constructors `= default` where possible.
- **Attributes**: `[[nodiscard]]` on pure getters; `noexcept` on audio-thread/`process` functions; `override` always (never repeat `virtual`); `final` on leaf classes.
- **Enums**: unscoped `k`-prefixed `enum` (trailing `num_*` count) by default; scoped `enum class` when a variable holds that enum type.
- **Param passing**: objects/containers by `const&`; small arithmetic types by value in audio/per-sample paths.
- **`struct` vs `class`**: `struct` for passive data aggregates; `class` for behavior/invariants.
- **Includes**: standard library → third-party/JUCE → project (own header first in a `.cpp`).
- **Headers**: `#pragma once`. **Standard**: C++17.
- **Comments**: never add comments to code unless Landon explicitly asks for them. Preserve existing comments when editing, and never strip a license/attribution header.
- Full rationale, examples, and edge cases: the `code-style` skill.

## Pointers

- `ROADMAP.md` — open work (Now/Next/Someday). `CHANGELOG.md` — finished work.
- Research vault at `~/dev/research` — log design thinking and research findings in `notes/Monodromy Delay.md` or a new concept note there, not here. Search it via `catalog/index.md` first, and rerun `scripts/build_catalog.py` after adding a concept note.
