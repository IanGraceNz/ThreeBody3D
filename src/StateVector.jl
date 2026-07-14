"""Number of floating-point elements in a ThreeBody3D solver state."""
const STATE_SIZE = 18

"""
    statevector(r1, v1, r2, v2, r3, v3)

Construct the 18-element solver state `[r1; v1; r2; v2; r3; v3]` from six
three-component vectors. Real inputs are promoted to a common floating type.
"""
function statevector(vectors::Vararg{AbstractVector{<:Real},6})
    all(length(v) == 3 for v in vectors) ||
        throw(ArgumentError("Every position and velocity must contain three components."))
    T = float(promote_type(map(v -> eltype(v), vectors)...))
    u = Vector{T}(undef, STATE_SIZE)
    k = 1
    for v in vectors, x in v
        u[k] = x
        k += 1
    end
    all(isfinite, u) || throw(ArgumentError("State values must be finite."))
    u
end

"""Return body `i`'s three-dimensional position from a solver state."""
@inline function body_position(u::AbstractVector{T}, i::Integer) where {T<:AbstractFloat}
    length(u) == STATE_SIZE || throw(ArgumentError("State must contain $STATE_SIZE elements."))
    1 <= i <= 3 || throw(BoundsError(u, i))
    j = 6(i - 1)
    SVector{3,T}(u[j+1], u[j+2], u[j+3])
end

"""Return body `i`'s three-dimensional velocity from a solver state."""
@inline function velocity(u::AbstractVector{T}, i::Integer) where {T<:AbstractFloat}
    length(u) == STATE_SIZE || throw(ArgumentError("State must contain $STATE_SIZE elements."))
    1 <= i <= 3 || throw(BoundsError(u, i))
    j = 6(i - 1)
    SVector{3,T}(u[j+4], u[j+5], u[j+6])
end

function validate_state(u::AbstractVector)
    length(u) == STATE_SIZE || throw(ArgumentError("State must contain $STATE_SIZE elements."))
    eltype(u) <: AbstractFloat || throw(ArgumentError("State values must be floating point."))
    all(isfinite, u) || throw(ArgumentError("State values must be finite."))
    true
end
