---
name: add-parameter
description: Add (or rename) an automatable APVTS parameter — wires Engine/Parameters.h, createParameterLayout(), the DSP/processor read, and the GUI control + attachment so they stay in sync. Use when adding a knob/button/menu backed by an AudioProcessorValueTreeState parameter.
---

# Add an APVTS parameter

A new automatable parameter touches **four** places. Miss one and the cached pointer is null or the control does nothing — there is no compile error. Do all four, matching the parameter's JUCE subtype across every step.

Pick the subtype up front — it must be identical everywhere:

| Kind        | Layout type                  | Pointer / cast type           | Read with      |
| ----------- | ---------------------------- | ----------------------------- | -------------- |
| continuous  | `juce::AudioParameterFloat`  | `juce::AudioParameterFloat*`  | `->get()`      |
| on/off      | `juce::AudioParameterBool`   | `juce::AudioParameterBool*`   | `->get()`      |
| menu/choice | `juce::AudioParameterChoice` | `juce::AudioParameterChoice*` | `->getIndex()` |

## 1. `source/Engine/Parameters.h` — three edits

If the file doesn't exist yet, create it with `#pragma once`, `#include <juce_audio_processors/juce_audio_processors.h>`, a `namespace viator::PluginParameters`, and a `struct parameters` whose `explicit parameters(const juce::AudioProcessorValueTreeState &tree)` constructor caches the pointers. The processor holds a `std::unique_ptr<PluginParameters::parameters>` built after `m_tree_state` in its constructor.

Add the ID/Name pair (both `inline const juce::String`, ID string equals the variable name `fooID`):

```cpp
inline const juce::String fooID = "fooID";
inline const juce::String fooName = "Foo";
```

In the `parameters` struct constructor, cache the pointer:

```cpp
fooParam = dynamic_cast<juce::AudioParameterFloat *>(tree.getParameter(fooID));
```

And declare the member (brace-init to null):

```cpp
juce::AudioParameterFloat *fooParam{nullptr};
```

## 2. `createParameterLayout()` in `source/PluginProcessor.cpp`

Add the parameter. **Always include the `, 1` version hint** in `ParameterID`:

```cpp
layout.add(std::make_unique<juce::AudioParameterFloat>(
    juce::ParameterID{PluginParameters::fooID, 1},
    PluginParameters::fooName, 0.0f, 20.0f, 0.0f));
```

Variants:
- **Skewed range**: build a `juce::NormalisableRange<float>(min, max, step)`, call `range.setSkewForCentre(centre)`, pass `range` in place of the min/max/default triple, then the default.
- **Bool**: `std::make_unique<juce::AudioParameterBool>(juce::ParameterID{fooID, 1}, fooName, false)`.
- **Choice**: `std::make_unique<juce::AudioParameterChoice>(juce::ParameterID{fooID, 1}, fooName, juce::StringArray{"A", "B"}, 0)`.

Keep the default inside the range or the APVTS asserts.

## 3. Consume the value

Read it in `ProcessBlock::updateParameters(const PluginParameters::parameters &parameters)` and call a DSP setter — never look up APVTS by string on the audio thread, and never allocate there:

```cpp
const auto foo = parameters.fooParam->get();
m_some_module.setFoo(foo);
```

Plugin-global params (bypass, oversampling) are read in the processor alongside the other global handling.

## 4. GUI control + attachment

- Add the control (`juce::Slider` / `juce::Button` / `juce::ComboBox`) to the editor (or the component that owns it) and `addAndMakeVisible(it)`.
- Declare a `unique_ptr` attachment member:
  ```cpp
  std::unique_ptr<juce::AudioProcessorValueTreeState::SliderAttachment> m_foo_attach;
  ```
- Construct it (ties the control to the param by ID):
  ```cpp
  m_foo_attach = std::make_unique<juce::AudioProcessorValueTreeState::SliderAttachment>(
      tree_state, PluginParameters::fooID, m_foo_slider);
  ```
  Use `ButtonAttachment` for bool toggles, `ComboBoxAttachment` for choices.

## Checklist

- [ ] Subtype identical in all of: Parameters.h cast, Parameters.h member, layout `make_unique`, attachment.
- [ ] `, 1` version hint present in `ParameterID`.
- [ ] Default value within range; Choice default index valid.
- [ ] Value read off the cached `parameters.fooParam` pointer (typed), not by string lookup on the audio thread.
- [ ] No heap alloc / lock / I/O added to `process`/`processBlock`.
- [ ] Attachment stored in a member `unique_ptr` (a local is destroyed immediately and the control goes dead).
- [ ] Ran `.clang-format`.

## Renaming a parameter

The ID string is the persistence key — changing `"fooID"` breaks existing sessions/presets that stored the old ID. Change only the `Name` (display) unless you intend to break saved state. Update every occurrence of the variable in all four locations above.
