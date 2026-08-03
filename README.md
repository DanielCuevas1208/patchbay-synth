# Patchbay Synth

Offline modular synthesis in Julia.

Patchbay Synth turns a plain-text patch into a deterministic mono WAV render. Each render also produces a self-contained spectrogram gallery.

Release 0.2.0 includes:

- Oscillators and LFOs
- ADSR envelopes
- State-variable filter
- Delay and gain
- Pitch automation
- WAV output
- Spectrogram gallery

## Value

The patch file keeps signal routing visible. The evaluator keeps node behavior small, testable, and reusable.

The project shows a complete audio path. It parses a patch, evaluates a graph, writes audio, and analyzes every module.

Rendering does not use a sound card. The primary demo does not need network access or secrets.

## Architecture

```text
patches/demo.patch
        |
        v
  Patch parser  ->  validated directed graph  ->  node processors
                                                      |
                              +----------------------+------------------+
                              |                                         |
                         WAV writer                              FFTW analyzer
                              |                                         |
                        output/demo.wav                     gallery/index.html
```

| Layer | Responsibility |
| --- | --- |
| `Parser.jl` | Reads patch settings, nodes, parameters, and connections. |
| `DSP.jl` | Implements oscillators, LFOs, ADSR, state-variable filtering, delay, and gain. |
| `Render.jl` | Orders the graph, sums inputs, evaluates nodes, and writes WAV files. |
| `Analysis.jl` | Measures RMS and frequency, then writes SVG spectrograms. |
| `bin/patchbay-synth.jl` | Provides the local command-line workflow. |

Supported node kinds are `osc`, `lfo`, `adsr`, `svf`, `delay`, and `gain`.

## Setup

Install Julia 1.10.

Instantiate the committed project environment:

```powershell
julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

Run the bundled demo from the repository root:

```powershell
julia --project=. bin/patchbay-synth.jl patches/demo.patch --output output/demo.wav --gallery output/gallery
```

The command writes one WAV file and one SVG per node.

Open `output/gallery/index.html` in a browser after rendering.

## Sample output

The command prints measured values from the render:

```text
rendered: output/demo.wav
samples: 176400 at 44100 Hz
duration: 4.0 s
rms: 0.038016
peak: 0.131155
dominant_frequency: 236.87 Hz
gallery: output/gallery/index.html
```

The values come from the demo patch and its sample rate.

## Patch format

A patch uses one command per line. Lines beginning with `#` are comments.

```text
sample_rate 44100
duration 4.0
output output/demo.wav

node bass osc waveform=saw frequency=110 amplitude=0.18 pitch_depth=0.06
node bass_vib lfo waveform=sine frequency=4.2 amplitude=0.9
node tone osc waveform=sine frequency=220 amplitude=0.16

node envelope adsr attack=0.02 decay=0.15 sustain=0.7 release=0.4 gate=3.4
node filter svf cutoff=1800 resonance=0.2 mode=low
node master gain amount=0.8

connect bass_vib -> bass
connect bass -> envelope
connect envelope -> filter
connect filter -> master
```

Use `sine`, `saw`, `square`, or `triangle` waveforms.

The graph must be acyclic. Terminal nodes mix into the final mono output.

CLI options can override the patch output, gallery path, sample rate, and duration.

### LFO modulation

Connect an `lfo` node into an `osc` node. The `osc` node uses that signal for pitch automation.

Set `pitch_depth` to control the sweep range. The unit is octaves per unit input.

A depth of `1.0` with a full-scale LFO sweeps one octave. Use small depths for vibrato.

## Evaluation evidence

The test suite measures the RMS level and dominant frequency of rendered signals.

The golden fixture compares all samples against checked-in expected values.

The suite covers parser errors, ADSR stages, filter stability, LFO output, pitch modulation, graph cycles, WAV creation, and gallery output.

Run all tests:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

CI runs the same command on every push and pull request.

Local test status for this workspace: 46 tests pass on Julia 1.10.11.

## Limitations

- The engine renders mono audio.
- The oscillators are not band-limited and can alias above Nyquist.
- The LFO ignores audio-rate input.
- The envelope uses one gate and one release phase.
- The filter exposes low-pass, high-pass, band-pass, and notch modes.
- The gallery uses static SVG files without interactive zoom.
- The graph evaluator keeps every node signal in memory.
- The WAV writer does not normalize samples automatically.

## Roadmap

- [x] Add LFO sources and oscillator pitch automation.
- [ ] Add note events and polyphonic voices.
- [ ] Add amplitude and filter modulation sources.
- [ ] Add streamed rendering for longer patches.
- [ ] Add a browser-free report format for spectrogram metadata.

## License

MIT. See [LICENSE](LICENSE).
