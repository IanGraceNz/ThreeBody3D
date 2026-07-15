"""
    KeplerReference(μ, r0, v0)

Analytic two-body reference problem for relative motion under
`r̈ = -μ r / |r|³`. `r0` and `v0` are three-component initial relative
position and velocity vectors.

The constructor promotes all values to a common floating-point type and rejects
non-finite data, non-positive `μ`, and an initial collision. This type is a
validation aid for regularization development; it does not alter ThreeBody3D's
production integrator.
"""
struct KeplerReference{T<:AbstractFloat}
    μ::T
    r0::SVector{3,T}
    v0::SVector{3,T}
end

function KeplerReference(μ::Real, r0::AbstractVector{<:Real},
                         v0::AbstractVector{<:Real})
    length(r0) == 3 || throw(ArgumentError("r0 must contain three components."))
    length(v0) == 3 || throw(ArgumentError("v0 must contain three components."))
    T = float(promote_type(typeof(μ), eltype(r0), eltype(v0)))
    μT = T(μ)
    r = SVector{3,T}(r0)
    v = SVector{3,T}(v0)
    isfinite(μT) && μT > zero(T) || throw(ArgumentError("μ must be finite and positive."))
    all(isfinite, r) || throw(ArgumentError("r0 must be finite."))
    all(isfinite, v) || throw(ArgumentError("v0 must be finite."))
    norm(r) > zero(T) || throw(ArgumentError("The initial relative position cannot be zero."))
    KeplerReference{T}(μT, r, v)
end

