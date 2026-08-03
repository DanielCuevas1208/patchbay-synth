function _hann_window(size::Int)
    size > 0 || throw(ArgumentError("window_size must be positive"))
    size == 1 && return ones(Float64, 1)
    [0.5 - 0.5 * cos(2pi * (index - 1) / (size - 1)) for index in 1:size]
end

"""Measure the root-mean-square level of a mono signal."""
function rms_level(samples::AbstractVector{<:Real})
    isempty(samples) && throw(ArgumentError("cannot measure an empty signal"))
    sqrt(sum(abs2, samples) / length(samples))
end

"""Find the strongest positive-frequency FFT bin."""
function dominant_frequency(samples::AbstractVector{<:Real}, sample_rate::Integer;
        window_size::Integer = 4096)
    isempty(samples) && throw(ArgumentError("cannot analyze an empty signal"))
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    window_size > 1 || throw(ArgumentError("window_size must be greater than one"))
    window = _hann_window(Int(window_size))
    frame = zeros(Float64, Int(window_size))
    count = min(length(samples), Int(window_size))
    frame[1:count] .= Float64.(samples[1:count])
    spectrum = abs.(fft(frame .* window))
    positive = spectrum[1:(div(window_size, 2) + 1)]
    bin = argmax(positive)
    (bin - 1) * Float64(sample_rate) / window_size
end

"""Compute a Hann-windowed short-time Fourier transform in decibels."""
function spectrogram(samples::AbstractVector{<:Real}, sample_rate::Integer;
        window_size::Integer = 1024, hop_size::Integer = 256)
    isempty(samples) && throw(ArgumentError("cannot analyze an empty signal"))
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    window_size > 1 || throw(ArgumentError("window_size must be greater than one"))
    hop_size > 0 || throw(ArgumentError("hop_size must be positive"))

    fft_size = Int(window_size)
    hop = Int(hop_size)
    frame_count = max(1, 1 + fld(max(length(samples) - fft_size, 0), hop))
    bin_count = div(fft_size, 2) + 1
    magnitudes = zeros(Float64, bin_count, frame_count)
    window = _hann_window(fft_size)
    frame = zeros(Float64, fft_size)

    for frame_index in 1:frame_count
        fill!(frame, 0.0)
        start_index = (frame_index - 1) * hop + 1
        available = min(fft_size, length(samples) - start_index + 1)
        available > 0 && (frame[1:available] .= Float64.(samples[start_index:(start_index + available - 1)]))
        magnitudes[:, frame_index] .= abs.(fft(frame .* window))[1:bin_count]
    end

    reference = maximum(magnitudes)
    reference = reference > 0 ? reference : 1.0
    magnitudes_db = 20.0 .* log10.(max.(magnitudes ./ reference, eps(Float64)))
    frequencies = collect(0:(bin_count - 1)) .* Float64(sample_rate) ./ fft_size
    times = collect(0:(frame_count - 1)) .* hop ./ Float64(sample_rate)
    Spectrogram(frequencies, times, magnitudes_db)
end

