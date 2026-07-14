@inline function _inverse_cube(d::SVector{3,T}) where {T<:AbstractFloat}
    r2 = dot(d, d)
    iszero(r2) && throw(DomainError(r2, "Two bodies occupy the same position; Newtonian acceleration is singular."))
    inv(r2 * sqrt(r2))
end

"""Internal in-place Newtonian equations of motion."""
function threebody!(du, u, system::ThreeBodySystem, _t)
    validate_state(u)
    length(du) == STATE_SIZE || throw(ArgumentError("Derivative must contain $STATE_SIZE elements."))

    r1, r2, r3 = body_position(u, 1), body_position(u, 2), body_position(u, 3)
    v1, v2, v3 = velocity(u, 1), velocity(u, 2), velocity(u, 3)
    m1, m2, m3 = system.masses
    G = system.G

    d12, d13, d23 = r2-r1, r3-r1, r3-r2
    q12, q13, q23 = G*_inverse_cube(d12), G*_inverse_cube(d13), G*_inverse_cube(d23)

    a1 = m2*q12*d12 + m3*q13*d13
    a2 = -m1*q12*d12 + m3*q23*d23
    a3 = -m1*q13*d13 - m2*q23*d23

    @inbounds begin
        du[1:3] .= v1;   du[4:6] .= a1
        du[7:9] .= v2;   du[10:12] .= a2
        du[13:15] .= v3; du[16:18] .= a3
    end
    nothing
end
