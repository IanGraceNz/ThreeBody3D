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

"""
    levi_civita_fictitious_time(oscillator, target_time;
                                initial_time=0, tolerance=nothing,
                                initial_step=1, max_iterations=256)

Invert the exact Sundman map and return the fictitious time `s` satisfying
`levi_civita_physical_time(oscillator, s; initial_time) == target_time`.

The method first expands a bracket in the required time direction and then
uses bisection. It uses no ODE callback and is valid for forward and backward
queries. The physical-time map is monotone. At a regularized radial collision
its derivative vanishes, so the inverse is locally ill-conditioned: the
returned physical time remains accurate, while the corresponding fictitious
time may be less accurate in finite precision.
"""
function levi_civita_fictitious_time(
    oscillator::LeviCivitaOscillator{T},
    target_time::Real;
    initial_time::Real=zero(T),
    tolerance=nothing,
    initial_step::Real=one(T),
    max_iterations::Integer=256,
) where {T}
    target = T(target_time)
    t0 = T(initial_time)
    step0 = T(initial_step)
    all(isfinite, (target, t0, step0)) ||
        throw(ArgumentError("target_time, initial_time, and initial_step must be finite."))
    step0 > zero(T) || throw(ArgumentError("initial_step must be positive."))
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))

    Δt = target - t0
    iszero(Δt) && return zero(T)
    direction = sign(Δt)
    tol = isnothing(tolerance) ? T(64) * eps(T) * max(one(T), abs(target), abs(t0)) : T(tolerance)
    isfinite(tol) && tol > zero(T) ||
        throw(ArgumentError("tolerance must be finite and positive."))

    f(s) = levi_civita_physical_time(oscillator, s; initial_time=t0) - target
    a = zero(T)
    fa = -Δt
    b = direction * step0
    fb = f(b)

    expansions = 0
    while signbit(fa) == signbit(fb) && !iszero(fb)
        expansions += 1
        expansions <= max_iterations ||
            throw(ErrorException("Unable to bracket the requested physical time."))
        b *= T(2)
        isfinite(b) || throw(ErrorException("Fictitious-time bracket overflowed."))
        fb = f(b)
    end
    iszero(fb) && return b

    left, right = minmax(a, b)
    fleft = f(left)
    fright = f(right)
    signbit(fleft) != signbit(fright) ||
        throw(ErrorException("Internal error: physical-time root is not bracketed."))

    for _ in 1:max_iterations
        midpoint = (left + right) / T(2)
        fm = f(midpoint)
        time_converged = abs(fm) <= tol
        bracket_converged =
            abs(right - left) <= T(32) * eps(T) * max(one(T), abs(midpoint))
        if time_converged && bracket_converged
            return midpoint
        end
        if signbit(fleft) == signbit(fm)
            left = midpoint
            fleft = fm
        else
            right = midpoint
            fright = fm
        end
    end

    throw(ErrorException("Physical-to-fictitious time inversion did not converge."))
end

"""
    levi_civita_state_at_time(oscillator, target_time; kwargs...)

Return the isolated Levi-Civita state at an exact requested physical time.
The Sundman map is inverted with [`levi_civita_fictitious_time`](@ref), after
which the exact regularized oscillator is evaluated and reconstructed.

The returned named tuple contains `physical_time`, `fictitious_time`,
`regularized_position`, `regularized_derivative`, `position`, and `velocity`.
At an exact binary collision the physical velocity is singular and a
`DomainError` is thrown; the fictitious time can still be obtained separately.
"""
function levi_civita_state_at_time(
    oscillator::LeviCivitaOscillator{T},
    target_time::Real;
    initial_time::Real=zero(T),
    kwargs...,
) where {T}
    target = T(target_time)
    s = levi_civita_fictitious_time(
        oscillator, target; initial_time=initial_time, kwargs...,
    )
    u, w = levi_civita_fictitious_state(oscillator, s)
    radius = dot(u, u)
    radius > zero(T) ||
        throw(DomainError(radius, "Cartesian velocity is undefined at exact binary collision."))
    q = levi_civita_position(u)
    qdot = levi_civita_velocity(u, w / radius)
    return (
        physical_time=target,
        fictitious_time=s,
        regularized_position=u,
        regularized_derivative=w,
        position=q,
        velocity=qdot,
    )
end
