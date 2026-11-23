---
name: add-processblock-stage
description: Insert a DSP stage into the plugin's ProcessBlock chain — decides base-rate vs oversampled placement, wires prepare()/process()/updateParameters() in the right order, and keeps it real-time safe. Use when adding a viatordsp module (or juce::dsp node) into source/DSP/ProcessBlock.h.
---

# Add a stage to ProcessBlock

`viator::ProcessBlock` in `source/DSP/ProcessBlock.h` wraps the DSP chain. The processor owns it, and forwards `prepare` / `updateParameters` / `process` to it. If it doesn't exist yet, create it with those three methods and have `MonodromyDelayProcessor` call them from `prepareToPlay` and `processBlock`.

**Adding a stage should not touch `PluginProcessor`.** It lives entirely inside `ProcessBlock.h`.

If the stage needs a new automatable control, run the `add-parameter` flow first so `parameters.fooParam` exists. To create the module itself, use `scaffold-dsp-class`.

## Step 0 — decide: base rate or oversampled?

- **Oversampled** (between up/down sampling, if the chain has an oversampler): anything **nonlinear / harmonic-generating** — saturation, waveshaping, clipping, hard-knee dynamics.
- **Base rate**: **linear** stages — delay lines, filters, Hilbert pairs, phase rotation, gain, mix, DC blocking. A unit-magnitude twist in a feedback loop is linear, so the delay loop itself runs at base rate.

## Step 1 — include + declare the member

Add the include (std → JUCE → project order) and declare the member in the private section:

```cpp
#include "DSP/Delay/Foo.h"
...
    viatordsp::Foo<float> m_foo;
```

## Step 2 — `prepare()`

Prepare at the right spec and set all fixed/config values here (never in `process`):

- Base-rate stage: `m_foo.prepare(spec);`
- Oversampled stage: prepare with a copy of `spec` whose `sampleRate` and `maximumBlockSize` are multiplied by the oversampling factor.

All per-sample buffers/state must be sized now — `prepare` is the only place allocation is allowed.

## Step 3 — `process()` — placement matters

Insert the call in signal-flow order, passing the matching block and sample count:

```cpp
m_foo.process(juce::dsp::ProcessContextReplacing<float>(block), num_samples);
```

For an oversampled stage, use the up-sampled block and its own `getNumSamples()`, between `processSamplesUp` and `processSamplesDown`.

## Step 4 — `updateParameters()`

Read the cached param pointer and push it to the stage's setter:

```cpp
void updateParameters(const PluginParameters::parameters &parameters) {
    m_foo.setAmount(parameters.fooParam->get());
}
```

## Real-time safety checklist

- [ ] `prepare` sizes everything; `process` allocates nothing, takes no locks, does no I/O or logging.
- [ ] Block and sample count match the rate the stage was prepared at. Mismatched counts trip the module's `jassert`.
- [ ] Nonlinear → oversampled; linear → base rate.
- [ ] Params read via the typed `parameters` struct, smoothed inside the module.
- [ ] Ran `.clang-format`.
