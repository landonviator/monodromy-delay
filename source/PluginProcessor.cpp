#include "PluginProcessor.h"

#include "PluginEditor.h"

namespace viator {
    MonodromyDelayProcessor::MonodromyDelayProcessor()
        : AudioProcessor(BusesProperties()
                                 .withInput("Input", juce::AudioChannelSet::stereo(), true)
                                 .withOutput("Output", juce::AudioChannelSet::stereo(), true)),
          m_tree_state(*this, nullptr, "PARAMETERS", createParameterLayout()) {
    }

    juce::AudioProcessorValueTreeState::ParameterLayout MonodromyDelayProcessor::createParameterLayout() {
        return {};
    }

    void MonodromyDelayProcessor::prepareToPlay(double, int) {
    }

    void MonodromyDelayProcessor::releaseResources() {
    }

    bool MonodromyDelayProcessor::isBusesLayoutSupported(const BusesLayout &layouts) const {
        const auto &main_output = layouts.getMainOutputChannelSet();

        if (main_output != juce::AudioChannelSet::mono() && main_output != juce::AudioChannelSet::stereo())
            return false;

        return main_output == layouts.getMainInputChannelSet();
    }

    void MonodromyDelayProcessor::processBlock(juce::AudioBuffer<float> &buffer, juce::MidiBuffer &) noexcept {
        const juce::ScopedNoDenormals no_denormals;

        for (auto channel = getTotalNumInputChannels(); channel < getTotalNumOutputChannels(); ++channel)
            buffer.clear(channel, 0, buffer.getNumSamples());
    }

    juce::AudioProcessorEditor *MonodromyDelayProcessor::createEditor() {
        return new MonodromyDelayEditor(*this);
    }

    void MonodromyDelayProcessor::getStateInformation(juce::MemoryBlock &dest_data) {
        if (const auto xml = m_tree_state.copyState().createXml())
            copyXmlToBinary(*xml, dest_data);
    }

    void MonodromyDelayProcessor::setStateInformation(const void *data, const int size_in_bytes) {
        if (const auto xml = getXmlFromBinary(data, size_in_bytes))
            if (xml->hasTagName(m_tree_state.state.getType()))
                m_tree_state.replaceState(juce::ValueTree::fromXml(*xml));
    }
}

juce::AudioProcessor *JUCE_CALLTYPE createPluginFilter() {
    return new viator::MonodromyDelayProcessor();
}
