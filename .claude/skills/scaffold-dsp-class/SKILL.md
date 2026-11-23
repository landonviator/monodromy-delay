---
name: scaffold-dsp-class
description: Generate a new empty (passthrough) DSP class in source/DSP following the header/cpp split — template<SampleType>, inline process(), cold prepare/setters in the .cpp, explicit float/double instantiation. Use to stub out a new viatordsp module before writing its math.
---

# Scaffold an empty DSP class

Emits a compiling, **passthrough** DSP module in `source/DSP/<Category>/<Name>.{h,cpp}`. The generated class does nothing yet — `processSample` returns the input untouched — so the author fills in the math. It ships with one example smoothed parameter (`amount`) demonstrating the full smoother → range-clamp → setter plumbing; delete or rename it as needed.

## Before generating, collect

1. **Class name** — PascalCase (e.g. `ComplexDelayLine`). Used verbatim as the type and filenames.
2. **Category folder** under `source/DSP/` (e.g. `Delay`, `Filters`, `Chaos`, `Utils`). Consumers include it as `#include "DSP/Delay/ComplexDelayLine.h"`.

## Rules that make it "just work"

- **No CMake edit needed.** `CMakeLists.txt` globs `source/*.cpp`/`*.h` with `CONFIGURE_DEPENDS`, and `source/` is on the include path.
- Keep it self-contained: `#include <juce_dsp/juce_dsp.h>` plus std headers only.
- **Header/cpp split**: the hot `process()` stays inline in the `.h` (templated on `ProcessContext`); cold `prepare` + setters go in the `.cpp`.
- **Explicit instantiation** at the bottom of the `.cpp` for both `float` and `double` — without it, consumers get linker errors.
- No code comments (CLAUDE.md rule).
- Run the repo `.clang-format` after writing.

## Template — `<Name>.h`

Replace `Foo` with the class name.

```cpp
#pragma once

#include <array>

#include <juce_dsp/juce_dsp.h>

namespace viatordsp {
    template<typename SampleType>
    class Foo final {
    public:
        Foo() = default;
        ~Foo() = default;

        void prepare(const juce::dsp::ProcessSpec &spec);

        template<typename ProcessContext>
        void process(const ProcessContext &context, size_t num_samples) noexcept {
            const auto &input_block = context.getInputBlock();
            auto &output_block = context.getOutputBlock();
            const auto num_channels = output_block.getNumChannels();

            jassert(input_block.getNumChannels() == num_channels);
            jassert(input_block.getNumSamples() == num_samples);

            for (size_t ch = 0; ch < num_channels; ++ch) {
                const auto *input_samples = input_block.getChannelPointer(ch);
                auto *output_samples = output_block.getChannelPointer(ch);

                for (size_t i = 0; i < num_samples; ++i) {
                    output_samples[i] = processSample(ch, input_samples[i]);
                }
            }
        }

        void setAmount(SampleType value);

    private:
        std::array<juce::SmoothedValue<SampleType>, 2> m_amount;

        struct Amount {
            static constexpr SampleType min = static_cast<SampleType>(0.0);
            static constexpr SampleType max = static_cast<SampleType>(1.0);
        };

        SampleType processSample(size_t channel, SampleType xn) noexcept {
            const auto amount = m_amount[channel].getNextValue();
            juce::ignoreUnused(amount);
            return xn;
        }

        static void initSmoother(std::array<juce::SmoothedValue<SampleType>, 2> &smoother,
                                 const juce::dsp::ProcessSpec &spec) {
            constexpr auto ramp_seconds = 0.02;
            for (auto &value : smoother) { value.reset(spec.sampleRate, ramp_seconds); }
        }
    };
}
```

## Template — `<Name>.cpp`

```cpp
#include "Foo.h"

namespace viatordsp {
    template<typename SampleType>
    void Foo<SampleType>::prepare(const juce::dsp::ProcessSpec &spec) {
        initSmoother(m_amount, spec);
        setAmount(static_cast<SampleType>(0.0));
    }

    template<typename SampleType>
    void Foo<SampleType>::setAmount(const SampleType value) {
        const auto clamped = juce::jlimit(Amount::min, Amount::max, value);
        for (auto &smoother : m_amount) { smoother.setTargetValue(clamped); }
    }

    template class Foo<float>;
    template class Foo<double>;
}
```

## After generating

- Wire it into `source/DSP/ProcessBlock.h` with the `add-processblock-stage` flow.
- For the full rationale behind this shape, see the `dsp-module` skill.
