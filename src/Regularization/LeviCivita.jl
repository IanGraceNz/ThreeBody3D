"""
    LeviCivitaCoordinates

Planar Levi-Civita coordinates and their derivative with respect to physical
time.

The quadratic map is

`q₁ = u₁² - u₂²`, `q₂ = 2u₁u₂`.

`u` and `-u` describe the same Cartesian position. To preserve the Cartesian
velocity, the corresponding coordinate velocities must also change sign.
This type is an algebraic Stage 3 building block; it does not yet introduce
fictitious time or integrate regularized equations.
"""
struct LeviCivitaCoordinates{T<:AbstractFloat}
    u::SVector{2,T}
    udot::SVector{2,T}

    function LeviCivitaCoordinates{T}(
        u::SVector{2,T},
        udot::SVector{2,T},
    ) where {T<:AbstractFloat}
        all(isfinite, u) || throw(ArgumentError("Levi-Civita coordinates must be finite."))
        all(isfinite, udot) || throw(ArgumentError("Levi-Civita coordinate velocities must be finite."))
        new{T}(u, udot)
    end
end

function LeviCivitaCoordinates(
    u::AbstractVector{<:Real},
    udot::AbstractVector{<:Real},
)
    length(u) == 2 || throw(ArgumentError("u must contain two components."))
    length(udot) == 2 || throw(ArgumentError("udot must contain two components."))
    T = float(promote_type(eltype(u), eltype(udot)))
    LeviCivitaCoordinates{T}(SVector{2,T}(u), SVector{2,T}(udot))
end

"""
    levi_civita_position(u)

Map a two-component Levi-Civita coordinate `u` to the planar Cartesian relative
position `(u₁²-u₂², 2u₁u₂)`.

The map is regular at `u == 0` and is invariant under `u -> -u`.
"""
function levi_civita_position(u::AbstractVector{<:Real})
    length(u) == 2 || throw(ArgumentError("u must contain two components."))
    T = float(eltype(u))
    uv = SVector{2,T}(u)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    u1, u2 = uv
    SVector{2,T}(u1^2 - u2^2, T(2) * u1 * u2)
end

"""
    levi_civita_velocity(u, udot)

Map a Levi-Civita coordinate and its physical-time derivative to Cartesian
relative velocity. The Jacobian relation is

`qdot = 2 * [u₁ -u₂; u₂ u₁] * udot`.

At `u == 0`, every finite `udot` maps to zero Cartesian velocity. The later
Sundman formulation will use fictitious-time derivatives instead; this Stage 3
function is only the ordinary algebraic velocity map.
"""
function levi_civita_velocity(
    u::AbstractVector{<:Real},
    udot::AbstractVector{<:Real},
)
    length(u) == 2 || throw(ArgumentError("u must contain two components."))
    length(udot) == 2 || throw(ArgumentError("udot must contain two components."))
    T = float(promote_type(eltype(u), eltype(udot)))
    uv = SVector{2,T}(u)
    vv = SVector{2,T}(udot)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, vv) || throw(ArgumentError("udot must be finite."))
    u1, u2 = uv
    v1, v2 = vv
    SVector{2,T}(
        T(2) * (u1 * v1 - u2 * v2),
        T(2) * (u2 * v1 + u1 * v2),
    )
end

"""
    from_levi_civita(coordinates)

Reconstruct planar Cartesian relative position and velocity from
[`LeviCivitaCoordinates`](@ref). Returns `(q, qdot)`.
"""
function from_levi_civita(coordinates::LeviCivitaCoordinates)
    levi_civita_position(coordinates.u),
    levi_civita_velocity(coordinates.u, coordinates.udot)
end

"""
    to_levi_civita(q, qdot; branch=1)

Initialize planar Levi-Civita coordinates from a nonzero Cartesian relative
position `q` and velocity `qdot`.

`branch` must be `1` or `-1` and selects the two equivalent square-root gauges.
The inverse is undefined at `q == 0`, so collision initialization throws a
`DomainError`. A trajectory already represented in Levi-Civita variables may,
however, pass through `u == 0` using the forward map.
"""
function to_levi_civita(
    q::AbstractVector{<:Real},
    qdot::AbstractVector{<:Real};
    branch::Integer=1,
)
    length(q) == 2 || throw(ArgumentError("q must contain two components."))
    length(qdot) == 2 || throw(ArgumentError("qdot must contain two components."))
    branch in (-1, 1) || throw(ArgumentError("branch must be either 1 or -1."))

    T = float(promote_type(eltype(q), eltype(qdot)))
    qv = SVector{2,T}(q)
    qdv = SVector{2,T}(qdot)
    all(isfinite, qv) || throw(ArgumentError("q must be finite."))
    all(isfinite, qdv) || throw(ArgumentError("qdot must be finite."))

    q1, q2 = qv
    radius = norm(qv)
    radius > zero(T) || throw(DomainError(radius, "Levi-Civita inverse initialization is undefined at collision."))

    # Principal complex square root, evaluated with a branch that avoids
    # subtractive cancellation and division by a nearly zero component.
    if q1 >= zero(T)
        u1 = sqrt((radius + q1) / T(2))
        u2 = q2 / (T(2) * u1)
    else
        magnitude = sqrt((radius - q1) / T(2))
        u2 = q2 < zero(T) ? -magnitude : magnitude
        u1 = q2 / (T(2) * u2)
    end

    gauge = T(branch)
    u = gauge * SVector{2,T}(u1, u2)
    u1g, u2g = u
    denominator = T(2) * radius
    udot = SVector{2,T}(
        (u1g * qdv[1] + u2g * qdv[2]) / denominator,
        (-u2g * qdv[1] + u1g * qdv[2]) / denominator,
    )

    LeviCivitaCoordinates{T}(u, udot)
end
