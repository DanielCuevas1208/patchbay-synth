function _topological_order(patch::Patch)
    node_index = Dict{String,Int}(node.id => index for (index, node) in enumerate(patch.nodes))
    outgoing = [Int[] for _ in patch.nodes]
    indegree = zeros(Int, length(patch.nodes))
    edges = Tuple{String,String}[]

    for connection in patch.connections
        push!(edges, (connection.source, connection.target))
    end
    for modulation in patch.modulations
        modulation.rate == :audio ||
            throw(ArgumentError("modulation input rate must be audio"))
        modulation.range == :bipolar ||
            throw(ArgumentError("modulation input range must be bipolar"))
        push!(edges, (modulation.source, modulation.target))
    end

    for (source, target) in edges
        haskey(node_index, source) ||
            throw(ArgumentError("connection references unknown source '$(source)'"))
        haskey(node_index, target) ||
            throw(ArgumentError("connection references unknown target '$(target)'"))
        source == target &&
            throw(ArgumentError("node '$(source)' cannot connect to itself"))
        source_index = node_index[source]
        target_index = node_index[target]
        push!(outgoing[source_index], target_index)
        indegree[target_index] += 1
    end

    queue = Int[]
    for index in eachindex(indegree)
        indegree[index] == 0 && push!(queue, index)
    end
    order = Int[]
    cursor = 1
    while cursor <= length(queue)
        current = queue[cursor]
        cursor += 1
        push!(order, current)
        for target in outgoing[current]
            indegree[target] -= 1
            indegree[target] == 0 && push!(queue, target)
        end
    end
    length(order) == length(patch.nodes) || throw(ArgumentError("patch graph contains a cycle"))
    order, outgoing
end

function _validate_modulation_target(modulation::ModulationInput, node::NodeSpec)
    ports = get(_MODULATION_PORTS, node.kind, Set{Symbol}())
    modulation.parameter in ports ||
        throw(ArgumentError("node '$(node.id)' does not accept modulation parameter '$(modulation.parameter)'"))
end

function _sum_inputs(signals::Vector{Vector{Float64}}, n_samples::Int)
    output = zeros(Float64, n_samples)
    for signal in signals
        output .+= signal
    end
    output
end

function _render_node(node::NodeSpec, input::Vector{Float64},
        modulation_inputs::Dict{Symbol,Vector{Float64}}, sample_rate::Int,
        duration::Float64, notes::Vector{NoteEvent})
    n_samples = length(input)
    if node.kind == :osc
        waveform = Symbol(lowercase(_parameter(node, :waveform, "sine")))
        frequency = _float_parameter(node, :frequency, 220.0)
        amplitude = _float_parameter(node, :amplitude, 0.2)
        phase = _float_parameter(node, :phase, 0.0)
        pitch_depth = _float_parameter(node, :pitch_depth, 0.0)
        amplitude_depth = _float_parameter(node, :amplitude_depth, 1.0)
        pitch = isempty(input) || pitch_depth == 0 ? Float64[] : input
        return oscillator(waveform, frequency, sample_rate, n_samples;
            amplitude = amplitude, phase = phase,
            pitch_modulation = pitch, pitch_depth = pitch_depth,
            amplitude_modulation = get(modulation_inputs, :amplitude, Float64[]),
            amplitude_depth = amplitude_depth)
    elseif node.kind == :lfo
        waveform = Symbol(lowercase(_parameter(node, :waveform, "sine")))
        frequency = _float_parameter(node, :frequency, 1.0)
        amplitude = _float_parameter(node, :amplitude, 1.0)
        phase = _float_parameter(node, :phase, 0.0)
        return lfo(waveform, frequency, sample_rate, n_samples;
            amplitude = amplitude, phase = phase)
    elseif node.kind == :voice
        waveform = Symbol(lowercase(_parameter(node, :waveform, "sine")))
        amplitude = _float_parameter(node, :amplitude, 0.2)
        phase = _float_parameter(node, :phase, 0.0)
        attack = _float_parameter(node, :attack, 0.01)
        release = _float_parameter(node, :release, 0.1)
        voice_notes = filter(note -> note.group == node.id, notes)
        voice = polyphonic_voice(waveform, voice_notes, sample_rate, n_samples;
            amplitude = amplitude, phase = phase, attack = attack, release = release)
        amplitude_input = get(modulation_inputs, :amplitude, Float64[])
        return isempty(amplitude_input) ? voice :
            _apply_amplitude_modulation(voice, amplitude_input,
                _float_parameter(node, :amplitude_depth, 1.0))
    elseif node.kind == :adsr
        attack = _float_parameter(node, :attack, 0.01)
        decay = _float_parameter(node, :decay, 0.15)
        sustain = _float_parameter(node, :sustain, 0.7)
        release = _float_parameter(node, :release, 0.35)
        gate = _float_parameter(node, :gate, duration)
        envelope = adsr_envelope(attack, decay, sustain, release, gate, sample_rate, n_samples)
        return input .* envelope
    elseif node.kind == :svf
        cutoff = _float_parameter(node, :cutoff, sample_rate / 4)
        resonance = _float_parameter(node, :resonance, 0.1)
        mode = Symbol(lowercase(_parameter(node, :mode, "low")))
        return state_variable_filter(input, cutoff, resonance, sample_rate; mode = mode,
            cutoff_modulation = get(modulation_inputs, :cutoff, Float64[]),
            cutoff_depth = _float_parameter(node, :cutoff_depth, 1.0))
    elseif node.kind == :gain
        amount = _float_parameter(node, :amount, 1.0)
        output = input .* amount
        amplitude_input = get(modulation_inputs, :amplitude, Float64[])
        return isempty(amplitude_input) ? output :
            _apply_amplitude_modulation(output, amplitude_input,
                _float_parameter(node, :amplitude_depth, 1.0))
    elseif node.kind == :delay
        delay_time = _float_parameter(node, :time, 0.25)
        feedback = _float_parameter(node, :feedback, 0.2)
        mix = _float_parameter(node, :mix, 0.2)
        return delay_effect(input, delay_time, feedback, mix, sample_rate)
    end
    throw(ArgumentError("unsupported node kind '$(node.kind)'"))
