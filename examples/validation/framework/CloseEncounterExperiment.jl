# Shared scientific operations for Investigation 2 close-encounter experiments.

import ThreeBody3D
using LinearAlgebra: dot, norm

const CLOSE_ENCOUNTER_REFERENCE_PRECISION = 256
const CLOSE_ENCOUNTER_SAMPLE_STEP = 0.002
const CLOSE_ENCOUNTER_SELECTED_PAIR = (1, 2)
const CLOSE_ENCOUNTER_ENTRY_THRESHOLD = 0.1
const CLOSE_ENCOUNTER_EXIT_THRESHOLD = 0.25
const CLOSE_ENCOUNTER_REFERENCE_TOLERANCE = "1e-30"
const CLOSE_ENCOUNTER_INTERVAL = (0.0, 1.6)

function _close_reference_time(time::Float64, precision_bits::Int)
    setprecision(BigFloat, precision_bits) do
        BigFloat(time)
    end
end

@inline _close_decimal(::Type{Float64}, value::AbstractString) = parse(Float64, value)
@inline _close_decimal(::Type{BigFloat}, value::AbstractString) = parse(BigFloat, value)

function close_encounter_problem(::Type{T}) where {T<:AbstractFloat}
    m1 = _close_decimal(T, "1")
    m2 = _close_decimal(T, "1")
    m3 = _close_decimal(T, "0.001")
    gravitational_constant = _close_decimal(T, "1")
    apoapsis = _close_decimal(T, "1")
    nominal_periapsis = _close_decimal(T, "0.0001")
    semimajor_axis = (apoapsis + nominal_periapsis) / T(2)
    binary_mu = gravitational_constant * (m1 + m2)
    relative_speed = sqrt(
        binary_mu * (T(2) / apoapsis - one(T) / semimajor_axis),
    )
    third_body_offset = _close_decimal(T, "10")
    total_mass = m1 + m2 + m3
    binary_com_x = -(m3 / total_mass) * third_body_offset
    third_x = binary_com_x + third_body_offset
    zero_value = zero(T)

    r1 = T[binary_com_x + apoapsis / T(2), zero_value, zero_value]
    r2 = T[binary_com_x - apoapsis / T(2), zero_value, zero_value]
    r3 = T[third_x, zero_value, zero_value]
    v1 = T[zero_value, relative_speed / T(2), zero_value]
    v2 = T[zero_value, -relative_speed / T(2), zero_value]
    v3 = T[zero_value, zero_value, zero_value]

    system = ThreeBody3D.ThreeBodySystem((m1, m2, m3); G=gravitational_constant)
    (
        system=system,
        u0=ThreeBody3D.statevector(r1, v1, r2, v2, r3, v3),
        tspan=(zero_value, _close_decimal(T, "1.6")),
        nominal_periapsis=nominal_periapsis,
        physical_parameters=(
            masses=Tuple(system.masses),
            gravitational_constant=system.G,
            apoapsis=apoapsis,
            third_body_offset=third_body_offset,
        ),
    )
end

function _validate_close_encounter_problem(problem, ::Type{T}) where {T<:AbstractFloat}
    expected = close_encounter_problem(T)
    problem.system.masses == expected.system.masses ||
        throw(ArgumentError("Close-encounter masses are not canonical."))
    problem.system.G == expected.system.G ||
        throw(ArgumentError("Close-encounter gravitational constant is not canonical."))
    problem.u0 == expected.u0 ||
        throw(ArgumentError("Close-encounter initial state is not canonical."))
    problem.tspan == expected.tspan ||
        throw(ArgumentError("Close-encounter interval is not canonical."))
    problem.nominal_periapsis == expected.nominal_periapsis ||
        throw(ArgumentError("Close-encounter nominal periapsis is not canonical."))
    problem.physical_parameters == expected.physical_parameters ||
        throw(ArgumentError("Close-encounter physical parameters are not canonical."))
    problem
end

