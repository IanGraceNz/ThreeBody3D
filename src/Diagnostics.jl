"""Return the system center of mass for state `u`."""
function center_of_mass(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    (sum(system.masses[i] * body_position(u, i) for i in 1:3)) / total_mass(system)
end

"""Return the center-of-mass velocity for state `u`."""
function center_of_mass_velocity(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    (sum(system.masses[i] * velocity(u, i) for i in 1:3)) / total_mass(system)
end

"""Return total linear momentum for state `u`."""
function linear_momentum(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    sum(system.masses[i] * velocity(u, i) for i in 1:3; init=zero(SVector{3,T}))
end

"""Return total angular momentum about the coordinate origin for state `u`."""
function angular_momentum(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    sum(system.masses[i] * cross(body_position(u, i), velocity(u, i)) for i in 1:3;
        init=zero(SVector{3,T}))
end

"""Return total kinetic energy for state `u`."""
function kinetic_energy(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    sum(T(0.5) * system.masses[i] * dot(velocity(u, i), velocity(u, i)) for i in 1:3)
end

"""Return Newtonian gravitational potential energy for state `u`."""
function potential_energy(system::ThreeBodySystem, u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    energy = zero(promote_type(T, typeof(system.G)))
    for i in 1:2, j in (i+1):3
        r = norm(body_position(u, j) - body_position(u, i))
        iszero(r) && throw(DomainError(r, "Potential energy is singular at collision."))
        energy -= system.G * system.masses[i] * system.masses[j] / r
    end
    energy
end

"""Return total mechanical energy for state `u`."""
total_energy(system::ThreeBodySystem, u::AbstractVector) =
    kinetic_energy(system, u) + potential_energy(system, u)

"""Return the smallest pairwise separation in state `u`."""
function minimum_separation(u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)
    min(norm(body_position(u,2)-body_position(u,1)),
        norm(body_position(u,3)-body_position(u,1)),
        norm(body_position(u,3)-body_position(u,2)))
end

@inline _relative_error(value, reference) =
    iszero(reference) ? abs(value-reference) : abs((value-reference)/reference)

"""
    relative_energy_error(result)

Maximum relative energy drift over all saved states in `result`. When initial
energy is zero, returns the maximum absolute energy drift instead.
"""
function relative_energy_error(result::SimulationResult)
    E0 = total_energy(result.system, first(result.solution.u))
    maximum(_relative_error(total_energy(result.system, u), E0) for u in result.solution.u)
end

"""
    DiagnosticsReport

Conservation and close-approach summary over all saved simulation states.
Fields with `maximum_*_drift` report the largest drift from the initial value,
not merely the endpoint error.
"""
struct DiagnosticsReport{T,V}
    initial_energy::T
    final_energy::T
    maximum_relative_energy_drift::T
    maximum_linear_momentum_drift::T
    maximum_angular_momentum_drift::T
    maximum_center_of_mass_residual::T
    minimum_separation::T
    initial_linear_momentum::V
    final_linear_momentum::V
    initial_angular_momentum::V
    final_angular_momentum::V
end

"""
    diagnostics_report(result)

Compute conservation diagnostics over every state saved in `result`.
Center-of-mass residual is measured against inertial motion predicted from the
initial center of mass and center-of-mass velocity.
"""
function diagnostics_report(result::SimulationResult)
    system, sol = result.system, result.solution
    u0, uf = first(sol.u), last(sol.u)
    t0 = first(sol.t)
    E0 = total_energy(system, u0)
    P0 = linear_momentum(system, u0)
    L0 = angular_momentum(system, u0)
    R0 = center_of_mass(system, u0)
    V0 = center_of_mass_velocity(system, u0)

    max_e = zero(E0)
    max_p = zero(E0)
    max_l = zero(E0)
    max_r = zero(E0)
    min_r = oftype(E0, Inf)

    for (t, u) in zip(sol.t, sol.u)
        max_e = max(max_e, _relative_error(total_energy(system, u), E0))
        max_p = max(max_p, norm(linear_momentum(system, u) - P0))
        max_l = max(max_l, norm(angular_momentum(system, u) - L0))
        expected_com = R0 + (t-t0)*V0
        max_r = max(max_r, norm(center_of_mass(system, u) - expected_com))
        min_r = min(min_r, minimum_separation(u))
    end

    DiagnosticsReport(E0, total_energy(system, uf), max_e, max_p, max_l, max_r,
                      min_r, P0, linear_momentum(system, uf), L0,
                      angular_momentum(system, uf))
end

function Base.show(io::IO, report::DiagnosticsReport)
    println(io, "ThreeBody3D diagnostics")
    println(io, "  initial energy:                 ", report.initial_energy)
    println(io, "  final energy:                   ", report.final_energy)
    println(io, "  maximum relative energy drift: ", report.maximum_relative_energy_drift)
    println(io, "  maximum momentum drift:        ", report.maximum_linear_momentum_drift)
    println(io, "  maximum angular momentum drift:", report.maximum_angular_momentum_drift)
    println(io, "  maximum COM residual:          ", report.maximum_center_of_mass_residual)
    print(io,   "  minimum pair separation:       ", report.minimum_separation)
end
