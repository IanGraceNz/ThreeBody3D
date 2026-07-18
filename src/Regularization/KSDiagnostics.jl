# Scale-aware diagnostics for the algebraic KS transformation layer.

function _ks_scale_floor(::Type{T}) where {T<:AbstractFloat}
    floatmin(T)
end

function _ks_scalar(value::Real, name::AbstractString, ::Type{T}) where {T<:AbstractFloat}
    converted = T(value)
    isfinite(converted) || throw(ArgumentError("$name must be finite."))
    converted
end

"""
    ks_radial_identity_residual(u)

Return the normalized residual of the KS radial identity
`norm(ks_position(u)) = dot(u, u)`.
"""
function ks_radial_identity_residual(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    physical_radius = norm(ks_position(uv))
    ks_radial = dot(uv, uv)
    scale = max(physical_radius, ks_radial, _ks_scale_floor(eltype(uv)))
    abs(physical_radius - ks_radial) / scale
end

"""
    ks_jacobian_identity_residual(u)

Return the normalized Frobenius residual of the KS Jacobian identity
`J(u)J(u)' = 4ρI₃`.
"""
function ks_jacobian_identity_residual(u::AbstractVector{<:Real})
    uv = _ks_vector4(u, "u")
    T = eltype(uv)
    jacobian_product = ks_jacobian(uv) * transpose(ks_jacobian(uv))
    rho = dot(uv, uv)
    four_rho = T(4) * rho
    target = SMatrix{3,3,T,9}(
        four_rho, zero(T), zero(T),
        zero(T), four_rho, zero(T),
        zero(T), zero(T), four_rho,
    )
    scale = max(norm(jacobian_product), norm(target), _ks_scale_floor(T))
    norm(jacobian_product - target) / scale
end

"""
    ks_scaled_constraint_residual(u, w)

Return the absolute KS bilinear-constraint residual normalized by
`norm(u) * norm(w)`. A floating-point scale floor prevents division by zero.
"""
function ks_scaled_constraint_residual(
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
    scale = max(norm(uv) * norm(wv), _ks_scale_floor(T))
    abs(ks_constraint_residual(uv, wv)) / scale
end

"""
    ks_position_roundtrip_residual(q)

Return the normalized Cartesian position residual after deterministic
Cartesian-to-KS lifting and KS-to-Cartesian reconstruction.
"""
function ks_position_roundtrip_residual(q::AbstractVector{<:Real})
    length(q) == 3 || throw(ArgumentError("q must contain three components."))
    T = float(eltype(q))
    qv = SVector{3,T}(q)
    all(isfinite, qv) || throw(ArgumentError("q must be finite."))
    u = cartesian_to_ks_position(qv)
    reconstructed = ks_position(u)
    scale = max(norm(qv), norm(reconstructed), _ks_scale_floor(T))
    norm(reconstructed - qv) / scale
end

"""
    ks_velocity_roundtrip_residual(q, v)

Return the normalized Cartesian velocity residual after lifting `(q, v)` to
KS coordinates and reconstructing the physical velocity.
"""
function ks_velocity_roundtrip_residual(
    q::AbstractVector{<:Real},
    v::AbstractVector{<:Real},
)
    length(q) == 3 || throw(ArgumentError("q must contain three components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    T = float(promote_type(eltype(q), eltype(v)))
    qv = SVector{3,T}(q)
    vv = SVector{3,T}(v)
    all(isfinite, qv) || throw(ArgumentError("q must be finite."))
    all(isfinite, vv) || throw(ArgumentError("v must be finite."))
    u, w = cartesian_to_ks_state(qv, vv)
    reconstructed = ks_to_cartesian_velocity(u, w)
    scale = max(norm(vv), norm(reconstructed), _ks_scale_floor(T))
    norm(reconstructed - vv) / scale
end

"""
    ks_energy_consistency_residual(u, w, h, mu)

Return the normalized collision-regular energy consistency residual
`abs(ρh - μ + 2dot(w,w))`. The denominator uses the magnitudes of all three
terms, so the result is dimensionless and remains finite at exact collision.
"""
function ks_energy_consistency_residual(
    u::AbstractVector{<:Real},
    w::AbstractVector{<:Real},
    h::Real,
    mu::Real,
)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    T = float(promote_type(eltype(u), eltype(w), typeof(h), typeof(mu)))
    uv = SVector{4,T}(u)
    wv = SVector{4,T}(w)
    all(isfinite, uv) || throw(ArgumentError("u must be finite."))
    all(isfinite, wv) || throw(ArgumentError("w must be finite."))
    hv = _ks_scalar(h, "h", T)
    muv = _ks_scalar(mu, "mu", T)

    radial_term = dot(uv, uv) * hv
    kinetic_term = T(2) * dot(wv, wv)
    residual = radial_term - muv + kinetic_term
    scale = max(abs(radial_term), abs(muv), abs(kinetic_term), _ks_scale_floor(T))
    abs(residual) / scale
end
