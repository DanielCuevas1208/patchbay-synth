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

"""A complete patch declaration."""
struct Patch
    sample_rate::Int
    duration::Float64
    output_path::String
    nodes::Vector{NodeSpec}
    connections::Vector{Connection}
end

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

const NODE_KINDS = Set([:osc, :adsr, :svf, :gain, :delay])

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
