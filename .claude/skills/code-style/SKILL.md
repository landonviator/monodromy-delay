---
name: code-style
description: Full Viator DSP C++ style guide — rationale, examples, and edge cases behind the terse rules in CLAUDE.md (immutability constexpr>const, west const, auto, attributes, enum scoping, parameter passing, includes, struct vs class, naming). Use when writing or reviewing non-trivial C++ and you want the reasoning, not just the rule.
---

# Viator DSP C++ style — rationale & examples

CLAUDE.md carries the terse rules; this is the "why" and the worked examples. When a rule and reality disagree, prefer consistency with the surrounding file, then fix the file toward these rules as you touch it. Formatting itself (indent, column limit) is owned by the repo's `.clang-format` — run it; don't hand-format.

## Immutability ladder: `constexpr` → `const` → mutable

Reach for the most restrictive that compiles, at every level: locals, members, parameters, and methods.

- **`constexpr`** when the value is known at compile time.
- **`const`** when it's runtime-computed but never reassigned.
- **mutable** only when it genuinely changes.

```cpp
constexpr SampleType kTwoPi = juce::MathConstants<SampleType>::twoPi; // compile-time
const auto gain = m_gain[channel].getNextValue();                    // runtime, fixed
SampleType accumulator = 0;                                          // actually mutates
```

Non-mutating member functions are `const`:

```cpp
[[nodiscard]] std::vector<BandConfig> getConfigs() const;
void updateLowShelf() const;   // touches only mutable-by-design juce state
```

Why: const-correctness makes intent legible, lets the compiler catch accidental writes, and documents thread-safety expectations (a `const` method is a read). It costs nothing at runtime.

## Named constants over magic numbers

Non-trivial literals get a named `constexpr`, grouped in a nested `Params`/range struct:

```cpp
struct Params {
    static constexpr SampleType thresh   = static_cast<SampleType>(1.5);
    static constexpr SampleType clip_pos = static_cast<SampleType>(4.0);
    static constexpr SampleType clip_neg = static_cast<SampleType>(-1.5);
};
```

Bare identity values (`0`, `1`, a `* 2`) can stay inline — naming them adds noise. The test: would a reader wonder "why 1.5?" If yes, name it.

## `auto` — liberal

Use `auto`/`const auto` whenever the initializer makes the type obvious. This is already the house pattern (`const auto power = m_parameters->powerParam->get();`). Spell the type out only when it genuinely aids clarity (rare) or is required. Don't fight the existing `const auto` idiom.

## West const

`const` goes on the left: `const SampleType`, `const auto`, `const juce::String&`. Every file already does this — east const (`SampleType const`) is more logically consistent for pointers but breaks the repo's grain, so don't introduce it.

## Initialization & member defaults

- **Brace-init `{}` by default**: `T x{};`, `m_spec{};`, `juce::AudioParameterFloat *p{nullptr};`. Gives narrowing protection and value-inits members.
- **In-class default member initializers** over constructor init lists for fixed defaults:

```cpp
bool m_use_miller_cap = true;
juce::dsp::ProcessSpec m_spec {};
FilterType m_type{kBandShelf};
```

- Keep constructors `= default` where possible; a hand-written constructor is a smell that some member lacks a good in-class default.

## Attributes & specifiers

- **`[[nodiscard]]`** on pure getters and value-returning computations — ignoring the result is almost always a bug:
  ```cpp
  [[nodiscard]] static std::vector<BandConfig> get15Configs();
  ```
- **`noexcept`** on audio-thread / `process` functions. The hot path must not throw, and `noexcept` both documents and enables optimizations:
  ```cpp
  template <typename ProcessContext>
  void process(const ProcessContext& context, size_t num_samples) noexcept { ... }
  ```
- **`override`** always on virtual overrides; never repeat `virtual` on the override. Lets the compiler verify the signature matches.
- **`final`** on leaf classes not meant to be derived from (`class SVFilter final`, `class ClassBAmp final`).

## Enum scoping

Default to an **unscoped `k`-prefixed `enum`** with a trailing `num_*` count — this is the idiom for index/size enums that subscript arrays:

```cpp
enum EqBand { kLow = 0, kLowMid, kHighMid, kHigh, kNumEqBands };
std::array<SVFilter<float>, kNumEqBands> m_eq_filters;
```

**Promote to scoped `enum class` when a variable/member holds that enum type** — i.e. it's a real typed value passed around, not just array indices. For example:

```cpp
enum class DistortionType { kClassBAmp, kClassAValve, ... }; // held by a member ↓
DistortionType m_distortion_type = DistortionType::kClassBAmp;

enum Type { kClassBAmp = 0, kClassAValve, ..., num_distortions }; // only indexes m_distortions
```

Scoping the typed one prevents its constants from leaking into the enclosing scope and forces qualified, self-documenting use (`DistortionType::kTape`).

## Parameter passing (interacts with RT-safety)

- **Objects/containers** (`juce::String`, `std::vector`, `ProcessSpec`, contexts) → `const&`.
- **Small arithmetic types** (`SampleType`, `int`, `bool`, enums) → **by value in audio/per-sample paths**. Passing a `float` by `const&` in a per-sample inner loop adds an indirection the optimizer may not elide — the opposite of what `processBlock` needs.

```cpp
SampleType processSample(size_t channel, SampleType xn);      // hot path: by value
void setProportionalQReferenceGain(SampleType maxAbsGainDb);  // cold API: by value too, fine
void setBands(const std::vector<BandConfig>& configs);        // object: const&
```

`const&` for a small type is acceptable on cold/message-thread setters, but by value is never wrong there and is required in the hot path — so default to by value for small types everywhere and you can't get it wrong.

## `struct` vs `class`

- **`struct`** for passive data aggregates: public data, no invariants to protect. The `parameters` pointer cache and the `Params` constant bundles are structs.
- **`class`** for anything with behavior or an invariant (private state + methods that maintain it). DSP modules are classes.

## Includes

Order groups **standard library → third-party/JUCE → project headers**. In a `.cpp`, its own header comes first (so the header is verified to be self-contained), then the three groups. Apply this to **new and edited files only** — don't reorder untouched files just to churn them; they migrate as they're touched.

```cpp
// Foo.cpp
#include "Foo.h"        // own header first

#include <array>        // std
#include <juce_dsp/juce_dsp.h>  // third-party
#include "Utils/Bias.h" // project
```

## Naming recap (full rules in CLAUDE.md)

Types & files PascalCase, no underscores, acronyms fully capitalized (`SVFilter`, `DCBlocker`, `ClassAValve`), file named for its primary class. `m_` members, `snake_case` locals/params, `camelCase` methods. Underscores appear only inside `snake_case` variable names — never in a type or file name.