function close_encounter_sample_times(tspan; step=CLOSE_ENCOUNTER_SAMPLE_STEP)
    times = collect(range(first(tspan); step=step, stop=last(tspan)))
    times[end] == last(tspan) || push!(times, last(tspan))
    times
end

function _validate_close_encounter_sample_grid(times)
    expected = close_encounter_sample_times(CLOSE_ENCOUNTER_INTERVAL)
    times == expected || throw(ArgumentError("Physical-time sample grid is not approved."))
    times
end

@inline function _close_body_state_ranges(body)
    (6body - 5):(6body - 3), (6body - 2):(6body)
end

function close_encounter_pair_components(state, pair=CLOSE_ENCOUNTER_SELECTED_PAIR)
    i, j = pair
    ri, vi = _close_body_state_ranges(i)
    rj, vj = _close_body_state_ranges(j)
    (position=state[ri] .- state[rj], velocity=state[vi] .- state[vj])
end

"""Established standalone error convention: compare after conversion to Float64."""
function close_encounter_state_errors(
    state,
    reference_state;
    pair=CLOSE_ENCOUNTER_SELECTED_PAIR,
)
    actual = close_encounter_pair_components(state, pair)
    reference = close_encounter_pair_components(reference_state, pair)
    actual_state = Float64.(state)
    reference_full_state = Float64.(reference_state)
    (
        position=norm(Float64.(actual.position) .- Float64.(reference.position)),
        velocity=norm(Float64.(actual.velocity) .- Float64.(reference.velocity)),
        full_state=maximum(abs, actual_state .- reference_full_state),
    )
end

function close_encounter_trajectory_errors(states, reference_states)
    length(states) == length(reference_states) ||
        throw(ArgumentError("Trajectory and reference sample counts differ."))
    isempty(states) && throw(ArgumentError("Trajectory errors require samples."))
    values = map(close_encounter_state_errors, states, reference_states)
    (
        maximum_position=maximum(value.position for value in values),
        maximum_velocity=maximum(value.velocity for value in values),
        maximum_full_state=maximum(value.full_state for value in values),
        maximum_combined=maximum(hypot(value.position, value.velocity) for value in values),
        final_position=last(values).position,
        final_velocity=last(values).velocity,
        final_full_state=last(values).full_state,
        final_combined=hypot(last(values).position, last(values).velocity),
    )
end

@inline function close_encounter_radial_numerator(state, pair=CLOSE_ENCOUNTER_SELECTED_PAIR)
    relative = close_encounter_pair_components(state, pair)
    dot(relative.position, relative.velocity)
end

@inline function _close_encounter_pair_separation(state, pair=CLOSE_ENCOUNTER_SELECTED_PAIR)
    norm(close_encounter_pair_components(state, pair).position)
end

function _close_bisect(left, right, value_at_time; iterations=200)
    a = left
    b = right
    fa = value_at_time(a)
    fb = value_at_time(b)
    all(isfinite, (fa, fb)) || throw(ArgumentError("Boundary bracket is nonfinite."))
    iszero(fa) && return a
    iszero(fb) && return b
    signbit(fa) != signbit(fb) || throw(ArgumentError("Boundary bracket does not change sign."))
    for _ in 1:iterations
        midpoint = a + (b - a) / 2
        (midpoint == a || midpoint == b) && break
        fm = value_at_time(midpoint)
        isfinite(fm) || throw(ArgumentError("Boundary search produced a nonfinite value."))
        if iszero(fm)
            return midpoint
        elseif signbit(fm) == signbit(fa)
            a = midpoint
            fa = fm
        else
            b = midpoint
        end
    end
    a + (b - a) / 2
end

