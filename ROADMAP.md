# Roadmap

This roadmap keeps milestone IDs stable across releases.
Each milestone records a user outcome, bounded work, acceptance criteria, and verification.

## Milestones

### `modulation-routing` — completed

User outcome: Patch authors can route explicit amplitude and filter modulation.

Deliverable: Add typed audio-rate, bipolar modulation inputs for `amplitude` and `cutoff` ports.

Acceptance criteria:

- [x] Parse `modulate source -> target.port` routes.
- [x] Convert amplitude depth into a clipped normalized gain factor.
- [x] Convert cutoff depth into octaves and clip below Nyquist.
- [x] Reject cycles that include signal or modulation routes.
- [x] Render deterministic fixtures for modulation depth and clipping.
- [x] Test unsupported ports and graph errors.
- [x] Execute the fixture and full suite on Julia 1.10.

Evidence:

- `src/Types.jl` defines `ModulationInput` with audio-rate and bipolar metadata.
- `src/DSP.jl` performs amplitude and cutoff conversion.
- `test/fixtures/modulation.patch` checks clipped amplitude modulation.
- `test/runtests.jl` checks metadata, depth, cutoff limits, and cycles.
- `patches/demo.patch` demonstrates both modulation ports.

Verification command:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

Verified on Julia 1.10.5: all 73 test assertions pass, including the modulation fixture.
The demo render also produces a WAV file and spectrogram gallery.

### `streamed-render` — planned

User outcome: Users can render long patches with bounded working memory.

Deliverable: Add block rendering that preserves oscillator, envelope, filter, and effect state.

Acceptance criteria:

- [ ] Render blocks without allocating the complete node signal.
- [ ] Preserve state across every block boundary.
- [ ] Match whole-buffer output within a documented tolerance.
- [ ] Report peak working memory in the render evidence.

Verification command:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

### `report-metadata` — planned

User outcome: Users can inspect render metrics without opening a browser.

Deliverable: Write a deterministic text report beside the WAV file.

Acceptance criteria:

- [ ] Report sample rate, duration, RMS, peak, and dominant frequency.
- [ ] Include one entry for every rendered node.
- [ ] Keep field order stable across runs.
- [ ] Test report contents with a checked-in fixture.

Verification command:

```powershell
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Verification note

Local validation passed on Julia 1.10.5 on 2026-10-20.
The modulation constructor supplies audio-rate, bipolar defaults. Voice and gain branches return their rendered signals.
CI remains configured in `.github/workflows/ci.yml`.
