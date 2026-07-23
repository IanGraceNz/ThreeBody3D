"""
    RegularizationTransitionDiagnostics

Diagnostics for one Cartesian/regularized coordinate handoff.

All reported jumps compare two representations of the *same physical state*.
They therefore measure coordinate-conversion consistency, not integration
error across a segment.
"""
struct RegularizationTransitionDiagnostics{T<:AbstractFloat}
    physical_time::T
    pair::Tuple{Int,Int}
    state_residual::T
    position_residual::T
    velocity_residual::T
    energy_jump::T
    momentum_jump::T
    angular_momentum_jump::T
    center_of_mass_jump::T
    center_of_mass_velocity_jump::T
end

function Base.show(io::IO, diagnostics::RegularizationTransitionDiagnostics)
    println(io, "Regularization transition at t=$(diagnostics.physical_time)")
    println(io, "  pair:                         $(diagnostics.pair)")
    println(io, "  state residual:               $(diagnostics.state_residual)")
    println(io, "  position residual:            $(diagnostics.position_residual)")
    println(io, "  velocity residual:            $(diagnostics.velocity_residual)")
    println(io, "  total-energy jump:             $(diagnostics.energy_jump)")
    println(io, "  linear-momentum jump:          $(diagnostics.momentum_jump)")
    println(io, "  angular-momentum jump:         $(diagnostics.angular_momentum_jump)")
    println(io, "  center-of-mass jump:           $(diagnostics.center_of_mass_jump)")
    print(io,   "  center-of-mass velocity jump:  $(diagnostics.center_of_mass_velocity_jump)")
end

@inline function _max_body_residual(reference, reconstructed, accessor)
    maximum(norm(accessor(reference, i) - accessor(reconstructed, i)) for i in 1:3)
end

function _transition_diagnostics(
    system::ThreeBodySystem,
    reference::AbstractVector{T},
    reconstructed::AbstractVector{T},
    physical_time::T,
    pair::Tuple{Int,Int},
) where {T<:AbstractFloat}
    validate_state(reference)
    validate_state(reconstructed)
    RegularizationTransitionDiagnostics{T}(
        physical_time,
        pair,
        maximum(abs, reconstructed .- reference),
        _max_body_residual(reference, reconstructed, body_position),
        _max_body_residual(reference, reconstructed, velocity),
        abs(total_energy(system, reconstructed) - total_energy(system, reference)),
        norm(linear_momentum(system, reconstructed) - linear_momentum(system, reference)),
        norm(angular_momentum(system, reconstructed) - angular_momentum(system, reference)),
        norm(center_of_mass(system, reconstructed) - center_of_mass(system, reference)),
        norm(center_of_mass_velocity(system, reconstructed) - center_of_mass_velocity(system, reference)),
    )
end

"""
    ExplicitRegularizedSegment

One explicitly requested planar Levi-Civita segment between two physical times.

The object retains the Cartesian entry and exit states, the underlying
[`PerturbedLeviCivitaProblem`](@ref) and numerical result, and diagnostics for
both coordinate handoffs. No automatic pair selection or threshold switching
is performed.
"""
struct ExplicitRegularizedSegment{T<:AbstractFloat,S,P,R}
    system::S
    pair::Tuple{Int,Int}
    entry_time::T
    exit_time::T
    entry_state::Vector{T}
    exit_state::Vector{T}
    exit_fictitious_time::T
    regularized_problem::P
    regularized_result::R
    entry_diagnostics::RegularizationTransitionDiagnostics{T}
    exit_diagnostics::RegularizationTransitionDiagnostics{T}
end

"""
    propagate_regularized_segment(system, state, pair, entry_time, exit_time; kwargs...)

Perform one explicit Cartesian → planar Levi-Civita → Cartesian handoff.

`state` is the ordinary 18-element Cartesian state at `entry_time`. The
selected pair is regularized explicitly and propagated to `exit_time` using
callback-free bracket expansion and bisection of the integrated Sundman time.
The returned [`ExplicitRegularizedSegment`](@ref) records conversion residuals
and invariant jumps at both boundaries.

This experimental function requires planar data and `exit_time != entry_time`.
It does not inspect close-approach thresholds and does not modify the production
[`simulate`](@ref) path. Solver and targeting keywords are forwarded to
[`perturbed_levi_civita_fictitious_time`](@ref).
"""
function propagate_regularized_segment(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer},
    entry_time::Real,
    exit_time::Real;
    branch::Integer=1,
    kwargs...,
)
    validate_state(state)
    i, j, _ = _validate_pair(pair)
    T = float(promote_type(eltype(system.masses), eltype(state), typeof(entry_time), typeof(exit_time)))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    entry = Vector{T}(state)
    t_entry = T(entry_time)
    t_exit = T(exit_time)
    all(isfinite, (t_entry, t_exit)) ||
        throw(ArgumentError("entry_time and exit_time must be finite."))
    t_exit != t_entry || throw(ArgumentError("exit_time must differ from entry_time."))

    problem = PerturbedLeviCivitaProblem(
        converted_system, entry, (i, j); branch=branch, initial_time=t_entry,
    )

    initial_regularized = perturbed_levi_civita_state_at_time(problem, t_entry)
    entry_reconstructed = Vector{T}(initial_regularized.physical_state)
    entry_diagnostics = _transition_diagnostics(
        converted_system, entry, entry_reconstructed, t_entry, (i, j),
    )

    exit_s, targeted_result = perturbed_levi_civita_fictitious_time(
        problem, t_exit; kwargs...,
    )
    isnothing(targeted_result) && throw(
        ErrorException(
            "Internal error: a nonzero regularized segment returned no integration result.",
        ),
    )
    regularized_result = targeted_result
    exit_regularized = perturbed_levi_civita_state(regularized_result, exit_s)
    exit_state = Vector{T}(exit_regularized.physical_state)

    # Apply the ordinary pair-coordinate round trip at the exit boundary. This
    # represents the regularized → Cartesian handoff and gives a state with
    # which conversion and invariant jumps can be measured independently of
    # the integration error accumulated inside the segment.
    exit_pair_coordinates = to_pair_coordinates(converted_system, exit_state, (i, j))
    exit_reconstructed = Vector{T}(
        from_pair_coordinates(converted_system, exit_pair_coordinates),
    )
    exit_diagnostics = _transition_diagnostics(
        converted_system, exit_state, exit_reconstructed, T(exit_regularized.physical_time), (i, j),
    )

    ExplicitRegularizedSegment{T,typeof(converted_system),typeof(problem),typeof(regularized_result)}(
        converted_system,
        (i, j),
        t_entry,
        t_exit,
        entry,
        exit_state,
        T(exit_s),
        problem,
        regularized_result,
        entry_diagnostics,
        exit_diagnostics,
    )
end