function close_encounter_periapsis(
    state_at_time,
    left,
    right;
    pair=CLOSE_ENCOUNTER_SELECTED_PAIR,
    iterations=200,
)
    radial_at_time = time -> close_encounter_radial_numerator(state_at_time(time), pair)
    left_value = radial_at_time(left)
    right_value = radial_at_time(right)
    left_value < 0 ||
        throw(ArgumentError("Periapsis bracket must start on the inbound branch."))
    right_value >= 0 ||
        throw(ArgumentError("Periapsis bracket must end on the outbound branch."))
    if iszero(right_value)
        midpoint = left + (right - left) / 2
        radial_at_time(midpoint) < 0 ||
            throw(ArgumentError("Endpoint root is not an inbound-to-outbound minimum."))
    end
    time = _close_bisect(left, right, radial_at_time; iterations=iterations)
    state = state_at_time(time)
    (
        time=time,
        separation=_close_encounter_pair_separation(state, pair),
        radial_numerator=radial_at_time(time),
        state=state,
    )
end

struct CloseEncounterReferenceBoundaries
    entry_time::BigFloat
    entry_separation::BigFloat
    entry_residual::BigFloat
    periapsis_time::BigFloat
    periapsis_separation::BigFloat
    periapsis_residual::BigFloat
    exit_time::BigFloat
    exit_separation::BigFloat
    exit_residual::BigFloat
    arithmetic::Symbol
    precision_bits::Int

    function CloseEncounterReferenceBoundaries(
        entry_time::BigFloat,
        entry_separation::BigFloat,
        entry_residual::BigFloat,
        periapsis_time::BigFloat,
        periapsis_separation::BigFloat,
        periapsis_residual::BigFloat,
        exit_time::BigFloat,
        exit_separation::BigFloat,
        exit_residual::BigFloat,
        arithmetic=:BigFloat,
        precision_bits=CLOSE_ENCOUNTER_REFERENCE_PRECISION,
    )
        values = (
            entry_time, entry_separation, entry_residual,
            periapsis_time, periapsis_separation, periapsis_residual,
            exit_time, exit_separation, exit_residual,
        )
        all(isfinite, values) || throw(ArgumentError("Reference boundaries must be finite."))
        all(value -> precision(value) == CLOSE_ENCOUNTER_REFERENCE_PRECISION, values) ||
            throw(ArgumentError("Reference boundary values must retain 256-bit precision."))
        arithmetic == :BigFloat || throw(ArgumentError("Reference arithmetic must be BigFloat."))
        precision_bits == CLOSE_ENCOUNTER_REFERENCE_PRECISION ||
            throw(ArgumentError("Reference precision must be 256 bits."))
        entry_separation >= 0 && periapsis_separation >= 0 && exit_separation >= 0 ||
            throw(ArgumentError("Reference separations must be nonnegative."))
        setprecision(BigFloat, CLOSE_ENCOUNTER_REFERENCE_PRECISION) do
            zero_time = parse(BigFloat, "0")
            final_time = parse(BigFloat, "1.6")
            entry_threshold = parse(BigFloat, "0.1")
            exit_threshold = parse(BigFloat, "0.25")
            zero_time < entry_time < periapsis_time < exit_time < final_time ||
                throw(ArgumentError("Reference boundaries are outside the approved interval or unordered."))
            entry_separation - entry_threshold == entry_residual ||
                throw(ArgumentError("Entry crossing residual is inconsistent."))
            exit_separation - exit_threshold == exit_residual ||
                throw(ArgumentError("Exit crossing residual is inconsistent."))
            construction_bound = sqrt(eps(BigFloat))
            all(residual -> abs(residual) <= construction_bound,
                (entry_residual, periapsis_residual, exit_residual)) ||
                throw(ArgumentError("Reference boundary residual exceeds the construction bound."))
        end
        new(
            entry_time, entry_separation, entry_residual,
            periapsis_time, periapsis_separation, periapsis_residual,
            exit_time, exit_separation, exit_residual,
            arithmetic, Int(precision_bits),
        )
    end
end

