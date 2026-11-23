---
name: audit-daw-compat
description: Audit a plugin's host-contract surface (bus/channel-layout negotiation, latency/PDC reporting, APVTS state save-restore, tail/program/MIDI reporting) for cross-DAW compatibility bugs and apply the canonical fix for each. Use when a plugin loads or behaves differently across DAWs — works in Reaper but not Logic/FL/Cubase/Pro Tools, wrong delay compensation, presets or window size not recalling, AU validation (auval) failing, mono/stereo or odd channel layouts crashing — or when hardening a plugin before release. This is the off-audio-thread companion to audit-rt-safety; reach for it whenever DAW/host compatibility, plugin format conformance, or state persistence is in question, even if the user doesn't name a specific host.
---

# Audit DAW / host compatibility

Walk `source/PluginProcessor.cpp` and `.h` (constructor,
`prepareToPlay`, `isBusesLayoutSupported`, `processBlock`, `getStateInformation` /
`setStateInformation`, and the reporting getters), plus `source/DSP/ProcessBlock.h` for
anything that adds latency (oversampling, lookahead). Report findings worst-first
as `file:line — tell → fix`, then apply the fixes.

**This is the message-thread / host-contract counterpart to `audit-rt-safety`.**
That skill owns the audio thread (no heap/locks/NaN in `processBlock`); this one
owns how the plugin negotiates with the DAW *around* the audio thread. The one
place they overlap is Hazard 1: an under-constrained bus layout is a host-contract
bug whose payoff is an audio-thread array overrun — flag it here, and let the
RT-safety pass assume the layout is already bounded.

## The principle everything derives from

A plugin is a contract with the host: it must tell the host the truth about what
it can do (which channel layouts, how much latency, how many programs, whether it
tails) and it must round-trip its own state losslessly. Hosts differ in how
strictly they hold you to that contract — Reaper is forgiving, Logic/`auval` and
Pro Tools are strict — so a contract violation often shows up as "works on my DAW,
broken on theirs." Most findings below are a place where the plugin lies to, or
mishandles, the host.

## Hazard 1 (high) — bus layout constrains only one side

`isBusesLayoutSupported` that checks only the **output** set (or only the input)
lets a host negotiate a layout wider than the plugin is built for. Because the
buffer JUCE hands `processBlock` has `jmax(numInputs, numOutputs)` channels, an
unchecked wide input bus produces a buffer with more channels than the plugin's
fixed-size per-channel state — the `num_channels`-sized metering/smoother
`std::array`s — and the per-channel loops read/write past the end on the audio
thread. It also fails `auval`, which probes layouts the plugin claims to accept.

**Tells:** `isBusesLayoutSupported` references `getMainOutputChannelSet()` without
a matching `getMainInputChannelSet()` check (or vice-versa); per-channel state
sized to a fixed `num_channels` while the layout check doesn't bound the buffer to
that width; `processBlock` loops on `buffer.getNumChannels()` indexing those
fixed arrays.

**Fix:** constrain **both** the main input and main output to the sets the plugin
actually supports, so the buffer width can never exceed the fixed state:

```cpp
const auto supported = [](const juce::AudioChannelSet &set) {
  return set == juce::AudioChannelSet::mono() ||
         set == juce::AudioChannelSet::stereo();
};
const auto &mainIn = layouts.getMainInputChannelSet();
return supported(layouts.getMainOutputChannelSet()) &&
       (mainIn.isDisabled() || supported(mainIn));
```

Then confirm `processBlock` handles the asymmetric layouts the check still allows:
clear output-only channels when `out > in`, fan mono→stereo for 1-in/2-out, and
document the 2-in/1-out case (the host reads channel 0). Keep this channel fix-up
before any chunk loop / `processChunk` split.

## Hazard 2 (high) — latency not reported, or reported off the wrong thread

Anything that delays the signal — `juce::dsp::Oversampling`, a lookahead limiter,
a linear-phase filter — adds latency the host must compensate for. If the plugin
never calls `setLatencySamples`, the processed signal drifts against dry/parallel
paths; the misalignment is worst in phase-critical routing and inconsistent when
the latency is toggleable (HQ/oversampling on vs. off). And `setLatencySamples`
notifies the host, so it must run on the **message thread** — calling it from
`processBlock`/`parameterChanged` (which can fire on the audio thread under host
automation) is itself a violation.

**Tells:** `ProcessBlock`/chain constructs an oversampler or lookahead buffer but
no `setLatencySamples` anywhere; latency reported once but the source can change at
runtime (a bypassable oversampler) without re-reporting; `setLatencySamples` called
directly inside `processBlock` or an APVTS parameter callback.

