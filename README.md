# Monodromy Delay

An open-source delay whose feedback path twists the signal on every pass. The twist `r` sets how many passes the loop takes to return to its starting state, and that winding number sets the pitch: `r = 1` is a plain feedback comb, `r = −1` drops it an octave to odd harmonics, rotations `e^(i2π/m)` give offset sparse series, and a chaotic map makes the pitch follow the orbit.

Built on the monodromy framework from Georg Essl's *Winding Numbers and Monodromy of Vector Bundles over a Circular Buffer*. Made for the Freqlab plugin jam.

## Build

```bash
git submodule update --init --recursive
cmake -B build
cmake --build build --config Release
```

## License

AGPLv3. See [LICENSE](LICENSE). Uses [JUCE](https://juce.com) under its AGPLv3 open-source licence.
