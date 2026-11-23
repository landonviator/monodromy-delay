cmake_minimum_required(VERSION 3.23.1)

project(monodromy-delay VERSION 0.0.1)

set(CMAKE_CXX_STANDARD 17)

if (APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "Minimum OS X deployment version" FORCE)
    set(CMAKE_OSX_ARCHITECTURES "x86_64;arm64" CACHE STRING "Architectures" FORCE)
    set(CMAKE_XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET[arch=arm64] "11.0" CACHE STRING "arm 64 minimum deployment target" FORCE)
endif ()

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE INTERNAL "")
endif ()

add_subdirectory(libs/JUCE)

set(PROJECT_NAME "monodromy-delay")
set(PRODUCT_NAME "Monodromy Delay")
set(COMPANY_NAME "Viator DSP")
set(BUNDLE_ID "com.viator-dsp.monodromy-delay")
set(FORMATS Standalone AU VST3)

find_package(Git QUIET)
set(CURRENT_VERSION "0.0.1")

if (Git_FOUND)
    execute_process(
            COMMAND ${GIT_EXECUTABLE} rev-list --count HEAD
            WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
            OUTPUT_VARIABLE GIT_COMMIT_COUNT
            ERROR_QUIET
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if (GIT_COMMIT_COUNT)
        set(CURRENT_VERSION "0.0.${GIT_COMMIT_COUNT}")
    endif ()
endif ()

juce_add_plugin("${PROJECT_NAME}"
        COMPANY_NAME "${COMPANY_NAME}"
        BUNDLE_ID "${BUNDLE_ID}"
        COPY_PLUGIN_AFTER_BUILD TRUE
        PLUGIN_MANUFACTURER_CODE Vdsp
        PLUGIN_CODE MnDl
        FORMATS ${FORMATS}
        PLUGIN_VERSION "${CURRENT_VERSION}"
        PRODUCT_NAME "${PRODUCT_NAME}"
        NEEDS_MIDI_INPUT FALSE
        NEEDS_MIDI_OUTPUT FALSE
        IS_MIDI_EFFECT FALSE
        IS_SYNTH FALSE
)

file(GLOB_RECURSE SourceFiles CONFIGURE_DEPENDS
        "${CMAKE_CURRENT_SOURCE_DIR}/source/*.cpp"
        "${CMAKE_CURRENT_SOURCE_DIR}/source/*.h"
)

target_sources("${PROJECT_NAME}" PRIVATE ${SourceFiles})

target_include_directories("${PROJECT_NAME}" PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}/source"
)

target_compile_definitions("${PROJECT_NAME}" PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
        VERSION="${CURRENT_VERSION}"
)

target_link_libraries("${PROJECT_NAME}" PRIVATE
        juce::juce_audio_utils
        juce::juce_dsp
        PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)