function _xml_escape(value)
    replace(string(value), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
end

function _spectrogram_color(value::Float64)
    intensity = clamp((value + 80.0) / 80.0, 0.0, 1.0)
    red = round(Int, 16 + 232 * intensity)
    green = round(Int, 24 + 174 * intensity)
    blue = round(Int, 48 - 28 * intensity)
    "rgb($(red),$(green),$(blue))"
end

"""Write a self-contained SVG spectrogram without a plotting runtime."""
function write_spectrogram_svg(path::AbstractString, result::Spectrogram; title::AbstractString = "Spectrogram")
    parent = dirname(path)
    isempty(parent) || mkpath(parent)
    width, height = 800, 360
    left, top, plot_width, plot_height = 64, 28, 700, 260
    columns = min(180, size(result.magnitudes_db, 2))
    rows = min(96, size(result.magnitudes_db, 1))
    cell_width = plot_width / columns
    cell_height = plot_height / rows

    open(path, "w") do io
        write(io, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
        write(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $(width) $(height)\" role=\"img\" aria-label=\"$(_xml_escape(title))\">\n")
        write(io, "<rect width=\"100%\" height=\"100%\" fill=\"#0d1321\"/>\n")
        write(io, "<text x=\"$(left)\" y=\"20\" fill=\"#f6c453\" font-family=\"ui-monospace,monospace\" font-size=\"14\">$(_xml_escape(title))</text>\n")
        for row in 1:rows
            source_row = rows - row + 1
            row_start = floor(Int, (source_row - 1) * size(result.magnitudes_db, 1) / rows) + 1
            row_stop = max(row_start, ceil(Int, source_row * size(result.magnitudes_db, 1) / rows))
            for column in 1:columns
                column_start = floor(Int, (column - 1) * size(result.magnitudes_db, 2) / columns) + 1
                column_stop = max(column_start, ceil(Int, column * size(result.magnitudes_db, 2) / columns))
                value = maximum(result.magnitudes_db[row_start:row_stop, column_start:column_stop])
                x = left + (column - 1) * cell_width
                y = top + (row - 1) * cell_height
                write(io, "<rect x=\"$(round(x, digits=2))\" y=\"$(round(y, digits=2))\" width=\"$(round(cell_width + 0.2, digits=2))\" height=\"$(round(cell_height + 0.2, digits=2))\" fill=\"$(_spectrogram_color(value))\"/>\n")
            end
        end
        write(io, "<rect x=\"$(left)\" y=\"$(top)\" width=\"$(plot_width)\" height=\"$(plot_height)\" fill=\"none\" stroke=\"#718096\"/>\n")
        write(io, "<text x=\"$(left)\" y=\"$(height - 34)\" fill=\"#cbd5e0\" font-family=\"ui-monospace,monospace\" font-size=\"11\">0 Hz</text>\n")
        write(io, "<text x=\"$(left + plot_width - 42)\" y=\"$(height - 34)\" fill=\"#cbd5e0\" font-family=\"ui-monospace,monospace\" font-size=\"11\">$(round(last(result.times), digits=2)) s</text>\n")
        write(io, "<text x=\"8\" y=\"$(top + 10)\" fill=\"#cbd5e0\" font-family=\"ui-monospace,monospace\" font-size=\"11\">$(round(last(result.frequencies), digits=0)) Hz</text>\n")
        write(io, "<text x=\"20\" y=\"$(top + plot_height)\" fill=\"#cbd5e0\" font-family=\"ui-monospace,monospace\" font-size=\"11\">0 Hz</text>\n")
        write(io, "</svg>\n")
    end
    path
end

function _gallery_filename(index::Int, node::NodeSpec)
    safe_id = replace(node.id, r"[^A-Za-z0-9_-]" => "_")
    "$(lpad(index, 2, '0'))-$(safe_id).svg"
end

"""Write one SVG spectrogram and one HTML index for every graph node."""
function write_spectrogram_gallery(result::RenderResult, nodes::Vector{NodeSpec}, directory::AbstractString)
    mkpath(directory)
    entries = String[]
    for (index, node) in enumerate(nodes)
        filename = _gallery_filename(index, node)
        svg_path = joinpath(directory, filename)
        analysis = spectrogram(result.node_signals[node.id], result.sample_rate)
        write_spectrogram_svg(svg_path, analysis; title = "$(node.id) / $(node.kind)")
        push!(entries, "<article><h2>$(_xml_escape(node.id))</h2><p>$(node.kind)</p><img src=\"$filename\" alt=\"Spectrogram for $(_xml_escape(node.id))\"></article>")
    end

    index_path = joinpath(directory, "index.html")
    open(index_path, "w") do io
        write(io, "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Patchbay Synth gallery</title><style>body{margin:0;background:#0d1321;color:#e2e8f0;font:15px ui-monospace,monospace}main{max-width:1100px;margin:0 auto;padding:32px}h1{color:#f6c453}section{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:20px}article{background:#151f32;border:1px solid #31415e;padding:14px}h2{margin:0;color:#f6c453}p{color:#a0aec0}img{width:100%;display:block}</style></head><body><main><h1>Patchbay Synth / module gallery</h1><p>Each panel shows the signal emitted by one graph node.</p><section>")
        for entry in entries
            write(io, entry, "\n")
        end
        write(io, "</section></main></body></html>\n")
    end
    index_path
end