end

"""Evaluate a patch graph into a deterministic mono render."""
function render_patch(patch::Patch; sample_rate::Integer = patch.sample_rate,
        duration::Real = patch.duration)
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    duration > 0 || throw(ArgumentError("duration must be positive"))
    n_samples = round(Int, Float64(duration) * sample_rate)
    n_samples > 0 || throw(ArgumentError("duration produces no samples"))
    order, outgoing = _topological_order(patch)
    node_indices = Dict{String,Int}(node.id => index for (index, node) in enumerate(patch.nodes))
    node_inputs = [Int[] for _ in patch.nodes]
    for connection in patch.connections
        source_index = node_indices[connection.source]
        target_index = node_indices[connection.target]
        push!(node_inputs[target_index], source_index)
    end
    node_modulation_sources = [Dict{Symbol,Vector{Int}}() for _ in patch.nodes]
    for modulation in patch.modulations
        target_index = node_indices[modulation.target]
        _validate_modulation_target(modulation, patch.nodes[target_index])
        source_index = node_indices[modulation.source]
        push!(get!(node_modulation_sources[target_index], modulation.parameter, Int[]), source_index)
    end

    signals = Dict{String,Vector{Float64}}()
    for current_index in order
        node = patch.nodes[current_index]
        inputs = Vector{Vector{Float64}}()
        for source_index in node_inputs[current_index]
            push!(inputs, signals[patch.nodes[source_index].id])
        end
        input = _sum_inputs(inputs, n_samples)
        modulation_inputs = Dict{Symbol,Vector{Float64}}()
        for (parameter, source_indices) in node_modulation_sources[current_index]
            sources = [signals[patch.nodes[source_index].id] for source_index in source_indices]
            modulation_inputs[parameter] = _sum_inputs(sources, n_samples)
        end
        signals[node.id] = _render_node(node, input, modulation_inputs,
            Int(sample_rate), Float64(duration), patch.notes)
    end

    output = zeros(Float64, n_samples)
    has_output = false
    for (index, node) in enumerate(patch.nodes)
        if isempty(outgoing[index])
            output .+= signals[node.id]
            has_output = true
        end
    end
    has_output || throw(ArgumentError("patch graph has no output node"))
    RenderResult(output, Int(sample_rate), signals)
end

"""Write mono floating-point samples as a WAV file."""
function write_wav(samples::AbstractVector{<:Real}, path::AbstractString, sample_rate::Integer)
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    parent = dirname(path)
    isempty(parent) || mkpath(parent)
    WAV.wavwrite(Float64.(samples), path; Fs = sample_rate)
    path
end

"""Parse, render, write, and optionally analyze a patch file."""
function render_patch_file(path::AbstractString; output_path::Union{Nothing,AbstractString} = nothing,
        sample_rate::Union{Nothing,Integer} = nothing, duration::Union{Nothing,Real} = nothing,
        gallery_dir::Union{Nothing,AbstractString} = nothing)
    patch = parse_patch_file(path)
    chosen_rate = isnothing(sample_rate) ? patch.sample_rate : Int(sample_rate)
    chosen_duration = isnothing(duration) ? patch.duration : Float64(duration)
    result = render_patch(patch; sample_rate = chosen_rate, duration = chosen_duration)
    chosen_output = isnothing(output_path) ? patch.output_path : String(output_path)
    write_wav(result.samples, chosen_output, result.sample_rate)
    if !isnothing(gallery_dir)
        write_spectrogram_gallery(result, patch.nodes, String(gallery_dir))
    end
    result, chosen_output
end