"""Return the specific orbital energy `|v|²/2 - μ/|r|`."""
function kepler_specific_energy(μ::Real, r::AbstractVector, v::AbstractVector)
    length(r) == 3 || throw(ArgumentError("r must contain three components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    norm(r) > zero(eltype(r)) || throw(DomainError(norm(r), "Energy is singular at collision."))
    dot(v, v) / 2 - μ / norm(r)
end

"""Return the specific angular-momentum vector `r × v`."""
function kepler_angular_momentum(r::AbstractVector, v::AbstractVector)
    length(r) == 3 || throw(ArgumentError("r must contain three components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    T = float(promote_type(eltype(r), eltype(v)))
    cross(SVector{3,T}(r), SVector{3,T}(v))
end

@inline function _stumpff_c(z::T) where {T<:AbstractFloat}
    cutoff = sqrt(sqrt(eps(T)))
    if abs(z) < cutoff
        term = one(T) / T(2)
        total = term
        for k in 1:12
            term *= -z / (T(2k + 1) * T(2k + 2))
            total += term
            abs(term) <= eps(T) * max(one(T), abs(total)) && break
        end
        return total
    elseif z > zero(T)
        s = sqrt(z)
        return (one(T) - cos(s)) / z
    else
        s = sqrt(-z)
        return (cosh(s) - one(T)) / (-z)
    end
end

@inline function _stumpff_s(z::T) where {T<:AbstractFloat}
    cutoff = sqrt(sqrt(eps(T)))
    if abs(z) < cutoff
        term = one(T) / T(6)
        total = term
        for k in 1:12
            term *= -z / (T(2k + 2) * T(2k + 3))
            total += term
            abs(term) <= eps(T) * max(one(T), abs(total)) && break
        end
        return total
    elseif z > zero(T)
        s = sqrt(z)
        return (s - sin(s)) / (s^3)
    else
        s = sqrt(-z)
        return (sinh(s) - s) / (s^3)
    end
end

function _universal_kepler_equation(reference::KeplerReference{T}, χ::T, Δt::T) where {T}
    μ, r0v, v0v = reference.μ, reference.r0, reference.v0
    r0 = norm(r0v)
    sqrtμ = sqrt(μ)
    radial = dot(r0v, v0v) / sqrtμ
    α = T(2) / r0 - dot(v0v, v0v) / μ
    z = α * χ^2
    C = _stumpff_c(z)
    S = _stumpff_s(z)
    F = radial * χ^2 * C + (one(T) - α * r0) * χ^3 * S + r0 * χ - sqrtμ * Δt
    dF = radial * χ * (one(T) - z * S) +
         (one(T) - α * r0) * χ^2 * C + r0
    F, dF
end

function _initial_universal_anomaly(reference::KeplerReference{T}, Δt::T) where {T}
    r0 = norm(reference.r0)
    α = T(2) / r0 - dot(reference.v0, reference.v0) / reference.μ
    scale = sqrt(reference.μ) * Δt
    if abs(α) > sqrt(eps(T)) / r0
        return scale * abs(α)
    end
    scale / r0
end

"""
    kepler_state(reference, Δt; tolerance=nothing, max_iterations=80)

Propagate an analytic two-body relative state by elapsed time `Δt` using the
universal-variable Kepler equation. The same formulation supports elliptic,
near-parabolic, hyperbolic, and radial trajectories up to (but not through) a
physical collision.

Returns `(position, velocity)` as static three-vectors. The calculation is
type-generic and supports `Float64` and `BigFloat` reference work.
"""
function kepler_state(reference::KeplerReference{T}, Δt::Real;
                      tolerance=nothing, max_iterations::Integer=80) where {T}
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    t = T(Δt)
    isfinite(t) || throw(ArgumentError("Δt must be finite."))
    iszero(t) && return reference.r0, reference.v0

    tol = isnothing(tolerance) ? T(16) * eps(T) : T(tolerance)

    isfinite(tol) && tol > zero(T) || throw(ArgumentError("tolerance must be finite and positive."))

    χ = _initial_universal_anomaly(reference, t)
    converged = false
    for _ in 1:max_iterations
        F, dF = _universal_kepler_equation(reference, χ, t)
        iszero(dF) && throw(ErrorException("Universal Kepler iteration encountered a zero derivative."))
        step = F / dF
        χ -= step
        if abs(step) <= tol * max(one(T), abs(χ))
            converged = true
            break
        end
    end
    converged || throw(ErrorException("Universal Kepler iteration did not converge."))

    μ = reference.μ
    r0 = norm(reference.r0)
    sqrtμ = sqrt(μ)
    α = T(2) / r0 - dot(reference.v0, reference.v0) / μ
    z = α * χ^2
    C = _stumpff_c(z)
    S = _stumpff_s(z)

    f = one(T) - χ^2 * C / r0
    g = t - χ^3 * S / sqrtμ
    rvec = f * reference.r0 + g * reference.v0
    r = norm(rvec)
    r > zero(T) || throw(DomainError(r, "The propagated state reached collision."))

    fdot = sqrtμ * (α * χ^3 * S - χ) / (r * r0)
    gdot = one(T) - χ^2 * C / r
    vvec = fdot * reference.r0 + gdot * reference.v0
    rvec, vvec
end

"""
    radial_free_fall_time(μ, initial_radius)

Return the exact collision time for a particle released from rest at radius
`initial_radius` in the Kepler field `r̈ = -μ r/|r|³`:
`π*sqrt(initial_radius^3/(8μ))`.
"""
function radial_free_fall_time(μ::Real, initial_radius::Real)
    T = float(promote_type(typeof(μ), typeof(initial_radius)))
    μT, radius = T(μ), T(initial_radius)
    isfinite(μT) && μT > zero(T) || throw(ArgumentError("μ must be finite and positive."))
    isfinite(radius) && radius > zero(T) || throw(ArgumentError("initial_radius must be finite and positive."))
    T(pi) * sqrt(radius^3 / (T(8) * μT))
end

function _radial_fall_parameter(τ::T; tolerance::T, max_iterations::Int) where {T}
    zero(T) <= τ <= T(pi) || throw(ArgumentError("Scaled radial-fall time must lie in [0, π]."))
    lo, hi = zero(T), T(pi)
    η = τ
    for _ in 1:max_iterations
        value = η + sin(η) - τ
        abs(value) <= tolerance && return η
        if value > zero(T)
            hi = η
        else
            lo = η
        end
        derivative = one(T) + cos(η)
        candidate = derivative > sqrt(eps(T)) ? η - value / derivative : (lo + hi) / T(2)
        η = lo < candidate < hi ? candidate : (lo + hi) / T(2)
    end
    throw(ErrorException("Radial free-fall parameter iteration did not converge."))
end

"""
    radial_free_fall_state(μ, initial_position, t; tolerance=nothing,
                           max_iterations=100)

Exact relative state for radial Kepler fall from rest at `initial_position`.
Valid from `t = 0` up to, but not including, the collision time returned by
[`radial_free_fall_time`](@ref).
"""
function radial_free_fall_state(μ::Real, initial_position::AbstractVector{<:Real},
                                t::Real; tolerance=nothing,
                                max_iterations::Integer=100)
    length(initial_position) == 3 || throw(ArgumentError("initial_position must contain three components."))
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    T = float(promote_type(typeof(μ), eltype(initial_position), typeof(t)))
    r0vec = SVector{3,T}(initial_position)
    r0 = norm(r0vec)
    r0 > zero(T) || throw(ArgumentError("initial_position cannot be zero."))
    μT, time = T(μ), T(t)
    collision_time = radial_free_fall_time(μT, r0)
    zero(T) <= time < collision_time || throw(ArgumentError("t must satisfy 0 ≤ t < the collision time."))
    iszero(time) && return r0vec, zero(r0vec)

    tol = isnothing(tolerance) ? T(16) * eps(T) : T(tolerance)

    tol > zero(T) || throw(ArgumentError("tolerance must be positive."))
    scale = sqrt(r0^3 / (T(8) * μT))
    τ = time / scale
    η = _radial_fall_parameter(τ; tolerance=tol, max_iterations=Int(max_iterations))
    radius = r0 * (one(T) + cos(η)) / T(2)
    direction = r0vec / r0
    speed = sqrt(T(2) * μT * (one(T) / radius - one(T) / r0))
    radius * direction, -speed * direction
end
