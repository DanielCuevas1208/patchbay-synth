#!/usr/bin/env julia

using PatchbaySynth

function usage()
    println("Patchbay Synth")
    println("Usage: julia --project=. bin/patchbay-synth.jl PATCH [options]")
    println("Options:")
    println("  --output PATH       Write the WAV file to PATH.")
    println("  --gallery PATH      Write one SVG spectrogram per module.")
    println("  --sample-rate HZ    Override the patch sample rate.")
    println("  --duration SECONDS  Override the patch duration.")
    println("  --help              Show this message.")
end

function next_value(args::Vector{String}, index::Int, option::String)
    index < length(args) || error("$(option) needs a value")
    args[index + 1]
end

function main(args::Vector{String})
    if any(argument -> argument == "--help", args)
        usage()
        return 0
    end

    input_path = nothing
    output_path = nothing
    gallery_path = nothing
    sample_rate = nothing
    duration = nothing
    index = 1
    while index <= length(args)
        argument = args[index]
        if argument == "--output"
            output_path = next_value(args, index, "--output")
            index += 2
        elseif argument == "--gallery"
            gallery_path = next_value(args, index, "--gallery")
            index += 2
        elseif argument == "--sample-rate"
            sample_rate = parse(Int, next_value(args, index, "--sample-rate"))
            index += 2
        elseif argument == "--duration"
            duration = parse(Float64, next_value(args, index, "--duration"))
            index += 2
        elseif startswith(argument, "-")
            error("unknown option: $(argument)")
        elseif isnothing(input_path)
            input_path = argument
            index += 1
        else
            error("only one patch file is allowed")
        end
    end

    isnothing(input_path) && (usage(); error("a patch file is required"))
    result, written_path = render_patch_file(input_path;
        output_path = output_path, sample_rate = sample_rate, duration = duration,
        gallery_dir = gallery_path)

    peak = maximum(abs.(result.samples))
    println("rendered: $(written_path)")
    println("samples: $(length(result.samples)) at $(result.sample_rate) Hz")
    println("duration: $(round(length(result.samples) / result.sample_rate, digits = 3)) s")
    println("rms: $(round(rms_level(result.samples), digits = 6))")
    println("peak: $(round(peak, digits = 6))")
    println("dominant_frequency: $(round(dominant_frequency(result.samples, result.sample_rate), digits = 2)) Hz")
    isnothing(gallery_path) || println("gallery: $(joinpath(gallery_path, "index.html"))")
    0
end

exit(main(ARGS))
