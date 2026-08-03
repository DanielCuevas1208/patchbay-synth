# Patchbay Synth

Offline modular synthesis in Julia.

Patchbay Synth turns a plain-text patch into a deterministic mono WAV render. The same render produces a self-contained spectrogram gallery.

> First coherent release: oscillators, ADSR envelopes, a state-variable filter, delay, gain, graph evaluation, WAV output, and regression tests.

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
| `DSP.jl` | Implements oscillators, ADSR, state-variable filtering, delay, and gain. |
| `Render.jl` | Orders the graph, sums inputs, evaluates nodes, and writes WAV files. |
| `Analysis.jl` | Measures RMS and frequency, then writes SVG spectrograms. |
| `bin/patchbay-synth.jl` | Provides the local command-line workflow. |

Supported nodes are `osc`, `adsr`, `svf`, `delay`, and `gain`.

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

The command creates the WAV file and one SVG spectrogram for every graph node.

Open `output/gallery/index.html` in a browser after rendering.

## Sample output

The command prints measured values from the render:

```text
rendered: output/demo.wav
samples: 176400 at 44100 Hz
duration: 4.0 s
rms: <measured RMS level>
peak: <measured peak level>
dominant_frequency: <measured frequency> Hz
gallery: output/gallery/index.html
```

The numeric fields come from the selected patch and sample rate.

## Patch format

A patch uses one command per line. Lines beginning with `#` are comments.

```text
sample_rate 44100
duration 4.0
output output/demo.wav

node tone osc waveform=sine frequency=220 amplitude=0.2
node envelope adsr attack=0.02 decay=0.15 sustain=0.7 release=0.4 gate=3.4
node filter svf cutoff=1800 resonance=0.2 mode=low
node master gain amount=0.8

connect tone -> envelope
connect envelope -> filter
connect filter -> master
```

Use `sine`, `saw`, `square`, or `triangle` waveforms.

The graph must be acyclic. Terminal nodes are mixed into the final mono output.

CLI options can override the patch output, gallery path, sample rate, and duration.

## Evaluation evidence

The test suite measures the RMS level and dominant frequency of a rendered 1 kHz signal.

The golden fixture compares all samples in a compact 1 kHz render against checked-in expected values.

The suite also checks parser errors, ADSR stages, filter stability, graph cycles, WAV creation, and gallery output.

Run all tests:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

CI runs the same command on every push and pull request.

Local test status for this workspace: Julia was not installed, so the suite could not run locally.

## Limitations

- The engine renders mono audio.
- Oscillator frequency stays constant during one render.
- The oscillators are not band-limited and can alias above Nyquist.
- The envelope uses one gate and one release phase.
- The filter exposes low-pass, high-pass, band-pass, and notch modes.
- The gallery uses static SVG files without interactive zoom.
- The graph evaluator keeps every node signal in memory.\n- The WAV writer does not normalize samples automatically.

## Roadmap

1. Add note events, pitch automation, and polyphonic voices.
2. Add modulation sources and richer time-based effects.
3. Add streamed rendering for longer patches.
4. Add a browser-free report format for spectrogram metadata.

## License

MIT. See [LICENSE](LICENSE).



