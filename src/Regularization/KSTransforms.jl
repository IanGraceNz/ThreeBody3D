# Pure algebraic transformations for the fixed classical KS1 convention.

function _ks_vector4(u::AbstractVector{<:Real}, name::AbstractString)
    length(u) == 4 || throw(ArgumentError("$name must contain four components."))
    T = float(eltype(u))
    result = SVector{4,T}(u)
    all(isfinite, result) || throw(ArgumentError("$name must be finite."))
    result
end

"""
    ks_position(u)

Map a four-component Kustaanheimo–Stiefel coordinate to the three-dimensional
Cartesian relative position using the fixed classical KS1 convention.

This is an internal experimental operation governed by
`KS_REGULARIZATION_DESIGN.md`.
"""
function ks_position(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    T = eltype(uv)
    u1, u2, u3, u4 = uv
    two = T(2)
    SVector{3,T}(
        u1^2 - u2^2 - u3^2 + u4^2,
        two * (u1 * u2 - u3 * u4),
        two * (u1 * u3 + u2 * u4),
    )
end

"""
    ks_radius(u)

Return the Cartesian separation represented by the KS coordinate `u`. For the
fixed KS1 map this is exactly `dot(u, u)` in exact arithmetic.
"""
function ks_radius(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    dot(uv, uv)
end

"""
    ks_jacobian(u)

Return the analytic `3 × 4` Jacobian of [`ks_position`](@ref) for the fixed
classical KS1 convention.
"""
function ks_jacobian(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    T = eltype(uv)
    u1, u2, u3, u4 = uv
    two = T(2)

    # SMatrix constructors consume entries in column-major order.
    SMatrix{3,4,T,12}(
        two * u1,  two * u2,  two * u3,
       -two * u2,  two * u1,  two * u4,
       -two * u3, -two * u4,  two * u1,
        two * u4, -two * u3,  two * u2,
    )
end

"""
    ks_gauge_direction(u)

Return the tangent direction of the one-dimensional KS gauge fiber through
`u`. The analytic Jacobian annihilates this direction.
"""
function ks_gauge_direction(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    T = eltype(uv)
    u1, u2, u3, u4 = uv
    SVector{4,T}(u4, -u3, u2, -u1)
end

"""
    ks_constraint_residual(u, w)

Return the signed classical KS bilinear-constraint residual
`dot(ks_gauge_direction(u), w)`.
"""
function ks_constraint_residual(
    u::AbstractVector{<:Real},
    w::AbstractVector{<:Real},
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    T = float(promote_type(eltype(u), eltype(w)))
    uv = SVector{4,T}(u)
    wv = SVector{4,T}(w)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, wv) || throw(ArgumentError("w must be finite."))
    u1, u2, u3, u4 = uv
    dot(SVector{4,T}(u4, -u3, u2, -u1), wv)
end
