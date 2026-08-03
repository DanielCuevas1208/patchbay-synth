const _DEFAULT_SAMPLE_RATE = 44_100
const _DEFAULT_DURATION = 4.0
const _DEFAULT_OUTPUT = "output/demo.wav"

function _parse_error(line_number::Int, message::String)
    throw(ArgumentError("patch line $(line_number): $(message)"))
end

function _parse_float(value::String, label::String, line_number::Int)
    try
        return parse(Float64, value)
    catch
        _parse_error(line_number, "$(label) must be numeric, got '$(value)'")
    end
end

function parse_patch(text::AbstractString)
    sample_rate = _DEFAULT_SAMPLE_RATE
    duration = _DEFAULT_DURATION
    output_path = _DEFAULT_OUTPUT
    nodes = NodeSpec[]
    connections = Connection[]
    node_ids = Set{String}()

    for (line_number, raw_line) in enumerate(split(String(text), '\n'; keepempty = true))
        line = strip(raw_line)
        isempty(line) && continue
        startswith(line, "#") && continue
        tokens = split(line)
        command = lowercase(tokens[1])

        if command == "sample_rate"
            length(tokens) == 2 || _parse_error(line_number, "sample_rate expects one value")
            sample_rate = try
                parse(Int, tokens[2])
            catch
                _parse_error(line_number, "sample_rate must be an integer")
            end
            sample_rate > 0 || _parse_error(line_number, "sample_rate must be positive")
        elseif command == "duration"
            length(tokens) == 2 || _parse_error(line_number, "duration expects one value")
            duration = _parse_float(tokens[2], "duration", line_number)
            duration > 0 || _parse_error(line_number, "duration must be positive")
        elseif command == "output"
            length(tokens) == 2 || _parse_error(line_number, "output expects one path")
            output_path = tokens[2]
        elseif command == "node"
            length(tokens) >= 3 || _parse_error(line_number, "node expects an id and kind")
            id = tokens[2]
            isempty(id) && _parse_error(line_number, "node id cannot be empty")
            id in node_ids && _parse_error(line_number, "duplicate node id '$(id)'")
            kind = Symbol(lowercase(tokens[3]))
            kind in NODE_KINDS || _parse_error(line_number, "unsupported node kind '$(tokens[3])'")
            params = Dict{Symbol,String}()
            for token in tokens[4:end]
                parts = split(token, '='; limit = 2)
                length(parts) == 2 || _parse_error(line_number, "node parameters use key=value")
                key = Symbol(lowercase(parts[1]))
                value = parts[2]
                isempty(value) && _parse_error(line_number, "parameter '$(key)' cannot be empty")
                haskey(params, key) && _parse_error(line_number, "duplicate parameter '$(key)'")
                params[key] = value
            end
            push!(nodes, NodeSpec(id, kind, params))
            push!(node_ids, id)
        elseif command == "connect"
            length(tokens) == 4 && tokens[3] == "->" || _parse_error(line_number, "connect uses: connect source -> target")
            push!(connections, Connection(tokens[2], tokens[4]))
        else
            _parse_error(line_number, "unknown command '$(tokens[1])'")
        end
    end

    isempty(nodes) && throw(ArgumentError("patch must declare at least one node"))
    Patch(sample_rate, duration, output_path, nodes, connections)
end

function parse_patch_file(path::AbstractString)
    isfile(path) || throw(ArgumentError("patch file does not exist: $(path)"))
    parse_patch(read(path, String))
end