**Fix:** expose the latency from the DSP at base rate and report it from the
message thread. For the oversampling case, add to `ProcessBlock`:

```cpp
[[nodiscard]] int getLatencySamples() const noexcept {
  return m_oversampler ? juce::roundToInt(m_oversampler->getLatencyInSamples()) : 0;
}
```

Report it in `prepareToPlay` (message thread, DSP prepared). For a *toggleable*
source, make the processor an `AudioProcessorValueTreeState::Listener` **and** a
`juce::AsyncUpdater`: register the toggle param in the constructor (unregister +
`cancelPendingUpdate()` in the destructor), `triggerAsyncUpdate()` from
`parameterChanged`, and do the actual `setLatencySamples(...)` in
`handleAsyncUpdate()`. Toggling then re-triggers host PDC, which is the correct,
expected behavior — the alternative (silent drift) is the bug.

## Hazard 3 (high) — state save/restore mutates or grows the live tree

`getStateInformation` is called on every host save (some hosts poll it), so it
must be idempotent and must not touch the live APVTS `ValueTree`. The classic
bug: `appendChild(m_variable_tree, nullptr)` onto the **live** tree
every save, which duplicates the child (or re-parents it, tripping a `jassert` in
debug) and bloats the stored state across a save→load→save cycle. A sibling bug is
"snap-on-copy, write-original" — building a cleaned copy but then serializing the
untouched live tree, so the cleanup is dead code.

**Tells:** `getStateInformation` calls `appendChild`/`setProperty` on
`getTreeState().state` (not a copy); it `createCopy()`s but then writes the
original to the stream; `setStateInformation` assigns `getChildWithName(...)`
without checking validity, so a foreign/older state leaves a member tree invalid.

**Fix:** serialize a copy, dedupe the auxiliary child, write the copy:

```cpp
auto state = getTreeState().state.createCopy();
state.removeChild(state.getChildWithName(m_variable_tree.getType()), nullptr);
state.appendChild(m_variable_tree.createCopy(), nullptr);
// ...snap near-zero values on `state`, skipping nodes without a "value" prop...
juce::MemoryOutputStream stream(destData, false);
state.writeToStream(stream);
```

In `setStateInformation`, only adopt a loaded auxiliary child when it
`isValid()`, so an older or third-party state can't leave the member tree broken.
APVTS restores missing parameters at their defaults, so forward/backward
compatibility comes for free **as long as parameter IDs stay stable** (see
Hazard 4).

## Hazard 4 (low / robustness) — reporting-contract mismatches

Check these, report them, fix where they matter for the plugin:

- **`getTailLengthSeconds()` returns 0 but the plugin tails.** Reverb, delay,
  long release, or a continuous noise/hiss bed means output isn't silent when
  input is. A 0 tail lets some hosts suspend `processBlock` on idle tracks and
  gate the tail. Report a realistic tail (or a small nonzero value for an
  always-on noise floor).
- **`getNumPrograms()` returns 0.** Some hosts cope badly with zero programs;
  return at least 1 even if programs aren't implemented.
- **MIDI flags inconsistent with the plugin.** `acceptsMidi` / `producesMidi` /
  `isMidiEffect` should match the `JucePlugin_*` build defines and the actual bus
  config — an effect that claims MIDI I/O it doesn't use confuses host routing.
- **Parameter-ID stability.** Parameters must use versioned
  `juce::ParameterID{id, 1}` and stable string IDs; renaming an ID silently breaks
  every saved preset and host automation lane that referenced it. Adding a
  parameter listener without a matching `removeParameterListener` in the
  destructor is a dangling-listener hazard.
- **Double-precision.** Leaving `supportsDoublePrecisionProcessing()` at its
  default (false) is fine — JUCE transparently converts for 64-bit hosts. It's
  only a bug if the plugin *overrides* it to true without providing the
  `processBlock(AudioBuffer<double>&, ...)` overload.

## Report + apply checklist

- [ ] Walked `PluginProcessor.cpp`/`.h` (ctor/dtor, `prepareToPlay`,
      `isBusesLayoutSupported`, `processBlock`, `getStateInformation` /
      `setStateInformation`, reporting getters) and `ProcessBlock.h` for
      latency sources.
- [ ] Findings reported worst-first as `file:line — tell → fix`.
- [ ] Bus layout bounds the buffer width to the fixed per-channel state (both
      sides constrained); latency reported and updated off the audio thread;
      state round-trips on a copy without growing.
- [ ] Did not build or run (Landon does that); did not commit unless asked.
- [ ] Matched surrounding style / `.clang-format`.
