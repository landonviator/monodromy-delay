#include "PluginEditor.h"

namespace viator {
    MonodromyDelayEditor::MonodromyDelayEditor(MonodromyDelayProcessor &processor)
        : AudioProcessorEditor(&processor), m_processor(processor) {
        constexpr auto default_width = 800;
        constexpr auto default_height = 450;
        setSize(default_width, default_height);
    }

    void MonodromyDelayEditor::paint(juce::Graphics &g) {
        g.fillAll(getLookAndFeel().findColour(juce::ResizableWindow::backgroundColourId));
    }

    void MonodromyDelayEditor::resized() {
    }
}
