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

function _ks_gauge_inputs(
    u::AbstractVector{<:Real},
    phi::Real,
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    T = float(promote_type(eltype(u), typeof(phi)))
    uv = SVector{4,T}(u)
    phiv = T(phi)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    isfinite(phiv) || throw(ArgumentError("phi must be finite."))
    uv, phiv
end

"""
    ks_gauge_transform(u, phi)

Apply the finite one-parameter gauge action of the fixed classical KS1
convention to the KS position coordinate `u`.

The Cartesian position and KS radius are invariant under this transformation.
"""
function ks_gauge_transform(u::AbstractVector{<:Real}, phi::Real)
    uv, phiv = _ks_gauge_inputs(u, phi)
    T = eltype(uv)
    u1, u2, u3, u4 = uv
    cosine = cos(phiv)
    sine = sin(phiv)

    SVector{4,T}(
        cosine * u1 + sine * u4,
        cosine * u2 - sine * u3,
        sine * u2 + cosine * u3,
       -sine * u1 + cosine * u4,
    )
end

"""
    ks_gauge_transform(u, w, phi)

Apply the same finite KS gauge transformation to the coordinate `u` and its
fictitious-time derivative `w`. Return `(transformed_u, transformed_w)`.
"""
function ks_gauge_transform(
    u::AbstractVector{<:Real},
    w::AbstractVector{<:Real},
    phi::Real,
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    T = float(promote_type(eltype(u), eltype(w), typeof(phi)))
    uv = SVector{4,T}(u)
    wv = SVector{4,T}(w)
    phiv = T(phi)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, wv) || throw(ArgumentError("w must be finite."))
    isfinite(phiv) || throw(ArgumentError("phi must be finite."))

    transformed_u = ks_gauge_transform(uv, phiv)
    transformed_w = ks_gauge_transform(wv, phiv)
    transformed_u, transformed_w
end

"""
    align_ks_gauge(u, w, reference_u)

Choose the representative on the gauge fiber through `(u, w)` that maximizes
its Euclidean alignment with `reference_u`. The same gauge action is applied
to `u` and `w`, and the aligned pair is returned.
"""
function align_ks_gauge(
    u::AbstractVector{<:Real},
    w::AbstractVector{<:Real},
    reference_u::AbstractVector{<:Real},
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    length(reference_u) == 4 ||
        throw(ArgumentError("reference_u must contain four components."))

    T = float(promote_type(eltype(u), eltype(w), eltype(reference_u)))
    uv = SVector{4,T}(u)
    wv = SVector{4,T}(w)
    reference = SVector{4,T}(reference_u)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, wv) || throw(ArgumentError("w must be finite."))
    all(isfinite, reference) ||
        throw(ArgumentError("reference_u must be finite."))

    a = dot(uv, reference)
    b = dot(ks_gauge_direction(uv), reference)
    phi = atan(b, a)
    ks_gauge_transform(uv, wv, phi)
end

"""
    cartesian_to_ks_position(q; reference=nothing)

Lift a nonzero three-dimensional Cartesian relative position `q` to the
fixed classical KS1 coordinate convention.

The deterministic two-chart construction selects the chart with the larger
analytic denominator. When `reference` is supplied, the resulting coordinate
is aligned over the complete gauge fiber with that prior KS representative.
Exact Cartesian collision is rejected because a history-free inverse lift is
not defined there.
"""
function cartesian_to_ks_position(
    q::AbstractVector{<:Real};
    reference::Union{Nothing,AbstractVector{<:Real}}=nothing,
)
    length(q) == 3 || throw(ArgumentError("q must contain three components."))
    reference === nothing || length(reference) == 4 ||
        throw(ArgumentError("reference must contain four components."))

    T = reference === nothing ?
        float(eltype(q)) :
        float(promote_type(eltype(q), eltype(reference)))
    qv = SVector{3,T}(q)
    all(isfinite, qv) || throw(ArgumentError("q must be finite."))

    reference_v = if reference === nothing
        nothing
    else
        value = SVector{4,T}(reference)
        all(isfinite, value) || throw(ArgumentError("reference must be finite."))
        value
    end

    x, y, z = qv
    rho = norm(qv)
    iszero(rho) && throw(DomainError(qv, "a Cartesian-to-KS lift is undefined at exact collision."))

    two = T(2)
    candidate = if x >= zero(T)
        radicand = max(two * (rho + x), zero(T))
        denominator = sqrt(radicand)
        SVector{4,T}(
            zero(T),
            -z / denominator,
            y / denominator,
            -denominator / two,
        )
    else
        radicand = max(two * (rho - x), zero(T))
        denominator = sqrt(radicand)
        SVector{4,T}(
            y / denominator,
            denominator / two,
            zero(T),
            z / denominator,
        )
    end

    reference_v === nothing && return candidate

    a = dot(candidate, reference_v)
    b = dot(ks_gauge_direction(candidate), reference_v)
    ks_gauge_transform(candidate, atan(b, a))
end

"""
    cartesian_to_ks_velocity(u, v)

Return the horizontal KS fictitious-time velocity corresponding to the
Cartesian relative velocity `v` at the nonzero KS coordinate `u`.

The lift is `w = J(u)'v / 4` and therefore satisfies the classical KS
bilinear constraint to roundoff.
"""
function cartesian_to_ks_velocity(
    u::AbstractVector{<:Real},
    v::AbstractVector{<:Real},
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    T = float(promote_type(eltype(u), eltype(v)))
    uv = SVector{4,T}(u)
    vv = SVector{3,T}(v)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, vv) || throw(ArgumentError("v must be finite."))

    T(1//4) * transpose(ks_jacobian(uv)) * vv
end

"""
    ks_to_cartesian_velocity(u, w)

Reconstruct Cartesian relative velocity from a KS coordinate `u` and its
fictitious-time derivative `w` using `v = J(u)w / ρ`.

Exact collision is rejected because Cartesian velocity reconstruction is
singular at `ρ = 0` even though the regularized KS state may remain finite.
"""
function ks_to_cartesian_velocity(
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

    rho = dot(uv, uv)
    iszero(rho) && throw(DomainError(uv, "Cartesian velocity reconstruction is undefined at exact collision."))
    ks_jacobian(uv) * wv / rho
end

"""
    cartesian_to_ks_state(q, v; reference=nothing)

Lift a noncollision Cartesian relative position and velocity to a KS position
coordinate and its horizontal fictitious-time derivative. Return `(u, w)`.

When `reference` is supplied, the deterministic position lift is gauge-aligned
to that prior KS representative before the velocity is lifted.
"""
function cartesian_to_ks_state(
    q::AbstractVector{<:Real},
    v::AbstractVector{<:Real};
    reference::Union{Nothing,AbstractVector{<:Real}}=nothing,
)
    length(q) == 3 || throw(ArgumentError("q must contain three components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    T = reference === nothing ?
        float(promote_type(eltype(q), eltype(v))) :
        float(promote_type(eltype(q), eltype(v), eltype(reference)))
    qv = SVector{3,T}(q)
    vv = SVector{3,T}(v)
    all(isfinite, qv) || throw(ArgumentError("q must be finite."))
    all(isfinite, vv) || throw(ArgumentError("v must be finite."))

    u = cartesian_to_ks_position(qv; reference=reference)
    w = cartesian_to_ks_velocity(u, vv)
    u, w
end
