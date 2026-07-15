"""
    levi_civita_physical_time(oscillator, s; initial_time=0)

Return the exact physical time associated with fictitious time `s` for an
isolated [`LeviCivitaOscillator`](@ref), using the Sundman relation
`dt/ds = |u|²` and `t(0) = initial_time`.

The formula is the analytic integral of the exact oscillator solution and
supports negative, zero, and positive specific energy as well as forward and
backward fictitious time.
"""
function levi_civita_physical_time(
    oscillator::LeviCivitaOscillator{T},
    s::Real;
    initial_time::Real=zero(T),
) where {T}
    sT = T(s)
    t0 = T(initial_time)
    isfinite(sT) || throw(ArgumentError("s must be finite."))
    isfinite(t0) || throw(ArgumentError("initial_time must be finite."))

    λ = oscillator.specific_energy / T(2)
    A = dot(oscillator.u0, oscillator.u0)
    B = dot(oscillator.u0, oscillator.uprime0)
    C = dot(oscillator.uprime0, oscillator.uprime0)

    elapsed = if λ < zero(T)
        ω = sqrt(-λ)
        θ = ω * sT
        i_cc = sT / T(2) + sin(T(2) * θ) / (T(4) * ω)
        i_ss = sT / T(2) - sin(T(2) * θ) / (T(4) * ω)
        i_cs = sin(θ)^2 / (T(2) * ω)
        A * i_cc + (T(2) * B / ω) * i_cs + (C / ω^2) * i_ss
    elseif λ > zero(T)
        κ = sqrt(λ)
        θ = κ * sT
        i_cc = sT / T(2) + sinh(T(2) * θ) / (T(4) * κ)
        i_ss = -sT / T(2) + sinh(T(2) * θ) / (T(4) * κ)
        i_cs = sinh(θ)^2 / (T(2) * κ)
        A * i_cc + (T(2) * B / κ) * i_cs + (C / κ^2) * i_ss
    else
        A * sT + B * sT^2 + C * sT^3 / T(3)
    end

    return t0 + elapsed
end

"""
    LeviCivitaSundmanResult

Numerical isolated Levi-Civita solution over a fixed fictitious-time interval
with physical time integrated as a fifth state component. The state layout is
`[u₁, u₂, u₁′, u₂′, t]`.

Stage 4B deliberately uses no callback and performs no physical-time stopping.
"""
struct LeviCivitaSundmanResult{O,S}
    oscillator::O
    solution::S
end

"""
    integrate_levi_civita_sundman(oscillator, sspan; initial_time=0, kwargs...)

Integrate the isolated Levi-Civita oscillator and `dt/ds = |u|²` over a fixed
fictitious-time interval beginning at `s = 0`.

No callback or physical-time termination is used. Keyword arguments are
forwarded to `solve`; defaults are `Vern9()`, `reltol=1e-12`, and
`abstol=1e-12`, converted to the oscillator's numeric type.
"""
function integrate_levi_civita_sundman(
    oscillator::LeviCivitaOscillator{T},
    sspan::Tuple{<:Real,<:Real};
    initial_time::Real=zero(T),
    algorithm=Vern9(),
    reltol=nothing,
    abstol=nothing,
    kwargs...,
) where {T}
    s0, s1 = T(sspan[1]), T(sspan[2])
    all(isfinite, (s0, s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    iszero(s0) || throw(ArgumentError("Stage 4B requires the fictitious-time interval to begin at zero."))
    s1 != s0 || throw(ArgumentError("sspan endpoints must differ."))
    t0 = T(initial_time)
    isfinite(t0) || throw(ArgumentError("initial_time must be finite."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    rt > zero(T) && isfinite(rt) || throw(ArgumentError("reltol must be finite and positive."))
    at > zero(T) && isfinite(at) || throw(ArgumentError("abstol must be finite and positive."))

    y0 = SVector{5,T}(
        oscillator.u0[1], oscillator.u0[2],
        oscillator.uprime0[1], oscillator.uprime0[2], t0,
    )
    function rhs(y, p, s)
        λ = p.specific_energy / T(2)
        radius = y[1]^2 + y[2]^2
        SVector{5,T}(y[3], y[4], λ * y[1], λ * y[2], radius)
    end
    problem = ODEProblem(rhs, y0, (s0, s1), oscillator)
    solution = solve(problem, algorithm; reltol=rt, abstol=at, kwargs...)
    SciMLBase.successful_retcode(solution) ||
        error("Levi-Civita Sundman integration failed with retcode $(solution.retcode).")
    LeviCivitaSundmanResult(oscillator, solution)
end

"""
    levi_civita_sundman_state(result, s)

Evaluate a numerical [`LeviCivitaSundmanResult`](@ref) at fictitious time `s`,
returning `(u, uprime, physical_time)`.
"""
function levi_civita_sundman_state(result::LeviCivitaSundmanResult, s::Real)
    y = result.solution(s)
    return SVector(y[1], y[2]), SVector(y[3], y[4]), y[5]
end

"""
    levi_civita_cartesian_state(result, s)

Reconstruct Cartesian relative position and physical velocity from a numerical
[`LeviCivitaSundmanResult`](@ref) at fictitious time `s`.
"""
function levi_civita_cartesian_state(result::LeviCivitaSundmanResult, s::Real)
    u, w, _ = levi_civita_sundman_state(result, s)
    radius = dot(u, u)
    radius > zero(eltype(u)) ||
        throw(DomainError(radius, "Cartesian velocity is undefined at exact binary collision."))
    return levi_civita_position(u), levi_civita_velocity(u, w / radius)
end