function _validate_close_reference_nodes(nodes, tspan, precision_bits)
    isempty(nodes) && throw(ArgumentError("Reference boundary search requires nodes."))
    all(node -> node isa BigFloat, nodes) ||
        throw(ArgumentError("Reference search nodes must use BigFloat."))
    all(isfinite, nodes) || throw(ArgumentError("Reference search nodes must be finite."))
    all(node -> precision(node) == precision_bits, nodes) ||
        throw(ArgumentError("Reference search nodes have the wrong precision."))
    all(index -> nodes[index] < nodes[index + 1], 1:length(nodes)-1) ||
        throw(ArgumentError("Reference search nodes must be strictly ordered."))
    first(nodes) == first(tspan) && last(nodes) == last(tspan) ||
        throw(ArgumentError("Reference search nodes must cover the complete interval."))
    nothing
end

function close_encounter_reference_boundaries(
    state_at_time,
    nodes,
    tspan;
    pair=CLOSE_ENCOUNTER_SELECTED_PAIR,
    precision_bits=CLOSE_ENCOUNTER_REFERENCE_PRECISION,
)
    precision_bits == CLOSE_ENCOUNTER_REFERENCE_PRECISION ||
        throw(ArgumentError("Reference precision must be 256 bits."))
    _validate_close_reference_nodes(nodes, tspan, precision_bits)
    setprecision(BigFloat, precision_bits) do
        approved_tspan = (parse(BigFloat, "0"), parse(BigFloat, "1.6"))
        tspan == approved_tspan || throw(ArgumentError("Reference interval is not approved."))
        entry_threshold = parse(BigFloat, "0.1")
        exit_threshold = parse(BigFloat, "0.25")
        separation = time -> _close_encounter_pair_separation(state_at_time(time), pair)
        radial = time -> close_encounter_radial_numerator(state_at_time(time), pair)

        function find_bracket(predicate, start_index=1)
            for index in start_index:length(nodes)-1
                left = nodes[index]
                right = nodes[index + 1]
                predicate(left, right) && return (left, right, index)
            end
            throw(ArgumentError("Reference nodes do not bracket an encounter boundary."))
        end

        entry_left, entry_right, entry_index = find_bracket(
            (left, right) -> separation(left) >= entry_threshold &&
                separation(right) <= entry_threshold,
        )
        entry_time = _close_bisect(
            entry_left, entry_right, time -> separation(time) - entry_threshold,
        )
        radial(entry_left) < 0 && radial(entry_right) < 0 ||
            throw(ArgumentError("Entry crossing is not on the inbound branch."))

        periapsis_left, periapsis_right, periapsis_index = find_bracket(
            (left, right) -> radial(left) <= 0 && radial(right) >= 0,
            entry_index,
        )
        periapsis = close_encounter_periapsis(
            state_at_time, periapsis_left, periapsis_right; pair=pair,
        )

        exit_left, exit_right, _ = find_bracket(
            (left, right) -> separation(left) <= exit_threshold &&
                separation(right) >= exit_threshold,
            periapsis_index,
        )
        exit_time = _close_bisect(
            exit_left, exit_right, time -> separation(time) - exit_threshold,
        )
        radial(exit_left) > 0 && radial(exit_right) > 0 ||
            throw(ArgumentError("Exit crossing is not on the outbound branch."))

        entry_separation = separation(entry_time)
        exit_separation = separation(exit_time)
        CloseEncounterReferenceBoundaries(
            entry_time,
            entry_separation,
            entry_separation - entry_threshold,
            periapsis.time,
            periapsis.separation,
            periapsis.radial_numerator,
            exit_time,
            exit_separation,
            exit_separation - exit_threshold,
            :BigFloat,
            precision_bits,
        )
    end
end

