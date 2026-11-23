#pragma once

#include <juce_audio_processors/juce_audio_processors.h>

namespace viator {
    class MonodromyDelayProcessor final : public juce::AudioProcessor {
    public:
        MonodromyDelayProcessor();

        void prepareToPlay(double sample_rate, int samples_per_block) override;

        void releaseResources() override;

        bool isBusesLayoutSupported(const BusesLayout &layouts) const override;

        void processBlock(juce::AudioBuffer<float> &buffer, juce::MidiBuffer &midi) noexcept override;

        using AudioProcessor::processBlock;

        juce::AudioProcessorEditor *createEditor() override;

        [[nodiscard]] bool hasEditor() const override { return true; }

        [[nodiscard]] const juce::String getName() const override { return JucePlugin_Name; }

        [[nodiscard]] bool acceptsMidi() const override { return false; }

        [[nodiscard]] bool producesMidi() const override { return false; }

        [[nodiscard]] bool isMidiEffect() const override { return false; }

        [[nodiscard]] double getTailLengthSeconds() const override { return 0.0; }

        int getNumPrograms() override { return 1; }

        int getCurrentProgram() override { return 0; }

        void setCurrentProgram(int) override {}

        const juce::String getProgramName(int) override { return {}; }

        void changeProgramName(int, const juce::String &) override {}

        void getStateInformation(juce::MemoryBlock &dest_data) override;

        void setStateInformation(const void *data, int size_in_bytes) override;

        [[nodiscard]] juce::AudioProcessorValueTreeState &getTreeState() { return m_tree_state; }

    private:
        static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

        juce::AudioProcessorValueTreeState m_tree_state;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MonodromyDelayProcessor)
    };
}
