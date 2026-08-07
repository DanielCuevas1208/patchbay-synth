# Patchbay Synth

Offline modular synthesis in Julia.

Patchbay Synth turns a text patch into deterministic mono WAV audio.
It can schedule notes across polyphonic voice nodes.
It also writes SVG spectrograms for every graph node.

## Value

The patch shows signal routing in a reviewable format.
The renderer separates parsing, graph evaluation, synthesis, and analysis.
The project demonstrates an offline audio pipeline without a sound card.

The new `note` command schedules pitch, timing, and velocity.
A `voice` node renders matching notes as independent oscillator voices.
Existing oscillator, envelope, filter, delay, and gain nodes remain available.

## Architecture

```text
patch text
    |
    v
parser ---> graph nodes + note events
                    |
                    v
             topological evaluator
                    |
        +-----------+-----------+
        |                       |
   RenderResult             analysis
        |                       |
        v                       v
     WAV file             SVG gallery
```

| Layer | Responsibility |
| --- | --- |
| `Types.jl` | Defines nodes, connections, note events, renders, and spectra. |
| `Parser.jl` | Parses settings, nodes, connections, and scheduled notes. |
| `DSP.jl` | Renders oscillators, voices, envelopes, filters, delay, and gain. |
| `Render.jl` | Orders the graph, mixes inputs, and evaluates each node. |
| `Analysis.jl` | Measures audio and writes SVG spectrograms. |
| `bin/patchbay-synth.jl` | Provides the command-line workflow. |

The public `Patch` type keeps note events beside graph declarations.
The public `polyphonic_voice` function supports direct deterministic tests.

## Setup

Install Julia 1.10.

Instantiate the committed project environment:

```powershell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Run the bundled demo:

```powershell
julia --project=. bin/patchbay-synth.jl patches/demo.patch --output output/demo.wav --gallery output/gallery
```

The command writes one WAV file and one SVG per node.
Open `output/gallery/index.html` in a browser.

## Sample output

```text
rendered: output/demo.wav
samples: 176400 at 44100 Hz
duration: 4.0 s
rms: <measured value>
peak: <measured value>
dominant_frequency: <measured value> Hz
gallery: output/gallery/index.html
```

The sample count and duration come from the demo settings.
Metric values depend on the selected patch.

## Patch format

A patch uses one command per line.
Lines beginning with `#` are comments.

```text
sample_rate 44100
duration 4.0
output output/demo.wav

node lead voice waveform=triangle amplitude=0.09 attack=0.01 release=0.12
note lead pitch=57 start=0.0 duration=0.70 velocity=0.8
note lead pitch=60 start=0.80 duration=0.70 velocity=0.7
note lead pitch=64 start=1.60 duration=0.70 velocity=0.8

node filter svf cutoff=1800 resonance=0.2 mode=low
node master gain amount=0.8

connect lead -> filter
connect filter -> master
```

Use `sine`, `saw`, `square`, or `triangle` waveforms.

The graph must be acyclic.
Terminal nodes mix into the final mono output.

### Note events

Use this form:

```text
note GROUP pitch=MIDI start=SECONDS duration=SECONDS velocity=LEVEL
```

`pitch` accepts MIDI values from 0 through 127.
Use `frequency=HZ` instead of `pitch` for direct frequency control.
`start` defaults to zero.
`velocity` defaults to one.

A `voice` node matches notes with the same group as its node id.
Each note starts a fresh oscillator phase.
Each note receives the node attack and release settings.
Overlapping notes mix into one node signal.

### LFO modulation

Connect an `lfo` node into an `osc` node.
The oscillator uses that signal for pitch automation.

Set `pitch_depth` in octaves per unit input.
A depth of `1.0` creates a one-octave sweep at full input.

CLI options can override output, gallery, sample rate, and duration.

## Evaluation evidence

The deterministic tests cover parser validation, voice timing, velocity, MIDI conversion, and note rendering.
They also cover envelopes, filters, LFO pitch modulation, graph cycles, WAV output, and gallery output.
The golden fixture checks every sample in a compact render.

Run the test suite:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

CI runs the test suite on Julia 1.10 for pushes and pull requests.
CI also renders the demo and uploads its WAV and SVG artifacts.

Local verification in this checkout is blocked because Julia is not installed.

## Limitations

- The engine renders mono audio.
- Voice nodes use one waveform and one envelope shape per group.
- Note starts and durations round to the nearest sample.
- MIDI note values use the equal-tempered 440 Hz reference.
- Oscillators are not band-limited and can alias above Nyquist.
- The graph evaluator keeps every node signal in memory.
- The gallery uses static SVG files without interactive zoom.
- The WAV writer does not normalize samples automatically.

## Roadmap

- [x] Add LFO sources and oscillator pitch automation.
- [x] Add note events and polyphonic voice nodes.
- [ ] Add amplitude and filter modulation sources.
- [ ] Add streamed rendering for longer patches.
- [ ] Add a browser-free report format for spectrogram metadata.

## License

MIT. See [LICENSE](LICENSE).