"""
    LeviCivitaOscillator

Initial data for the isolated planar Kepler problem written in Levi-Civita
coordinates and parameterized by fictitious time `s`.

The Sundman relation used by the later physical-time layer is `dt/ds = |u|²`,
but Stage 4A does not integrate physical time. With fixed specific Kepler
energy `h`, the regularized coordinate satisfies

`d²u/ds² = (h/2)u`.

`uprime0` is `du/ds`, not `du/dt`.
"""
struct LeviCivitaOscillator{T<:AbstractFloat}
    gravitational_parameter::T
    specific_energy::T
    u0::SVector{2,T}
    uprime0::SVector{2,T}
    branch::Int

    function LeviCivitaOscillator{T}(
        gravitational_parameter::T,
        specific_energy::T,
        u0::SVector{2,T},
        uprime0::SVector{2,T},
        branch::Int,
    ) where {T<:AbstractFloat}
        isfinite(gravitational_parameter) && gravitational_parameter > zero(T) ||
            throw(ArgumentError("gravitational_parameter must be finite and positive."))
        isfinite(specific_energy) || throw(ArgumentError("specific_energy must be finite."))
        all(isfinite, u0) || throw(ArgumentError("u0 must be finite."))
        all(isfinite, uprime0) || throw(ArgumentError("uprime0 must be finite."))
        branch in (-1, 1) || throw(ArgumentError("branch must be either 1 or -1."))
        new{T}(gravitational_parameter, specific_energy, u0, uprime0, branch)
    end
end

"""
    LeviCivitaOscillator(μ, q, qdot; branch=1)

Construct isolated planar Levi-Civita initial data from Cartesian relative
position `q`, Cartesian relative velocity `qdot`, and gravitational parameter
`μ`.

The Cartesian state must be non-collisional. The conversion first obtains
`du/dt` from [`to_levi_civita`](@ref), then uses `du/ds = |q| du/dt`.
"""
function LeviCivitaOscillator(
    μ::Real,
    q::AbstractVector{<:Real},
    qdot::AbstractVector{<:Real};
    branch::Integer=1,
)
    length(q) == 2 || throw(ArgumentError("q must contain two components."))
    length(qdot) == 2 || throw(ArgumentError("qdot must contain two components."))
    T = float(promote_type(typeof(μ), eltype(q), eltype(qdot)))
    μT = T(μ)
    qT = SVector{2,T}(q)
    qdotT = SVector{2,T}(qdot)
    μT > zero(T) && isfinite(μT) ||
        throw(ArgumentError("μ must be finite and positive."))
    all(isfinite, qT) || throw(ArgumentError("q must be finite."))
    all(isfinite, qdotT) || throw(ArgumentError("qdot must be finite."))

    lc = to_levi_civita(qT, qdotT; branch=branch)
    radius = norm(qT)
    h = dot(qdotT, qdotT) / T(2) - μT / radius
    uprime0 = radius * lc.udot
    LeviCivitaOscillator{T}(μT, h, lc.u, uprime0, Int(branch))
end

"""
    levi_civita_fictitious_state(oscillator, s)

Return the exact regularized state `(u, uprime)` at fictitious time `s` for an
isolated [`LeviCivitaOscillator`](@ref).

The implementation handles elliptic (`h < 0`), parabolic (`h == 0`), and
hyperbolic (`h > 0`) energy levels.
"""
function levi_civita_fictitious_state(
    oscillator::LeviCivitaOscillator{T},
    s::Real,
) where {T}
    sT = T(s)
    isfinite(sT) || throw(ArgumentError("s must be finite."))
    λ = oscillator.specific_energy / T(2)
    u0 = oscillator.u0
    w0 = oscillator.uprime0

    if λ < zero(T)
        ω = sqrt(-λ)
        c = cos(ω * sT)
        sn = sin(ω * sT)
        u = c * u0 + (sn / ω) * w0
        w = (-ω * sn) * u0 + c * w0
    elseif λ > zero(T)
        κ = sqrt(λ)
        c = cosh(κ * sT)
        sh = sinh(κ * sT)
        u = c * u0 + (sh / κ) * w0
        w = (κ * sh) * u0 + c * w0
    else
        u = u0 + sT * w0
        w = w0
    end

    return u, w
end

"""
    levi_civita_cartesian_state(oscillator, s)

Reconstruct Cartesian relative position and physical-time velocity at
fictitious time `s`.

At an exact collision (`u == 0`), the Cartesian position is well defined but
the Newtonian physical velocity is singular. In that case this function throws
`DomainError`; use [`levi_civita_fictitious_state`](@ref) to inspect the finite
regularized state through collision.
"""
function levi_civita_cartesian_state(
    oscillator::LeviCivitaOscillator{T},
    s::Real,
) where {T}
    u, w = levi_civita_fictitious_state(oscillator, s)
    radius = dot(u, u)
    radius > zero(T) || throw(DomainError(radius, "Cartesian velocity is undefined at exact binary collision."))
    q = levi_civita_position(u)
    qdot = levi_civita_velocity(u, w / radius)
    return q, qdot
end

"""
    LeviCivitaFictitiousResult

Numerical solution of the isolated Levi-Civita oscillator over a fixed
fictitious-time interval. `solution` is an OrdinaryDiffEq solution whose state
is `[u₁, u₂, u₁′, u₂′]`.
"""
struct LeviCivitaFictitiousResult{O,S}
    oscillator::O
    solution::S
end

"""
    integrate_levi_civita_fictitious(oscillator, sspan; kwargs...)

Numerically integrate the isolated Levi-Civita oscillator over fixed
fictitious-time interval `sspan`.

This Stage 4A function deliberately does not integrate physical time and uses
no callback. Keyword arguments are forwarded to `solve`; the defaults are
`Vern9()`, `reltol=1e-12`, and `abstol=1e-12` converted to the oscillator's
numeric type.
"""
function integrate_levi_civita_fictitious(
    oscillator::LeviCivitaOscillator{T},
    sspan::Tuple{<:Real,<:Real};
    algorithm=Vern9(),
    reltol=nothing,
    abstol=nothing,
    kwargs...,
) where {T}
    s0, s1 = T(sspan[1]), T(sspan[2])
    all(isfinite, (s0, s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    s1 != s0 || throw(ArgumentError("sspan endpoints must differ."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    rt > zero(T) && isfinite(rt) || throw(ArgumentError("reltol must be finite and positive."))
    at > zero(T) && isfinite(at) || throw(ArgumentError("abstol must be finite and positive."))

    y0 = SVector{4,T}(
        oscillator.u0[1], oscillator.u0[2],
        oscillator.uprime0[1], oscillator.uprime0[2],
    )
    function rhs(y, p, s)
        λ = p.specific_energy / T(2)
        SVector{4,T}(y[3], y[4], λ * y[1], λ * y[2])
    end
    problem = ODEProblem(rhs, y0, (s0, s1), oscillator)
    solution = solve(problem, algorithm; reltol=rt, abstol=at, kwargs...)
    SciMLBase.successful_retcode(solution) ||
        error("Levi-Civita fictitious-time integration failed with retcode $(solution.retcode).")
    LeviCivitaFictitiousResult(oscillator, solution)
end

"""
    levi_civita_fictitious_state(result, s)

Evaluate a numerical [`LeviCivitaFictitiousResult`](@ref) at fictitious time
`s`, returning `(u, uprime)`.
"""
function levi_civita_fictitious_state(result::LeviCivitaFictitiousResult, s::Real)
    y = result.solution(s)
    return SVector(y[1], y[2]), SVector(y[3], y[4])
end
