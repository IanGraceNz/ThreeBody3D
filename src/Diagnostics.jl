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

"""
    ExperimentalSwitchingDiagnosticsReport

Conservation, close-approach, and handoff summary for a physically sampled
[`ExperimentalSwitchingTrajectory`](@ref).

The conservation maxima are measured over the supplied physical-time samples.
Transition maxima are measured over every retained entry and exit event. A
failed trajectory may still be diagnosed over its successfully computed
interval.
"""
struct ExperimentalSwitchingDiagnosticsReport{T,V}
    initial_energy::T
    final_energy::T
    maximum_relative_energy_drift::T
    maximum_linear_momentum_drift::T
    maximum_angular_momentum_drift::T
    maximum_center_of_mass_residual::T
    maximum_center_of_mass_velocity_drift::T
    minimum_separation::T
    initial_linear_momentum::V
    final_linear_momentum::V
    initial_angular_momentum::V
    final_angular_momentum::V
    sample_count::Int
    segment_count::Int
    switch_count::Int
    maximum_transition_state_residual::T
    maximum_transition_energy_jump::T
    maximum_transition_momentum_jump::T
    maximum_transition_angular_momentum_jump::T
    maximum_transition_center_of_mass_jump::T
    maximum_transition_center_of_mass_velocity_jump::T
end

function _experimental_switching_diagnostics_report(
    trajectory::ExperimentalSwitchingTrajectory,
    samples::ExperimentalSwitchingSamples,
)
    system = trajectory.system
    times, states = samples.times, samples.states
    u0, uf = first(states), last(states)
    t0 = first(times)
    E0 = total_energy(system, u0)
    P0 = linear_momentum(system, u0)
    L0 = angular_momentum(system, u0)
    R0 = center_of_mass(system, u0)
    V0 = center_of_mass_velocity(system, u0)

    max_e = zero(E0)
    max_p = zero(E0)
    max_l = zero(E0)
    max_r = zero(E0)
    max_v = zero(E0)
    min_r = oftype(E0, Inf)

    for (time, state) in zip(times, states)
        max_e = max(max_e, _relative_error(total_energy(system, state), E0))
        max_p = max(max_p, norm(linear_momentum(system, state) - P0))
        max_l = max(max_l, norm(angular_momentum(system, state) - L0))
        expected_com = R0 + (time - t0) * V0
        max_r = max(max_r, norm(center_of_mass(system, state) - expected_com))
        max_v = max(max_v, norm(center_of_mass_velocity(system, state) - V0))
        min_r = min(min_r, minimum_separation(state))
    end

    transition_max(field::Symbol) = isempty(trajectory.switch_events) ? zero(E0) :
        maximum(getproperty(event.transition_diagnostics, field) for event in trajectory.switch_events)

    ExperimentalSwitchingDiagnosticsReport(
        E0,
        total_energy(system, uf),
        max_e,
        max_p,
        max_l,
        max_r,
        max_v,
        min_r,
        P0,
        linear_momentum(system, uf),
        L0,
        angular_momentum(system, uf),
        length(samples),
        length(trajectory.segments),
        length(trajectory.switch_events),
        transition_max(:state_residual),
        transition_max(:energy_jump),
        transition_max(:momentum_jump),
        transition_max(:angular_momentum_jump),
        transition_max(:center_of_mass_jump),
        transition_max(:center_of_mass_velocity_jump),
    )
end

"""
    diagnostics_report(trajectory, samples)

Compute Stage 9 conservation and transition diagnostics for an experimental
automatic-switching trajectory using explicit unified physical-time `samples`.
The samples must cover exactly the computed trajectory interval.
"""
function diagnostics_report(
    trajectory::ExperimentalSwitchingTrajectory,
    samples::ExperimentalSwitchingSamples,
)
    T = eltype(trajectory.final_state)
    first(samples.times) == T(trajectory.tspan[1]) || throw(ArgumentError(
        "diagnostic samples must begin at the trajectory initial time.",
    ))
    last(samples.times) == T(trajectory.final_time) || throw(ArgumentError(
        "diagnostic samples must end at the trajectory final computed time.",
    ))
    _experimental_switching_diagnostics_report(trajectory, samples)
end

"""
    diagnostics_report(trajectory; dt, include_switches=true,
                       regularized_kwargs=NamedTuple(), maximum_samples=1_000_000)

Uniformly sample an experimental automatic-switching trajectory in physical
time and compute conservation and transition diagnostics. Switch epochs are
included by default so each coordinate handoff is represented exactly.
"""
function diagnostics_report(
    trajectory::ExperimentalSwitchingTrajectory;
    dt::Real,
    include_switches::Bool=true,
    regularized_kwargs::NamedTuple=NamedTuple(),
    maximum_samples::Integer=1_000_000,
)
    samples = sample_experimental_switching(
        trajectory;
        dt=dt,
        include_switches=include_switches,
        regularized_kwargs=regularized_kwargs,
        maximum_samples=maximum_samples,
    )
    diagnostics_report(trajectory, samples)
end

function Base.show(io::IO, report::ExperimentalSwitchingDiagnosticsReport)
    println(io, "ThreeBody3D experimental switching diagnostics")
    println(io, "  samples:                              ", report.sample_count)
    println(io, "  segments:                             ", report.segment_count)
    println(io, "  switches:                             ", report.switch_count)
    println(io, "  initial energy:                       ", report.initial_energy)
    println(io, "  final energy:                         ", report.final_energy)
    println(io, "  maximum relative energy drift:       ", report.maximum_relative_energy_drift)
    println(io, "  maximum momentum drift:              ", report.maximum_linear_momentum_drift)
    println(io, "  maximum angular momentum drift:      ", report.maximum_angular_momentum_drift)
    println(io, "  maximum COM residual:                ", report.maximum_center_of_mass_residual)
    println(io, "  maximum COM velocity drift:          ", report.maximum_center_of_mass_velocity_drift)
    println(io, "  minimum pair separation:             ", report.minimum_separation)
    println(io, "  maximum transition state residual:   ", report.maximum_transition_state_residual)
    println(io, "  maximum transition energy jump:      ", report.maximum_transition_energy_jump)
    println(io, "  maximum transition momentum jump:    ", report.maximum_transition_momentum_jump)
    println(io, "  maximum transition angular momentum: ", report.maximum_transition_angular_momentum_jump)
    println(io, "  maximum transition COM jump:         ", report.maximum_transition_center_of_mass_jump)
    print(io,   "  maximum transition COM velocity jump:", report.maximum_transition_center_of_mass_velocity_jump)
end
