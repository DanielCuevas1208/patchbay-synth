using Test
using PatchbaySynth

const PROJECT_ROOT = dirname(@__DIR__)

@testset "Patch parsing" begin
    patch = parse_patch_file(joinpath(PROJECT_ROOT, "patches", "demo.patch"))
    @test patch.sample_rate == 44_100
    @test patch.duration == 4.0
    @test length(patch.nodes) == 9
    @test length(patch.connections) == 8
    @test patch.nodes[1].kind == :osc
    @test patch.nodes[1].params[:waveform] == "saw"

    missing_target = parse_patch("node tone osc frequency=220\nconnect tone -> missing")
    @test_throws ArgumentError render_patch(missing_target)
    @test_throws ArgumentError parse_patch("node tone unknown")
end

@testset "Signal primitives" begin
    tone = oscillator(:sine, 1_000, 8_000, 8_000; amplitude = 0.5)
    @test length(tone) == 8_000
    @test isapprox(rms_level(tone), sqrt(0.125); atol = 1e-12)
    @test isapprox(dominant_frequency(tone, 8_000; window_size = 1_024), 1_000.0; atol = 1e-12)

    envelope = adsr_envelope(0.001, 0.001, 0.5, 0.001, 0.003, 1_000, 8)
    @test envelope[1] == 0.0
    @test envelope[2] == 1.0
    @test envelope[3] == 0.5
    @test envelope[4] == 0.5
    @test envelope[5] == 0.0

    filtered = state_variable_filter(tone[1:128], 1_000, 0.2, 8_000; mode = :low)
    delayed = delay_effect(filtered, 0.01, 0.2, 0.3, 8_000)
    @test length(delayed) == 128
    @test all(isfinite, delayed)
end

@testset "Graph evaluation and metrics" begin
    patch = parse_patch("""
        sample_rate 8000
        duration 1.0
        node tone osc waveform=sine frequency=1000 amplitude=0.5
        node master gain amount=0.8
        connect tone -> master
    """)
    result = render_patch(patch)
    @test result.sample_rate == 8_000
    @test length(result.samples) == 8_000
    @test isapprox(rms_level(result.samples), sqrt(0.08); atol = 1e-12)
    @test isapprox(dominant_frequency(result.samples, result.sample_rate; window_size = 1_024), 1_000.0; atol = 1e-12)
    @test length(result.node_signals["tone"]) == 8_000

    cyclic = parse_patch("""
        node a gain amount=1
        node b gain amount=1
        connect a -> b
        connect b -> a
    """)
    @test_throws ArgumentError render_patch(cyclic)
end

@testset "Golden render" begin
    patch_path = joinpath(@__DIR__, "fixtures", "golden.patch")
    golden_path = joinpath(@__DIR__, "golden", "golden.samples")
    result = render_patch(parse_patch_file(patch_path))
    expected = parse.(Float64, filter(line -> !isempty(line), readlines(golden_path)))
    @test length(result.samples) == length(expected)
    @test all(isapprox.(result.samples, expected; atol = 1e-12, rtol = 0.0))
end

@testset "WAV and spectrogram artifacts" begin
    patch_path = joinpath(PROJECT_ROOT, "patches", "demo.patch")
    mktempdir() do directory
        wav_path = joinpath(directory, "demo.wav")
        gallery_path = joinpath(directory, "gallery")
        result, written_path = render_patch_file(patch_path;
            output_path = wav_path, duration = 0.1, gallery_dir = gallery_path)
        @test written_path == wav_path
        @test isfile(wav_path)
        @test isfile(joinpath(gallery_path, "index.html"))
        @test length(filter(name -> endswith(name, ".svg"), readdir(gallery_path))) == 9
        @test size(spectrogram(result.samples, result.sample_rate).magnitudes_db, 1) == 513
    end
end


