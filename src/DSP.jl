"""Render a band-limited-free oscillator for a fixed sample count."""
function oscillator(waveform::Symbol, frequency::Real, sample_rate::Integer, n_samples::Integer;
        amplitude::Real = 1.0, phase::Real = 0.0)
    n_samples >= 0 || throw(ArgumentError("n_samples must be non-negative"))
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    frequency >= 0 || throw(ArgumentError("frequency must be non-negative"))
    amplitude >= 0 || throw(ArgumentError("amplitude must be non-negative"))
    waveform in (:sine, :saw, :square, :triangle) ||
        throw(ArgumentError("unsupported waveform '$(waveform)'"))

    output = Vector{Float64}(undef, n_samples)
    frequency_value = Float64(frequency)
    sample_rate_value = Float64(sample_rate)
    amplitude_value = Float64(amplitude)
    phase_value = Float64(phase)
    for index in 1:n_samples
        cycle = mod(phase_value + (index - 1) * frequency_value / sample_rate_value, 1.0)
        unit = if waveform == :sine
            sin(2pi * cycle)
        elseif waveform == :saw
            2.0 * cycle - 1.0
        elseif waveform == :square
            cycle < 0.5 ? 1.0 : -1.0
        else
            4.0 * abs(cycle - 0.5) - 1.0
        end
        output[index] = amplitude_value * unit
    end
    output
end

"""Create a one-shot ADSR envelope with a gate time measured from the start."""
function adsr_envelope(attack::Real, decay::Real, sustain::Real, release::Real,
        gate::Real, sample_rate::Integer, n_samples::Integer)
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    n_samples >= 0 || throw(ArgumentError("n_samples must be non-negative"))
    attack >= 0 || throw(ArgumentError("attack must be non-negative"))
    decay >= 0 || throw(ArgumentError("decay must be non-negative"))
    release >= 0 || throw(ArgumentError("release must be non-negative"))
    0 <= sustain <= 1 || throw(ArgumentError("sustain must be between zero and one"))
    gate >= 0 || throw(ArgumentError("gate must be non-negative"))

    sr = Float64(sample_rate)
    attack_samples = max(1, round(Int, Float64(attack) * sr))
    decay_samples = max(1, round(Int, Float64(decay) * sr))
    release_samples = max(1, round(Int, Float64(release) * sr))
    gate_samples = clamp(round(Int, Float64(gate) * sr), 0, n_samples)
    sustain_value = Float64(sustain)

    level_before_release(index::Int) = if index < attack_samples
        index / attack_samples
    elseif index < attack_samples + decay_samples
        1.0 - (1.0 - sustain_value) * (index - attack_samples) / decay_samples
    else
        sustain_value
    end

    release_level = level_before_release(gate_samples)
    output = zeros(Float64, n_samples)
    n_samples == 0 && return output
    for index in 0:(n_samples - 1)
        output[index + 1] = if index < gate_samples
            level_before_release(index)
        elseif gate_samples == n_samples
            level_before_release(index)
        elseif release == 0
            0.0
        else
            release_level * max(0.0, 1.0 - (index - gate_samples) / release_samples)
        end
    end
    output
end

"""Apply a stable two-integrator state-variable filter to a mono signal."""
function state_variable_filter(input::AbstractVector{<:Real}, cutoff::Real,
        resonance::Real, sample_rate::Integer; mode::Symbol = :low)
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    0 < cutoff < sample_rate / 2 || throw(ArgumentError("cutoff must be below the Nyquist frequency"))
    0 <= resonance <= 1 || throw(ArgumentError("resonance must be between zero and one"))
    mode in (:low, :high, :band, :notch) || throw(ArgumentError("unsupported filter mode '$(mode)'"))

    g = tan(pi * Float64(cutoff) / Float64(sample_rate))
    damping = 2.0 * (1.0 - Float64(resonance))
    integrator_one = 0.0
    integrator_two = 0.0
    output = zeros(Float64, length(input))

    for index in eachindex(input)
        drive = Float64(input[index])
        v3 = drive - damping * integrator_two
        band = (g * v3 + integrator_one) / (1.0 + g * (g + damping))
        low = integrator_two + g * band
        high = v3 - damping * band
        notch = low + high
        integrator_one = 2.0 * band - integrator_one
        integrator_two = 2.0 * low - integrator_two
        output[index] = mode == :low ? low : mode == :high ? high : mode == :band ? band : notch
    end
    output
end

"""Apply a feedback delay with a dry/wet mix."""
function delay_effect(input::AbstractVector{<:Real}, delay_time::Real,
        feedback::Real, mix::Real, sample_rate::Integer)
    sample_rate > 0 || throw(ArgumentError("sample_rate must be positive"))
    delay_time > 0 || throw(ArgumentError("delay_time must be positive"))
    0 <= feedback < 1 || throw(ArgumentError("feedback must be between zero and one"))
    0 <= mix <= 1 || throw(ArgumentError("mix must be between zero and one"))

    delay_samples = max(1, round(Int, Float64(delay_time) * sample_rate))
    buffer = zeros(Float64, delay_samples)
    output = zeros(Float64, length(input))
    feedback_value = Float64(feedback)
    mix_value = Float64(mix)

    for index in eachindex(input)
        buffer_index = mod1(index, delay_samples)
        dry_sample = Float64(input[index])
        delayed_sample = buffer[buffer_index]
        output[index] = (1.0 - mix_value) * dry_sample + mix_value * delayed_sample
        buffer[buffer_index] = dry_sample + feedback_value * delayed_sample
    end
    output
end




