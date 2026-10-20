# Patchbay Synth

Offline modular synthesis in Julia.

Patchbay Synth turns a text patch into deterministic mono WAV audio.
The patch declares modules, signal routes, modulation routes, and scheduled notes.

## Value

Patch files keep signal flow visible in code review.
The engine separates parsing, graph evaluation, synthesis, and analysis.
The workflow runs without a sound card, network access, or hosted service.

The bundled demo shows polyphonic voices, pitch automation, amplitude modulation, filter modulation, delay, and spectrograms.

## Architecture

```text
patch text
    |
    v
parser ---> typed graph and note events
                    |
                    v
             cycle-safe evaluator
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
| `Types.jl` | Defines nodes, signal connections, modulation inputs, notes, renders, and spectra. |
| `Parser.jl` | Parses settings, nodes, connections, notes, and typed modulation routes. |
| `DSP.jl` | Renders oscillators, voices, envelopes, filters, delay, gain, and modulation conversion. |
| `Render.jl` | Validates the graph, orders nodes, mixes inputs, and evaluates modules. |
| `Analysis.jl` | Measures audio and writes SVG spectrograms. |
| `bin/patchbay-synth.jl` | Provides the command-line workflow. |

`connect` carries audio between modules.
`modulate` carries one audio-rate control signal into a named parameter.
Both route types participate in cycle detection.

## Setup

Install Julia 1.10.

Instantiate the committed environment:

```powershell
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

Render the showcase patch:

```powershell
julia --project=. bin/patchbay-synth.jl patches/demo.patch --output output/demo.wav --gallery output/gallery
```

Open `output/gallery/index.html` in a browser.

## Sample output

```text
rendered: output/demo.wav
samples: 176400 at 44100 Hz
duration: 4.0 s
gallery: output/gallery/index.html
```

The command also prints measured RMS, peak, and dominant frequency values.
The output directory contains one WAV file and one SVG file per graph node.

## Patch format

Use one command per line.
Lines beginning with `#` are comments.

```text
sample_rate 44100
duration 4.0
output output/demo.wav

node source lfo waveform=sine frequency=2 amplitude=1
node lead voice waveform=triangle amplitude=0.09 amplitude_depth=0.65 attack=0.01 release=0.12
note lead pitch=57 start=0.0 duration=0.70 velocity=0.8
node filter svf cutoff=1800 cutoff_depth=0.35 resonance=0.2 mode=low
node master gain amount=0.8

modulate source -> lead.amplitude
modulate source -> filter.cutoff
connect lead -> filter
connect filter -> master
```

Use `sine`, `saw`, `square`, or `triangle` waveforms.
The graph must be acyclic.
Terminal nodes mix into the mono output.

### Signal routes

Use `connect source -> target` for audio routes.
An oscillator input controls pitch when `pitch_depth` is non-zero.
Pitch depth uses octaves per input unit.

### Modulation routes

Use `modulate source -> target.port` for parameter routes.
Every modulation input uses audio-rate samples and a bipolar range.
The renderer sums multiple sources, then clips the result to `[-1, 1]`.

Supported ports use these conversions:

| Port | Nodes | Parameter | Conversion |
| --- | --- | --- | --- |
| `.amplitude` | `osc`, `voice`, `gain` | `amplitude_depth` from 0 through 1 | `clamp(1 + depth * input, 0, 1)` |
| `.cutoff` | `svf` | `cutoff_depth` in octaves | `cutoff * 2^(depth * input)`, clipped below Nyquist |

Base amplitude remains unnormalized.
The WAV writer preserves the rendered sample values.

### Note events

Use this form:

```text
note GROUP pitch=MIDI start=SECONDS duration=SECONDS velocity=LEVEL
```

`pitch` accepts MIDI values from 0 through 127.
Use `frequency=HZ` for direct frequency control.
`start` defaults to zero.
`velocity` defaults to one.

A `voice` node matches notes with its node identifier.
Each note starts a fresh oscillator phase.
Overlapping notes mix into one voice signal.

## Evaluation evidence

The tests cover parser validation, typed modulation metadata, amplitude depth, clipping, filter range conversion, and modulation cycles.
The tests also cover notes, envelopes, filters, pitch automation, graph cycles, WAV output, galleries, and golden samples.

Run the full suite:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

CI runs this suite on Julia 1.10.
CI also renders the demo and uploads its WAV and SVG artifacts.

Local validation on Julia 1.10.5 passes all 73 assertions, including the modulation fixture.
The demo render also produces its WAV file and spectrogram gallery.

## Limitations

- The engine renders mono audio.
- Oscillators are not band-limited.
- Voice nodes use one waveform and envelope shape per group.
- Note times round to the nearest sample.
- MIDI notes use equal temperament with A4 at 440 Hz.
- The evaluator keeps every node signal in memory.
- The gallery uses static SVG files.
- The WAV writer does not normalize samples.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for milestone IDs, acceptance criteria, evidence, and verification commands.

## License

MIT. See [LICENSE](LICENSE).