struct CloseEncounterReferenceExecution{P,S}
    problem::P
    solution::S
    sample_times::Vector{Float64}
    sampled_states::Vector{Vector{BigFloat}}
    boundaries::CloseEncounterReferenceBoundaries
    precision_bits::Int
    relative_tolerance::BigFloat
    absolute_tolerance::BigFloat
    solver_selector::Symbol
    dense::Bool
    save_everystep::Bool

    function CloseEncounterReferenceExecution(
        problem,
        solution,
        sample_times,
        sampled_states,
        boundaries::CloseEncounterReferenceBoundaries,
        precision_bits,
        relative_tolerance::BigFloat,
        absolute_tolerance::BigFloat,
        solver_selector,
        dense,
        save_everystep,
    )
        _validate_close_encounter_problem(problem, BigFloat)
        precision_bits == CLOSE_ENCOUNTER_REFERENCE_PRECISION ||
            throw(ArgumentError("Reference execution precision is not approved."))
        all(value -> precision(value) == precision_bits,
            (relative_tolerance, absolute_tolerance)) ||
            throw(ArgumentError("Reference tolerances have the wrong precision."))
        setprecision(BigFloat, precision_bits) do
            expected_tolerance = parse(BigFloat, CLOSE_ENCOUNTER_REFERENCE_TOLERANCE)
            relative_tolerance == expected_tolerance && absolute_tolerance == expected_tolerance ||
                throw(ArgumentError("Reference tolerances are not approved."))
        end
        solver_selector == :extreme || throw(ArgumentError("Reference solver must be :extreme."))
        dense === true || throw(ArgumentError("Reference dense output must be enabled."))
        save_everystep === true ||
            throw(ArgumentError("Reference accepted-node retention must be enabled."))
        normalized_times = Float64.(sample_times)
        _validate_close_encounter_sample_grid(normalized_times)
        normalized_states = Vector{BigFloat}[Vector{BigFloat}(state) for state in sampled_states]
        length(normalized_states) == length(normalized_times) ||
            throw(ArgumentError("Reference sample counts differ."))
        all(state -> length(state) == 18, normalized_states) ||
            throw(ArgumentError("Reference sampled states must contain 18 components."))
        all(state -> all(isfinite, state), normalized_states) ||
            throw(ArgumentError("Reference sampled states must be finite."))
        all(state -> all(value -> precision(value) == precision_bits, state), normalized_states) ||
            throw(ArgumentError("Reference sampled states have the wrong precision."))
        new{typeof(problem),typeof(solution)}(
            problem, solution, normalized_times, normalized_states, boundaries,
            Int(precision_bits), relative_tolerance, absolute_tolerance,
            solver_selector, dense, save_everystep,
        )
    end
end

function close_encounter_reference_state(reference::CloseEncounterReferenceExecution, time)
    setprecision(BigFloat, reference.precision_bits) do
        evaluation_time = time isa AbstractString ? parse(BigFloat, time) : BigFloat(time)
        Vector{BigFloat}(reference.solution(evaluation_time))
    end
end

close_encounter_reference_time(reference::CloseEncounterReferenceExecution, time::Float64) =
    _close_reference_time(time, reference.precision_bits)

function build_close_encounter_reference(; runner=ThreeBody3D.simulate)
    setprecision(BigFloat, CLOSE_ENCOUNTER_REFERENCE_PRECISION) do
        problem = close_encounter_problem(BigFloat)
        tolerance = parse(BigFloat, CLOSE_ENCOUNTER_REFERENCE_TOLERANCE)
        result = runner(
            problem.system,
            problem.u0,
            problem.tspan;
            solver=:extreme,
            precision=CLOSE_ENCOUNTER_REFERENCE_PRECISION,
            reltol=tolerance,
            abstol=tolerance,
            dense=true,
            save_everystep=true,
        )
        sample_times = close_encounter_sample_times(CLOSE_ENCOUNTER_INTERVAL)
        sampled_states = [Vector{BigFloat}(result.solution(
            _close_reference_time(time, CLOSE_ENCOUNTER_REFERENCE_PRECISION),
        )) for time in sample_times]
        search_nodes = collect(range(
            first(problem.tspan);
            step=parse(BigFloat, "0.002"),
            stop=last(problem.tspan),
        ))
        last(search_nodes) == last(problem.tspan) || push!(search_nodes, last(problem.tspan))
        boundaries = close_encounter_reference_boundaries(
            time -> result.solution(time), search_nodes, problem.tspan,
        )
        CloseEncounterReferenceExecution(
            problem, result.solution, sample_times, sampled_states, boundaries,
            CLOSE_ENCOUNTER_REFERENCE_PRECISION, tolerance, tolerance,
            :extreme, true, true,
        )
    end
