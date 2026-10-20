module PatchbaySynth

using FFTW
using WAV

include("Types.jl")
include("Parser.jl")
include("DSP.jl")
include("Render.jl")
include("Analysis.jl")

export Connection, ModulationInput, NodeSpec, NoteEvent, Patch, RenderResult, Spectrogram
export parse_patch, parse_patch_file
export oscillator, lfo, polyphonic_voice, amplitude_modulation, adsr_envelope
export state_variable_filter, delay_effect
export render_patch, render_patch_file, write_wav
export rms_level, dominant_frequency, spectrogram, write_spectrogram_svg
export write_spectrogram_gallery

end
