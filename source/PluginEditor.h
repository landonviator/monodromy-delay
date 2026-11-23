#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

#include "PluginProcessor.h"

namespace viator {
    class MonodromyDelayEditor final : public juce::AudioProcessorEditor {
    public:
        explicit MonodromyDelayEditor(MonodromyDelayProcessor &processor);

        void paint(juce::Graphics &g) override;

        void resized() override;

    private:
        MonodromyDelayProcessor &m_processor;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MonodromyDelayEditor)
    };
}
