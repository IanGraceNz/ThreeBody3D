"""
    PairCoordinates

Mass-weighted coordinates for one ordered binary pair in a three-body state.

For `pair == (i, j)`, `relative_position` and `relative_velocity` are defined as
body `i` minus body `j`. The binary centre-of-mass quantities use the physical
masses of bodies `i` and `j`. `third_position` and `third_velocity` describe the
remaining body. The representation is algebraically reversible through
[`from_pair_coordinates`](@ref).

This type is an experimental v0.4 regularization building block. It does not
alter the equations of motion or regularize a collision by itself.
"""
struct PairCoordinates{T<:AbstractFloat}
    relative_position::SVector{3,T}
    relative_velocity::SVector{3,T}
    binary_com_position::SVector{3,T}
    binary_com_velocity::SVector{3,T}
    third_position::SVector{3,T}
    third_velocity::SVector{3,T}
    pair::Tuple{Int,Int}
    third::Int
end

@inline function _validate_pair(pair::Tuple{<:Integer,<:Integer})
    i, j = pair
    1 <= i <= 3 || throw(ArgumentError("Pair indices must lie in 1:3."))
    1 <= j <= 3 || throw(ArgumentError("Pair indices must lie in 1:3."))
    i != j || throw(ArgumentError("A binary pair must contain two distinct bodies."))
    (Int(i), Int(j), 6 - Int(i) - Int(j))
end

"""
    to_pair_coordinates(system, u, pair)

Convert the physical solver state `u` to mass-weighted coordinates for the
ordered binary `pair = (i, j)`.

The returned relative vectors are oriented from body `j` to body `i`:
`rᵢ - rⱼ` and `vᵢ - vⱼ`. Reversing the pair reverses those two vectors while
leaving the binary centre of mass and reconstructed physical state unchanged.

The state and system values are promoted to a common floating-point type. This
function is algebraic only; it performs no integration or regularization.
"""
function to_pair_coordinates(
    system::ThreeBodySystem,
    u::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer},
)
    validate_state(u)
    i, j, k = _validate_pair(pair)
    T = float(promote_type(eltype(system.masses), eltype(u)))

    mi = T(mass(system, i))
    mj = T(mass(system, j))
    binary_mass = mi + mj

    ri = SVector{3,T}(body_position(u, i))
    rj = SVector{3,T}(body_position(u, j))
    rk = SVector{3,T}(body_position(u, k))
    vi = SVector{3,T}(velocity(u, i))
    vj = SVector{3,T}(velocity(u, j))
    vk = SVector{3,T}(velocity(u, k))

    PairCoordinates{T}(
        ri - rj,
        vi - vj,
        (mi * ri + mj * rj) / binary_mass,
        (mi * vi + mj * vj) / binary_mass,
        rk,
        vk,
        (i, j),
        k,
    )
end

"""
    from_pair_coordinates(system, coordinates)

Reconstruct the ordinary 18-element solver state from [`PairCoordinates`](@ref).

The bodies are restored in their original numerical order, independent of the
ordered pair orientation used to form `coordinates`. The returned element type
is the common floating-point type of the system and coordinate values.
"""
function from_pair_coordinates(
    system::ThreeBodySystem,
    coordinates::PairCoordinates,
)
    i, j, k = _validate_pair(coordinates.pair)
    k == coordinates.third ||
        throw(ArgumentError("PairCoordinates has inconsistent third-body metadata."))

    T = float(promote_type(eltype(system.masses),
                           eltype(coordinates.relative_position)))
    mi = T(mass(system, i))
    mj = T(mass(system, j))
    binary_mass = mi + mj

    q = SVector{3,T}(coordinates.relative_position)
    qdot = SVector{3,T}(coordinates.relative_velocity)
    R = SVector{3,T}(coordinates.binary_com_position)
    V = SVector{3,T}(coordinates.binary_com_velocity)

    positions = Vector{SVector{3,T}}(undef, 3)
    velocities = Vector{SVector{3,T}}(undef, 3)

    positions[i] = R + (mj / binary_mass) * q
    positions[j] = R - (mi / binary_mass) * q
    positions[k] = SVector{3,T}(coordinates.third_position)

    velocities[i] = V + (mj / binary_mass) * qdot
    velocities[j] = V - (mi / binary_mass) * qdot
    velocities[k] = SVector{3,T}(coordinates.third_velocity)

    statevector(
        positions[1], velocities[1],
        positions[2], velocities[2],
        positions[3], velocities[3],
    )
end
