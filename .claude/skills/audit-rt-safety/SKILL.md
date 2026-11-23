---
name: audit-rt-safety
description: Audit the plugin's processBlock + DSP chain for audio-thread hazards (heap allocation, host block-size overrun, NaN/Inf, unstable feedback) and apply the canonical fix for each. Use when reviewing or hardening the real-time path, or when the plugin misbehaves in a specific host (FL Studio, large/odd block sizes).
---

# Audit real-time safety

Walk `source/PluginProcessor.cpp` (`prepareToPlay` / `processBlock`), `source/DSP/ProcessBlock.h` (`prepare` / `process` / `updateParameters`), and every `source/DSP` module the chain includes, worst-first, against the hazards below. Report findings ranked by severity as `file:line — tell → fix`; then apply the fixes.

## The one rule everything derives from

`process`/`processBlock` and anything they call must not allocate on the heap, take a lock, do file I/O, or log. All allocation and sizing happens in `prepare` / `prepareToPlay`. Most findings are a violation of this.

## Hazard 1 (high) — heap allocation on the audio thread

**Tells:** in `process`/`updateParameters` or anything they reach — `std::vector`/`std::string` construction, `std::make_unique`, `.resize()` that can grow, `AudioBuffer::setSize`/`makeCopyOf` where the source can exceed capacity, a delay line resized when the Time parameter moves, or a per-block call to a setter that rebuilds a container.

**Fix:**
- Size delay buffers for the maximum delay time in `prepare`; moving Time only changes the read offset.
- Cache built-once data as a member populated in `prepare`; return it by `const&`.
- Gate rare reconfiguration on actual change — e.g. `if (mode != m_mode) setMode(mode);`.

## Hazard 2 (high) — host sends a bigger block than prepareToPlay reported

Hosts (FL Studio notably) can call `processBlock` with more samples than the `samplesPerBlock` given to `prepareToPlay`. Anything sized to that value overruns: `juce::dsp::Oversampling::initProcessing`, a dry buffer for the Mix control, scratch buffers.

**Tells:** `initProcessing(samplesPerBlock)`, `setSize(ch, samplesPerBlock)`, any buffer whose size traces back to the prepared block size, with no chunking guard in `processBlock`.

**Fix:** cache the prepared size (`int m_prepared_block_size{0};` set in `prepareToPlay`), move the per-block body into `processChunk(juce::AudioBuffer<float> &)`, and have `processBlock` walk the buffer in chunks of at most that size using a non-owning view (`juce::AudioBuffer<float>(buffer.getArrayOfWritePointers(), num_channels, start, length)`), so nothing is copied or allocated. Keep the one-time channel setup (clearing extra outputs) in `processBlock` before the chunk loop.

## Hazard 3 (high) — runaway or non-finite feedback

A feedback delay is one bad coefficient away from blowing up, and a NaN that enters the loop stays there forever.

**Tells:** loop gain that can reach or exceed 1 (Feedback range up to 1.0, gain applied before a twist whose magnitude isn't exactly 1, a damping filter with gain above unity anywhere in its response), a complex twist computed as `r = a + bi` and not normalized, unsmoothed jumps in twist phase θ, or no finite check on the output.

**Fix:**
- Clamp loop gain `g` strictly below 1 and keep any in-loop filter at or below unity gain.
- Build twists as `std::polar(1, θ)` (or renormalize) so `|r| = 1` exactly, including the chaos-map path.
- Smooth θ and g; a phase step inside the loop clicks.
- Add a single non-finite flush on the output, and reset the loop state if one is found:

```cpp
for (auto ch = 0; ch < buffer.getNumChannels(); ++ch)
    for (auto &sample : juce::Span(buffer.getWritePointer(ch), (size_t) buffer.getNumSamples()))
        if (! std::isfinite(sample)) sample = 0.0f;
```

`ScopedNoDenormals` kills denormals but not NaN/Inf.

## Hazard 4 (low / robustness) — check but usually just report

- **Oversized delay lines.** Allocating far more buffer than the Time range needs. Harmless (prepare-time), worth a note.
- **Per-block coefficient recompute** for params that rarely change — gate on change if it shows on a profile.
- **Sample-rate assumptions.** Delay lengths or Hilbert coefficients hard-coded for 44.1/48 kHz.

## Report + apply checklist

- [ ] Walked `PluginProcessor.cpp`, `DSP/ProcessBlock.h`, and every module the chain includes.
- [ ] Findings reported worst-first as `file:line — tell → fix`.
- [ ] Did not build or run (Landon does that); did not commit unless asked.
- [ ] Matched surrounding style / `.clang-format`.