end

function close_encounter_augmented_times(reference::CloseEncounterReferenceExecution)
    setprecision(BigFloat, reference.precision_bits) do
        values = BigFloat[close_encounter_reference_time(reference, time)
            for time in reference.sample_times]
        append!(values, BigFloat[
            BigFloat(reference.boundaries.entry_time),
            BigFloat(reference.boundaries.periapsis_time),
            BigFloat(reference.boundaries.exit_time),
            close_encounter_reference_time(reference, last(reference.sample_times)),
        ])
        sort!(unique!(values))
    end
end

function close_encounter_conservation(system, times, states)
    length(times) == length(states) || throw(ArgumentError("Conservation sample counts differ."))
    isempty(states) && throw(ArgumentError("Conservation measurement requires samples."))
    initial_state = first(states)
    initial_time = first(times)
    initial_energy = ThreeBody3D.total_energy(system, initial_state)
    initial_momentum = ThreeBody3D.linear_momentum(system, initial_state)
    initial_angular_momentum = ThreeBody3D.angular_momentum(system, initial_state)
    initial_com = ThreeBody3D.center_of_mass(system, initial_state)
    initial_com_velocity = ThreeBody3D.center_of_mass_velocity(system, initial_state)
    maximum_relative_energy_drift = zero(initial_energy)
    maximum_momentum_drift = zero(initial_energy)
    maximum_angular_momentum_drift = zero(initial_energy)
    maximum_com_residual = zero(initial_energy)
    minimum_pair_separation = oftype(initial_energy, Inf)
    for (time, state) in zip(times, states)
        energy = ThreeBody3D.total_energy(system, state)
        relative_energy_drift = iszero(initial_energy) ?
            abs(energy - initial_energy) : abs((energy - initial_energy) / initial_energy)
        expected_com = initial_com + (time - initial_time) * initial_com_velocity
        maximum_relative_energy_drift = max(maximum_relative_energy_drift, relative_energy_drift)
        maximum_momentum_drift = max(maximum_momentum_drift,
            norm(ThreeBody3D.linear_momentum(system, state) - initial_momentum))
        maximum_angular_momentum_drift = max(maximum_angular_momentum_drift,
            norm(ThreeBody3D.angular_momentum(system, state) - initial_angular_momentum))
        maximum_com_residual = max(maximum_com_residual,
            norm(ThreeBody3D.center_of_mass(system, state) - expected_com))
        minimum_pair_separation = min(minimum_pair_separation,
            ThreeBody3D.minimum_separation(state))
    end
    (
        maximum_relative_energy_drift=maximum_relative_energy_drift,
        maximum_momentum_drift=maximum_momentum_drift,
        maximum_angular_momentum_drift=maximum_angular_momentum_drift,
        maximum_com_residual=maximum_com_residual,
        minimum_separation=minimum_pair_separation,
    )
end

@inline function close_encounter_solution_work(solution)
    statistics = solution.stats
    (
        saved_states=length(solution.t),
        accepted_steps=Int(statistics.naccept),
        rejected_steps=Int(statistics.nreject),
        rhs_evaluations=Int(statistics.nf),
    )
end

function close_encounter_sum_work(items)
    (
        saved_states=sum(item.saved_states for item in items),
        accepted_steps=sum(item.accepted_steps for item in items),
        rejected_steps=sum(item.rejected_steps for item in items),
        rhs_evaluations=sum(item.rhs_evaluations for item in items),
    )
end
