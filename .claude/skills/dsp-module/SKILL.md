---
name: dsp-module
description: Pattern for writing a DSP class in source/DSP (viatordsp namespace) — template<SampleType>, header/cpp split, prepare/process/smoothers. Use when adding or reviewing a DSP module.
---

# Writing a DSP class

DSP modules live in `source/DSP/<Category>/<Name>.{h,cpp}` in namespace `viatordsp`, so they can move into Plugin-Vault's `libs/dsp` later without a rename. Plugin glue (processor, editor, `ProcessBlock`) stays in `viator`. Use `scaffold-dsp-class` to stub one out.

- **Templated on sample type**: `template <typename SampleType> class Foo final` in namespace `viatordsp`. At the bottom of the `.cpp`, explicitly instantiate both variants:
  ```cpp
  template class Foo<float>;
  template class Foo<double>;
  ```
- **Header/cpp split**: heavy/cold methods (`prepare`, parameter setters) are declared in the `.h` and defined in the `.cpp`. The hot-path `process()` stays **inline in the header** so it can be templated on the `ProcessContext` and inlined by the compiler.
- **Lifecycle**: default constructor/destructor; a `void prepare(const juce::dsp::ProcessSpec& spec)` that computes sample-rate-dependent constants, initializes smoothers, and applies default parameter values. All per-sample buffers/state (delay lines included) are sized here, never in `process()`.
- **`process(context)`**: get input/output blocks, `jassert` channel/sample counts match, then loop channels then samples. Pull smoothed parameter values per sample via `getNextValue()` and delegate the math to a private `processSample(channel, x)`.
- **Smoothed parameters**: store as `std::array<juce::SmoothedValue<SampleType>, 2>` (one per channel). A private `initSmoother(...)` resets each to a ~0.02 s ramp in `prepare`.
- **Parameter setters**: each public `setX(value)` clamps with `juce::jlimit` against a nested range struct of `static constexpr SampleType min/max`, applies any scaling, then `setTargetValue` on every smoother in the array. Setters are safe to call from the message thread.
- **Mode/type selection**: expose a `k`-prefixed `enum FilterType { ... }` and branch on the stored type inside `processSample` via `switch`.
- **Per-channel state** (filter memory, delay buffers, etc.) is indexed by channel (`m_z1[channel]`), sized for the channel count.
