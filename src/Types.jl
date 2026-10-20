"""A parsed synthesizer node and its textual parameters."""
struct NodeSpec
    id::String
    kind::Symbol
    params::Dict{Symbol,String}
end

"""A directed edge in the patch signal graph."""
struct Connection
    source::String
    target::String
end

"""A typed, audio-rate modulation route into a node parameter."""
struct ModulationInput
    source::String
    target::String
    parameter::Symbol
    rate::Symbol
    range::Symbol
end

"""A scheduled note for a named polyphonic voice node."""
struct NoteEvent
    group::String
    start::Float64
    duration::Float64
    frequency::Float64
    velocity::Float64
end

"""A complete patch declaration."""
struct Patch
    sample_rate::Int
    duration::Float64
    output_path::String
    nodes::Vector{NodeSpec}
    connections::Vector{Connection}
    notes::Vector{NoteEvent}
    modulations::Vector{ModulationInput}
end

Patch(sample_rate::Integer, duration::Real, output_path::AbstractString,
    nodes::Vector{NodeSpec}, connections::Vector{Connection}, notes::Vector{NoteEvent},
    modulations::Vector{ModulationInput}) =
    Patch(Int(sample_rate), Float64(duration), String(output_path), nodes, connections,
        notes, modulations)

Patch(sample_rate::Integer, duration::Real, output_path::AbstractString,
    nodes::Vector{NodeSpec}, connections::Vector{Connection}) =
    Patch(Int(sample_rate), Float64(duration), String(output_path), nodes, connections,
        NoteEvent[], ModulationInput[])

Patch(sample_rate::Integer, duration::Real, output_path::AbstractString,
    nodes::Vector{NodeSpec}, connections::Vector{Connection}, notes::Vector{NoteEvent}) =
    Patch(Int(sample_rate), Float64(duration), String(output_path), nodes, connections,
        notes, ModulationInput[])

"""A rendered mono track and the signal produced by every graph node."""
struct RenderResult
    samples::Vector{Float64}
    sample_rate::Int
    node_signals::Dict{String,Vector{Float64}}
end

"""A short-time Fourier transform represented in decibels."""
struct Spectrogram
    frequencies::Vector{Float64}
    times::Vector{Float64}
    magnitudes_db::Matrix{Float64}
end

const NODE_KINDS = Set([:osc, :lfo, :voice, :adsr, :svf, :gain, :delay])
const _MODULATION_PORTS = Dict{Symbol,Set{Symbol}}(
    :osc => Set([:amplitude]),
    :voice => Set([:amplitude]),
    :svf => Set([:cutoff]),
    :gain => Set([:amplitude]),
)

function _parameter(node::NodeSpec, key::Symbol, default::String)
    get(node.params, key, default)
end

function _float_parameter(node::NodeSpec, key::Symbol, default::Float64)
    value = _parameter(node, key, string(default))
    try
        return parse(Float64, value)
    catch
        throw(ArgumentError("node '$(node.id)' parameter '$(key)' must be numeric, got '$(value)'"))
    end
end
