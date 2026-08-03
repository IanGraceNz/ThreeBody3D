# I2-C2: matched automatic/explicit regularised-tolerance evidence.

const CLOSE_ENCOUNTER_REGULARIZED_DEFINITION_VERSION = "2.0.0"
const CLOSE_ENCOUNTER_DIFFERENCE_SAMPLE_ORDER = (:entry, :periapsis, :exit, :final)
const CLOSE_ENCOUNTER_COMPARISON_GRID_CONVENTION =
    "approved 0.002 physical grid within automatic interval plus exact entry, reference periapsis, and exit; sorted and deduplicated"

abstract type AbstractCloseEncounterRegularizedConfiguration end

struct CloseEncounterRegularizedToleranceConfiguration <: AbstractCloseEncounterRegularizedConfiguration
    regularized_relative_tolerance::Float64
    regularized_absolute_tolerance::Float64
    cartesian_relative_tolerance::Float64
    cartesian_absolute_tolerance::Float64
    entry_threshold::Float64
    ambiguity_threshold::Float64
    exit_threshold::Float64
    state_evaluation_tolerance::Float64
    regularized_initial_step::Float64
    regularized_maximum_iterations::Int
    state_evaluation_maximum_iterations::Int

    function CloseEncounterRegularizedToleranceConfiguration(tolerance::Real)
        controls = close_encounter_regularized_controls(tolerance)
        new((getfield(controls, name) for name in fieldnames(typeof(controls)))...)
    end
end
close_encounter_regularized_tolerance_configuration(tolerance) =
    CloseEncounterRegularizedToleranceConfiguration(tolerance)
_close_regularized_controls(c::CloseEncounterRegularizedToleranceConfiguration) =
    CloseEncounterRegularizedExecutionControls((getfield(c, n) for n in fieldnames(typeof(c)))...)
_close_regularized_configuration_is_approved(c::CloseEncounterRegularizedToleranceConfiguration) =
    c == CloseEncounterRegularizedToleranceConfiguration(c.regularized_relative_tolerance)

struct CloseEncounterTransitionEvidence
    physical_time::Float64
    pair::Tuple{Int,Int}
    state_residual::Float64
    position_residual::Float64
    velocity_residual::Float64
    energy_jump::Float64
    momentum_jump::Float64
    angular_momentum_jump::Float64
    center_of_mass_jump::Float64
    center_of_mass_velocity_jump::Float64

    function CloseEncounterTransitionEvidence(values)
        pair = Tuple(values.pair)
        pair == (1, 2) || throw(ArgumentError("Transition selected the wrong pair."))
        numbers = Float64[values.physical_time, values.state_residual, values.position_residual,
            values.velocity_residual, values.energy_jump, values.momentum_jump,
            values.angular_momentum_jump, values.center_of_mass_jump,
            values.center_of_mass_velocity_jump]
        all(isfinite, numbers) && all(>=(0), numbers[2:end]) ||
            throw(ArgumentError("Transition evidence is malformed."))
        new(numbers[1], pair, numbers[2:end]...)
    end
end

struct CloseEncounterAutomaticEventEvidence
    automatic_entry_time::Float64
    automatic_exit_time::Float64
    reference_entry_time::BigFloat
    reference_exit_time::BigFloat
    signed_entry_time_difference::BigFloat
    absolute_entry_time_error::BigFloat
    signed_exit_time_difference::BigFloat
    absolute_exit_time_error::BigFloat
    entry_separation::Float64
    entry_threshold_residual::Float64
    exit_separation::Float64
    exit_threshold_residual::Float64
    entry_radial_rate::Float64
    exit_radial_rate::Float64

    function CloseEncounterAutomaticEventEvidence(automatic_entry_time::Float64,
        automatic_exit_time::Float64, reference_entry_time::BigFloat,
        reference_exit_time::BigFloat, signed_entry_time_difference::BigFloat,
        absolute_entry_time_error::BigFloat, signed_exit_time_difference::BigFloat,
        absolute_exit_time_error::BigFloat, entry_separation::Float64,
        entry_threshold_residual::Float64, exit_separation::Float64,
        exit_threshold_residual::Float64, entry_radial_rate::Float64,
        exit_radial_rate::Float64; entry_threshold::Float64=0.1,
        exit_threshold::Float64=0.25)
        precision(reference_entry_time) == 256 && precision(reference_exit_time) == 256 ||
            throw(ArgumentError("Reference event times must retain 256-bit precision."))
        all(value -> precision(value) == 256, (signed_entry_time_difference,
            absolute_entry_time_error, signed_exit_time_difference,
            absolute_exit_time_error)) ||
            throw(ArgumentError("Event-time differences must retain 256-bit precision."))
        automatic_entry_time < automatic_exit_time || throw(ArgumentError("Automatic event times are unordered."))
        setprecision(BigFloat, 256) do
            signed_entry_time_difference == BigFloat(automatic_entry_time) - reference_entry_time || throw(ArgumentError("Entry-time difference is inconsistent."))
            signed_exit_time_difference == BigFloat(automatic_exit_time) - reference_exit_time || throw(ArgumentError("Exit-time difference is inconsistent."))
            absolute_entry_time_error == abs(signed_entry_time_difference) || throw(ArgumentError("Entry-time error is inconsistent."))
            absolute_exit_time_error == abs(signed_exit_time_difference) || throw(ArgumentError("Exit-time error is inconsistent."))
        end
        entry_threshold_residual == entry_separation - entry_threshold || throw(ArgumentError("Entry residual is inconsistent."))
        exit_threshold_residual == exit_separation - exit_threshold || throw(ArgumentError("Exit residual is inconsistent."))
        entry_radial_rate < 0 && exit_radial_rate > 0 || throw(ArgumentError("Event directions are invalid."))
        all(isfinite, (automatic_entry_time, automatic_exit_time, entry_separation,
            entry_threshold_residual, exit_separation, exit_threshold_residual,
            entry_radial_rate, exit_radial_rate)) || throw(ArgumentError("Automatic event evidence is nonfinite."))
        new(automatic_entry_time, automatic_exit_time, reference_entry_time,
            reference_exit_time, signed_entry_time_difference, absolute_entry_time_error,
            signed_exit_time_difference, absolute_exit_time_error, entry_separation,
            entry_threshold_residual, exit_separation, exit_threshold_residual,
            entry_radial_rate, exit_radial_rate)
    end

    function CloseEncounterAutomaticEventEvidence(entry, exit, boundaries)
        precision(boundaries.entry_time) == 256 && precision(boundaries.exit_time) == 256 ||
            throw(ArgumentError("Reference event times must retain 256-bit precision."))
        entry_time, exit_time = Float64(entry.physical_time), Float64(exit.physical_time)
        entry_time < exit_time || throw(ArgumentError("Automatic event times are unordered."))
        entry.pair == (1, 2) && exit.pair == (1, 2) || throw(ArgumentError("Automatic events selected the wrong pair."))
        entry_sep = Float64(entry.separations[1]); exit_sep = Float64(exit.separations[1])
        entry_rate = Float64(entry.radial_rates[1]); exit_rate = Float64(exit.radial_rates[1])
        entry_rate < 0 && exit_rate > 0 || throw(ArgumentError("Automatic event directions are invalid."))
        setprecision(BigFloat, 256) do
            entry_difference = BigFloat(entry_time) - boundaries.entry_time
            exit_difference = BigFloat(exit_time) - boundaries.exit_time
            new(entry_time, exit_time, BigFloat(boundaries.entry_time), BigFloat(boundaries.exit_time),
                entry_difference, abs(entry_difference), exit_difference, abs(exit_difference),
                entry_sep, entry_sep - 0.1, exit_sep, exit_sep - 0.25,
                entry_rate, exit_rate)
        end
    end
end

function CloseEncounterAutomaticEventEvidence(entry, exit, boundaries,
    configuration::AbstractCloseEncounterRegularizedConfiguration)
    precision(boundaries.entry_time) == 256 && precision(boundaries.exit_time) == 256 ||
        throw(ArgumentError("Reference event times must retain 256-bit precision."))
    entry_time, exit_time = Float64(entry.physical_time), Float64(exit.physical_time)
    entry_time < exit_time || throw(ArgumentError("Automatic event times are unordered."))
    entry.pair == (1, 2) && exit.pair == (1, 2) ||
        throw(ArgumentError("Automatic events selected the wrong pair."))
    entry_sep = Float64(entry.separations[1]); exit_sep = Float64(exit.separations[1])
    entry_rate = Float64(entry.radial_rates[1]); exit_rate = Float64(exit.radial_rates[1])
    entry_rate < 0 && exit_rate > 0 || throw(ArgumentError("Automatic event directions are invalid."))
    setprecision(BigFloat, 256) do
        entry_difference = BigFloat(entry_time) - boundaries.entry_time
        exit_difference = BigFloat(exit_time) - boundaries.exit_time
        CloseEncounterAutomaticEventEvidence(entry_time, exit_time,
            BigFloat(boundaries.entry_time), BigFloat(boundaries.exit_time),
            entry_difference, abs(entry_difference), exit_difference, abs(exit_difference),
            entry_sep, entry_sep - configuration.entry_threshold,
            exit_sep, exit_sep - configuration.exit_threshold, entry_rate, exit_rate;
            entry_threshold=configuration.entry_threshold,
            exit_threshold=configuration.exit_threshold)
    end
end

function CloseEncounterAutomaticEventEvidence(automatic_entry_time::Real,
    automatic_exit_time::Real, reference_entry_time::BigFloat,
    reference_exit_time::BigFloat, signed_entry_time_difference::BigFloat,
    absolute_entry_time_error::BigFloat, signed_exit_time_difference::BigFloat,
    absolute_exit_time_error::BigFloat, entry_separation::Real,
    entry_threshold_residual::Real, exit_separation::Real,
    exit_threshold_residual::Real, entry_radial_rate::Real, exit_radial_rate::Real;
    entry_threshold::Real=0.1, exit_threshold::Real=0.25)
    precision(reference_entry_time) == 256 && precision(reference_exit_time) == 256 ||
        throw(ArgumentError("Reference event times must retain 256-bit precision."))
    automatic_entry_time < automatic_exit_time || throw(ArgumentError("Automatic event times are unordered."))
    setprecision(BigFloat, 256) do
        signed_entry_time_difference == BigFloat(automatic_entry_time) - reference_entry_time || throw(ArgumentError("Entry-time difference is inconsistent."))
        signed_exit_time_difference == BigFloat(automatic_exit_time) - reference_exit_time || throw(ArgumentError("Exit-time difference is inconsistent."))
        absolute_entry_time_error == abs(signed_entry_time_difference) || throw(ArgumentError("Entry-time error is inconsistent."))
        absolute_exit_time_error == abs(signed_exit_time_difference) || throw(ArgumentError("Exit-time error is inconsistent."))
    end
    entry_threshold_residual == entry_separation - entry_threshold || throw(ArgumentError("Entry residual is inconsistent."))
    exit_threshold_residual == exit_separation - exit_threshold || throw(ArgumentError("Exit residual is inconsistent."))
    entry_radial_rate < 0 && exit_radial_rate > 0 || throw(ArgumentError("Event directions are invalid."))
    values = (automatic_entry_time, automatic_exit_time, entry_separation,
        entry_threshold_residual, exit_separation, exit_threshold_residual,
        entry_radial_rate, exit_radial_rate)
    all(isfinite, values) || throw(ArgumentError("Automatic event evidence is nonfinite."))
    CloseEncounterAutomaticEventEvidence(Float64(automatic_entry_time), Float64(automatic_exit_time),
        reference_entry_time, reference_exit_time, signed_entry_time_difference,
        absolute_entry_time_error, signed_exit_time_difference, absolute_exit_time_error,
        Float64(entry_separation), Float64(entry_threshold_residual), Float64(exit_separation),
        Float64(exit_threshold_residual), Float64(entry_radial_rate), Float64(exit_radial_rate);
        entry_threshold=Float64(entry_threshold), exit_threshold=Float64(exit_threshold))
end

struct CloseEncounterMethodFictitiousEndpointEvidence
    method::Symbol
    automatic_exit_time::Float64
    terminal_fictitious_time::Float64
    terminal_physical_time::Float64
    terminal_physical_time_residual::Float64
    function CloseEncounterMethodFictitiousEndpointEvidence(method, exit_time, s, time, residual)
        method in (:automatic, :explicit) || throw(ArgumentError("Unsupported endpoint method."))
        values = Float64[exit_time, s, time, residual]
        all(isfinite, values) || throw(ArgumentError("Method endpoint evidence is nonfinite."))
        values[4] == values[3] - values[1] || throw(ArgumentError("Method endpoint residual is inconsistent."))
        new(method, values...)
    end
end

struct CloseEncounterMatchedEndpointEvidence
    automatic::CloseEncounterMethodFictitiousEndpointEvidence
    explicit::CloseEncounterMethodFictitiousEndpointEvidence
    fictitious_time_difference::Float64
    function CloseEncounterMatchedEndpointEvidence(automatic, explicit, difference)
        automatic.method == :automatic && explicit.method == :explicit ||
            throw(ArgumentError("Matched endpoints use the wrong methods."))
        automatic.automatic_exit_time == explicit.automatic_exit_time ||
            throw(ArgumentError("Matched endpoints use different exit times."))
        value = Float64(difference)
        value == explicit.terminal_fictitious_time - automatic.terminal_fictitious_time ||
            throw(ArgumentError("Fictitious-time difference is inconsistent."))
        new(automatic, explicit, value)
    end
end

struct CloseEncounterMethodReferenceEvidence
    method::Symbol
    boundaries::CloseEncounterReferenceBoundaries
    errors::NamedTuple
    dense_periapsis::NamedTuple
    conservation::NamedTuple
    work::NamedTuple
    segment_count::Int
    switch_count::Int
    transitions::NTuple{2,CloseEncounterTransitionEvidence}

    function CloseEncounterMethodReferenceEvidence(method, boundaries, errors,
        dense_periapsis, conservation, work, segment_count, switch_count, transitions)
        method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
        keys(errors) == (:maximum_position, :maximum_velocity, :maximum_full_state,
            :maximum_combined, :final_position, :final_velocity, :final_full_state,
            :final_combined) || throw(ArgumentError("Reference-error fields differ."))
        keys(dense_periapsis) == (:time, :separation, :radial_numerator, :time_error,
            :separation_error) || throw(ArgumentError("Dense-periapsis fields differ."))
        keys(conservation) == (:maximum_relative_energy_drift, :maximum_momentum_drift,
            :maximum_angular_momentum_drift, :maximum_com_residual, :minimum_separation) ||
            throw(ArgumentError("Conservation fields differ."))
        keys(work) == (:saved_states, :accepted_steps, :rejected_steps, :rhs_evaluations) ||
            throw(ArgumentError("Solver-work fields differ."))
        all(x -> x isa Real && isfinite(x) && x >= 0, values(errors)) || throw(ArgumentError("Reference errors are invalid."))
        isfinite(dense_periapsis.time) && 0.0 <= dense_periapsis.time <= 1.6 ||
            throw(ArgumentError("Dense periapsis time is invalid."))
        isfinite(dense_periapsis.radial_numerator) || throw(ArgumentError("Dense radial numerator is invalid."))
        all(x -> isfinite(x) && x >= 0, (dense_periapsis.separation,
            dense_periapsis.time_error, dense_periapsis.separation_error)) ||
            throw(ArgumentError("Dense periapsis evidence is invalid."))
        all(x -> x isa Real && isfinite(x) && x >= 0, values(conservation)) || throw(ArgumentError("Invariant evidence is invalid."))
        all(x -> x isa Integer && x >= 0, values(work)) || throw(ArgumentError("Solver work is invalid."))
        (method == :explicit ? (segment_count == 3 && switch_count == 2) :
            (segment_count >= 1 && switch_count >= 2)) ||
            throw(ArgumentError("Method segment or switch count is invalid."))
        normalized = Tuple(transitions)
        length(normalized) == 2 || throw(ArgumentError("Entry and exit transition evidence are required."))
        new(method, boundaries, errors, dense_periapsis, conservation, work,
            Int(segment_count), Int(switch_count), normalized)
    end
end

struct CloseEncounterMethodDifferenceSample
    location::Symbol
    time::BigFloat
    pair_position_difference::Float64
    pair_velocity_difference::Float64
    full_state_difference::Float64
    function CloseEncounterMethodDifferenceSample(location, time::BigFloat, differences)
        location in CLOSE_ENCOUNTER_DIFFERENCE_SAMPLE_ORDER || throw(ArgumentError("Unsupported difference-sample location."))
        precision(time) == 256 || throw(ArgumentError("Difference-sample times must retain 256-bit precision."))
        values = Float64[differences.pair_position, differences.pair_velocity, differences.full_state]
        all(isfinite, values) && all(>=(0), values) || throw(ArgumentError("State differences are malformed."))
        new(location, time, values...)
    end
end

struct CloseEncounterAutomaticExplicitComparisonEvidence
    automatic_interval::Tuple{Float64,Float64}
    samples::NTuple{4,CloseEncounterMethodDifferenceSample}
    maximum_pair_position_difference::Float64
    maximum_pair_velocity_difference::Float64
    maximum_full_state_difference::Float64
    comparison_epoch_count::Int
    comparison_grid_convention::String
    periapsis_inside_interval::Bool

    function CloseEncounterAutomaticExplicitComparisonEvidence(interval, samples, maxima,
        count, convention=CLOSE_ENCOUNTER_COMPARISON_GRID_CONVENTION, inside=true)
        normalized_interval = Tuple(Float64.(interval))
        normalized = Tuple(samples)
        map(x -> x.location, normalized) == CLOSE_ENCOUNTER_DIFFERENCE_SAMPLE_ORDER ||
            throw(ArgumentError("Difference samples are reordered."))
        inside || throw(ArgumentError("Reference periapsis is outside the automatic interval."))
        setprecision(BigFloat, 256) do
            expected = (BigFloat(normalized_interval[1]), normalized[2].time,
                BigFloat(normalized_interval[2]), BigFloat(1.6))
            all(index -> normalized[index].time == expected[index], 1:4) ||
                throw(ArgumentError("Difference sample times differ from the approved locations."))
            all(index -> normalized[index].time < normalized[index + 1].time, 1:3) ||
                throw(ArgumentError("Difference sample times are not strictly ordered."))
        end
        normalized_interval[1] <= Float64(normalized[2].time) <= normalized_interval[2] ||
            throw(ArgumentError("Reference periapsis is outside the automatic interval."))
        values = Float64[maxima.pair_position, maxima.pair_velocity, maxima.full_state]
        all(isfinite, values) && all(>=(0), values) || throw(ArgumentError("Interval maxima are malformed."))
        convention == CLOSE_ENCOUNTER_COMPARISON_GRID_CONVENTION || throw(ArgumentError("Comparison-grid convention differs."))
        epochs = Float64[t for t in close_encounter_sample_times(CLOSE_ENCOUNTER_INTERVAL)
            if normalized_interval[1] <= t <= normalized_interval[2]]
        append!(epochs, [normalized_interval[1], Float64(normalized[2].time), normalized_interval[2]])
        sort!(unique!(epochs))
        count == length(epochs) || throw(ArgumentError("Comparison epoch count differs from the approved grid."))
        for component in 1:3
            maximum_value = values[component]
            samples_maximum = maximum(getfield(sample,
                (:pair_position_difference, :pair_velocity_difference, :full_state_difference)[component])
                for sample in normalized[1:3])
            maximum_value >= samples_maximum || throw(ArgumentError("Interval maximum is smaller than a retained in-interval sample."))
        end
        new(normalized_interval, normalized, values..., Int(count), String(convention), true)
    end
end

struct CloseEncounterRegularizedPointEvidence
    method::Symbol
    configuration::AbstractCloseEncounterRegularizedConfiguration
    boundaries::CloseEncounterReferenceBoundaries
    automatic_interval::Tuple{Float64,Float64}
    method_reference::CloseEncounterMethodReferenceEvidence
    event_evidence::CloseEncounterAutomaticEventEvidence
    comparison::CloseEncounterAutomaticExplicitComparisonEvidence
    fictitious_endpoints::CloseEncounterMatchedEndpointEvidence
    function CloseEncounterRegularizedPointEvidence(method, configuration, boundaries,
        interval, method_reference, event_evidence, comparison, endpoints)
        method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
        method_reference.method == method || throw(ArgumentError("Method evidence differs."))
        _record_fields_equal(boundaries, method_reference.boundaries) || throw(ArgumentError("Reference boundaries differ."))
        Tuple(interval) == comparison.automatic_interval || throw(ArgumentError("Matched intervals differ."))
        event_evidence.automatic_entry_time == interval[1] && event_evidence.automatic_exit_time == interval[2] ||
            throw(ArgumentError("Event evidence differs from the matched interval."))
        method_reference.transitions[1].physical_time == interval[1] &&
            method_reference.transitions[2].physical_time == interval[2] ||
            throw(ArgumentError("Transition times differ from the matched interval."))
        new(method, configuration, boundaries, Tuple(interval), method_reference,
            event_evidence, comparison, endpoints)
    end
end


struct CloseEncounterRegularizedPropagationFacts
    configuration::AbstractCloseEncounterRegularizedConfiguration
    method::Symbol
    automatic_interval::Tuple{Float64,Float64}
    achieved_final_time::Float64
    transitions::Tuple
    sampled_states::Tuple
    work::NamedTuple
    segment_count::Int
    switch_count::Int
    function CloseEncounterRegularizedPropagationFacts(configuration, method, interval,
        achieved_final_time, transitions, sampled_states,
        work, segment_count, switch_count)
        method in (:automatic, :explicit) || throw(ArgumentError("Unsupported propagation method."))
        normalized_interval = Tuple(Float64.(interval))
        0.0 < normalized_interval[1] < normalized_interval[2] < 1.6 ||
            throw(ArgumentError("Propagation interval is invalid."))
        Float64(achieved_final_time) == 1.6 || throw(ArgumentError("Completed propagation did not reach final time."))
        normalized_transitions = Tuple(transitions)
        length(normalized_transitions) in (0, 2) ||
            throw(ArgumentError("Propagation facts require zero or two transitions."))
        isempty(normalized_transitions) ||
            (normalized_transitions[1].physical_time == normalized_interval[1] &&
             normalized_transitions[2].physical_time == normalized_interval[2]) ||
            throw(ArgumentError("Propagation transition times differ."))
        states = Tuple(Vector{Float64}(state) for state in sampled_states)
        length(states) == length(close_encounter_sample_times(CLOSE_ENCOUNTER_INTERVAL)) ||
            throw(ArgumentError("Propagation sampled-state count differs."))
        all(state -> length(state) == 18 && all(isfinite, state), states) ||
            throw(ArgumentError("Propagation sampled states are malformed."))
        keys(work) == (:saved_states, :accepted_steps, :rejected_steps, :rhs_evaluations) ||
            throw(ArgumentError("Propagation work fields differ."))
        all(x -> x isa Integer && x >= 0, values(work)) || throw(ArgumentError("Propagation work is invalid."))
        expected = method == :explicit ? (3, 2) : (Int(segment_count), Int(switch_count))
        method == :explicit && (segment_count, switch_count) != expected &&
            throw(ArgumentError("Explicit segment or switch count differs."))
        segment_count >= 0 && switch_count >= 0 ||
            throw(ArgumentError("Propagation segment and switch counts must be nonnegative."))
        new(configuration, method, normalized_interval, 1.6,
            normalized_transitions, states, work,
            Int(segment_count), Int(switch_count))
    end
end

struct CloseEncounterRegularizedPropagationEvidence
    facts::CloseEncounterRegularizedPropagationFacts
    boundaries::CloseEncounterReferenceBoundaries
    event_evidence::CloseEncounterAutomaticEventEvidence
    function CloseEncounterRegularizedPropagationEvidence(facts, boundaries, event_evidence)
        length(facts.transitions) == 2 ||
            throw(ArgumentError("Completed propagation evidence requires two transitions."))
        event_evidence.automatic_entry_time == facts.automatic_interval[1] &&
            event_evidence.automatic_exit_time == facts.automatic_interval[2] ||
            throw(ArgumentError("Propagation event interval differs."))
        event_evidence.reference_entry_time == boundaries.entry_time &&
            event_evidence.reference_exit_time == boundaries.exit_time ||
            throw(ArgumentError("Propagation event reference times differ from shared boundaries."))
        event_evidence.entry_threshold_residual ==
            event_evidence.entry_separation - facts.configuration.entry_threshold ||
            throw(ArgumentError("Propagation entry residual differs from its controller threshold."))
        event_evidence.exit_threshold_residual ==
            event_evidence.exit_separation - facts.configuration.exit_threshold ||
            throw(ArgumentError("Propagation exit residual differs from its controller threshold."))
        new(facts, boundaries, event_evidence)
    end
end

function CloseEncounterRegularizedPropagationEvidence(configuration, method, boundaries,
    interval, achieved_final_time, event_evidence, transitions, sampled_states,
    work, segment_count, switch_count)
    facts = CloseEncounterRegularizedPropagationFacts(configuration, method, interval,
        achieved_final_time, transitions, sampled_states, work, segment_count, switch_count)
    CloseEncounterRegularizedPropagationEvidence(facts, boundaries, event_evidence)
end

function Base.getproperty(evidence::CloseEncounterRegularizedPropagationEvidence, name::Symbol)
    name in (:facts, :boundaries, :event_evidence) && return getfield(evidence, name)
    getproperty(getfield(evidence, :facts), name)
end

struct CloseEncounterRegularizedMethodEvidence
    propagation::CloseEncounterRegularizedPropagationEvidence
    reference::CloseEncounterMethodReferenceEvidence
    endpoint::Union{Nothing,CloseEncounterMethodFictitiousEndpointEvidence}
    function CloseEncounterRegularizedMethodEvidence(propagation, reference, endpoint)
        propagation.method == reference.method ||
            throw(ArgumentError("Method evidence identifiers differ."))
        isnothing(endpoint) || endpoint.method == propagation.method ||
            throw(ArgumentError("Method endpoint identifier differs."))
        _record_fields_equal(propagation.boundaries, reference.boundaries) ||
            throw(ArgumentError("Method reference boundaries differ."))
        reference.transitions == propagation.transitions ||
            throw(ArgumentError("Method transitions differ."))
        reference.work == propagation.work || throw(ArgumentError("Method work differs."))
        reference.segment_count == propagation.segment_count &&
            reference.switch_count == propagation.switch_count ||
            throw(ArgumentError("Method counts differ."))
        isnothing(endpoint) || endpoint.automatic_exit_time == propagation.automatic_interval[2] ||
            throw(ArgumentError("Method endpoint uses the wrong exit time."))
        new(propagation, reference, endpoint)
    end
end

struct CloseEncounterRegularizedPairAttempt
    configuration::AbstractCloseEncounterRegularizedConfiguration
    reference::CloseEncounterReferenceExecution
    automatic_execution::ExecutionOutcome
    explicit_execution::ExecutionOutcome
    automatic_evidence::Union{Nothing,CloseEncounterRegularizedMethodEvidence}
    explicit_evidence::Union{Nothing,CloseEncounterRegularizedMethodEvidence}
    automatic_partial::Union{Nothing,CloseEncounterRegularizedPropagationEvidence,CloseEncounterRegularizedPropagationFacts}
    explicit_partial::Union{Nothing,CloseEncounterRegularizedPropagationEvidence,CloseEncounterRegularizedPropagationFacts}
    comparison::Union{Nothing,CloseEncounterAutomaticExplicitComparisonEvidence}
    matched_endpoints::Union{Nothing,CloseEncounterMatchedEndpointEvidence}
    comparison_failure::Union{Nothing,String}
    function CloseEncounterRegularizedPairAttempt(configuration, reference,
        automatic_execution, explicit_execution, automatic_evidence, explicit_evidence,
        automatic_partial, explicit_partial, comparison, matched_endpoints,
        comparison_failure=nothing)
        _close_regularized_configuration_is_approved(configuration) ||
            throw(ArgumentError("Attempt configuration is not approved."))
        for (method, execution, evidence, partial) in ((:automatic, automatic_execution,
            automatic_evidence, automatic_partial), (:explicit, explicit_execution,
            explicit_evidence, explicit_partial))
            execution.actual == actual_completed && (isnothing(evidence) || isnothing(evidence.endpoint)) &&
                throw(ArgumentError("Completed $method execution requires complete method evidence."))
            execution.actual != actual_completed && isnothing(execution.summary) &&
                throw(ArgumentError("Abnormal $method execution requires a factual summary."))
            !isnothing(evidence) && !isnothing(partial) &&
                throw(ArgumentError("Complete and partial $method evidence are mutually exclusive."))
            retained = isnothing(evidence) ? partial : evidence.propagation
            isnothing(retained) || retained.configuration == configuration ||
                throw(ArgumentError("$method evidence configuration differs."))
            isnothing(retained) || retained.method == method ||
                throw(ArgumentError("$method evidence identifier differs."))
            isnothing(retained) || retained isa CloseEncounterRegularizedPropagationFacts ||
                _record_fields_equal(retained.boundaries, reference.boundaries) ||
                throw(ArgumentError("$method evidence does not use the shared reference execution."))
        end
        explicit_execution.actual == actual_completed && isnothing(explicit_evidence) &&
            throw(ArgumentError("Completed explicit execution requires retained evidence from the valid automatic interval."))
        both_completed = automatic_execution.actual == actual_completed &&
            explicit_execution.actual == actual_completed
        both_measured = !isnothing(automatic_evidence) && !isnothing(explicit_evidence)
        automatic_complete = !isnothing(automatic_evidence) &&
            !isnothing(automatic_evidence.endpoint)
        explicit_complete = !isnothing(explicit_evidence) &&
            !isnothing(explicit_evidence.endpoint)
        complete_paired_evidence = automatic_complete && explicit_complete &&
            !isnothing(comparison) && !isnothing(matched_endpoints)
        complete_paired_evidence && !both_completed &&
            throw(ArgumentError("Complete paired evidence requires completed direct executions."))
        complete_paired_evidence && !isnothing(comparison_failure) &&
            throw(ArgumentError("Complete paired evidence cannot have a failure summary."))
        both_completed && isnothing(comparison) &&
            throw(ArgumentError("Completed paired evidence requires matched comparison evidence."))
        both_completed && isnothing(matched_endpoints) &&
            throw(ArgumentError("Completed paired evidence requires matched endpoint evidence."))
        if !isnothing(comparison)
            both_measured ||
                throw(ArgumentError("Matched comparison requires both method measurements."))
            both_completed && !isnothing(comparison_failure) &&
                throw(ArgumentError("Complete paired evidence cannot have a failure summary."))
        elseif !isnothing(comparison_failure)
            both_measured ||
                throw(ArgumentError("Comparison failure requires both method measurements."))
            isempty(strip(String(comparison_failure))) && throw(ArgumentError("Comparison failure summary is blank."))
        elseif both_measured
            throw(ArgumentError("Missing matched comparison requires a factual failure summary."))
        end
        !isnothing(matched_endpoints) && isnothing(comparison) &&
            throw(ArgumentError("Matched endpoints require matched comparison evidence."))
        !isnothing(matched_endpoints) && !isnothing(comparison) &&
            !isnothing(comparison_failure) &&
            throw(ArgumentError("Matched comparison and endpoints cannot have a comparison failure summary."))
        !isnothing(comparison_failure) && both_completed &&
            throw(ArgumentError("Comparison failure requires an incomplete paired stage."))
        intervals = [x.automatic_interval for x in
            (isnothing(automatic_evidence) ? automatic_partial : automatic_evidence.propagation,
             isnothing(explicit_evidence) ? explicit_partial : explicit_evidence.propagation) if !isnothing(x)]
        length(intervals) <= 1 || all(==(first(intervals)), intervals) ||
            throw(ArgumentError("Explicit interval differs from the automatic interval."))
        retained_interval = isempty(intervals) ? nothing : first(intervals)
        if !isnothing(comparison)
            isnothing(retained_interval) && throw(ArgumentError("Comparison requires a retained interval."))
            comparison.automatic_interval == retained_interval ||
                throw(ArgumentError("Comparison interval differs from the retained method interval."))
            comparison.samples[2].location == :periapsis &&
                comparison.samples[2].time == reference.boundaries.periapsis_time ||
                throw(ArgumentError("Comparison periapsis differs from the independent reference."))
        end
        if !isnothing(matched_endpoints)
            isnothing(retained_interval) && throw(ArgumentError("Matched endpoints require a retained interval."))
            matched_endpoints.automatic.automatic_exit_time == retained_interval[2] &&
                matched_endpoints.explicit.automatic_exit_time == retained_interval[2] ||
                throw(ArgumentError("Matched endpoints use the wrong retained exit time."))
            for (method, evidence, endpoint) in ((:automatic, automatic_evidence,
                matched_endpoints.automatic), (:explicit, explicit_evidence,
                matched_endpoints.explicit))
                isnothing(evidence) || isnothing(evidence.endpoint) &&
                    throw(ArgumentError("Matched endpoints require the $method method endpoint."))
                isnothing(evidence) || _record_fields_equal(evidence.endpoint, endpoint) ||
                    throw(ArgumentError("Matched $method endpoint differs from method evidence."))
            end
        end
        new(configuration, reference, automatic_execution, explicit_execution,
            automatic_evidence, explicit_evidence, automatic_partial, explicit_partial,
            comparison, matched_endpoints,
            isnothing(comparison_failure) ? nothing : String(comparison_failure))
    end
end

function _close_regularized_dense_periapsis(state_at_time, boundaries)
    left = Float64(boundaries.entry_time); right = Float64(boundaries.exit_time)
    close_encounter_periapsis(state_at_time, left, right;
        iterations=CLOSE_ENCOUNTER_STATE_EVALUATION_MAXIMUM_ITERATIONS)
end

function _close_regularized_reference_measurement(method, trajectory, state_at_time,
    reference, problem, times, states, work, segment_count, switch_count, transitions)
    errors = close_encounter_trajectory_errors(states, reference.sampled_states)
    conservation = close_encounter_conservation(problem.system, times, states)
    periapsis = _close_regularized_dense_periapsis(state_at_time, reference.boundaries)
    dense = setprecision(BigFloat, reference.precision_bits) do
        method_time = BigFloat(Float64(periapsis.time))
        method_separation = BigFloat(Float64(periapsis.separation))
        (time=Float64(periapsis.time), separation=Float64(periapsis.separation),
            radial_numerator=Float64(periapsis.radial_numerator),
            time_error=Float64(abs(method_time - reference.boundaries.periapsis_time)),
            separation_error=Float64(abs(method_separation - reference.boundaries.periapsis_separation)))
    end
    CloseEncounterMethodReferenceEvidence(method, reference.boundaries, errors, dense,
        conservation, work, segment_count, switch_count, transitions)
end

function _close_regularized_comparison(automatic, explicit, interval, reference, controls, times)
    setprecision(BigFloat, 256) do
        locations = (BigFloat(interval[1]), BigFloat(reference.boundaries.periapsis_time),
            BigFloat(interval[2]), BigFloat(1.6))
        interval[1] <= Float64(locations[2]) <= interval[2] || throw(ArgumentError("Reference periapsis is outside the automatic interval."))
        samples = ntuple(4) do index
            difference = close_encounter_state_difference(
                close_encounter_automatic_state(automatic, locations[index], controls),
                close_encounter_explicit_state(explicit, locations[index], controls))
            CloseEncounterMethodDifferenceSample(CLOSE_ENCOUNTER_DIFFERENCE_SAMPLE_ORDER[index],
                locations[index], difference)
        end
        epochs = Float64[t for t in times if interval[1] <= t <= interval[2]]
        append!(epochs, [interval[1], Float64(reference.boundaries.periapsis_time), interval[2]])
        sort!(unique!(epochs))
        differences = [close_encounter_state_difference(
            close_encounter_automatic_state(automatic, time, controls),
            close_encounter_explicit_state(explicit, time, controls)) for time in epochs]
        maxima = (pair_position=maximum(x.pair_position for x in differences),
            pair_velocity=maximum(x.pair_velocity for x in differences),
            full_state=maximum(x.full_state for x in differences))
        CloseEncounterAutomaticExplicitComparisonEvidence(interval, samples, maxima, length(epochs))
    end
end

function _close_regularized_transition_evidence(method, trajectory)
    if method == :automatic
        entry, exit = close_encounter_switch_events(trajectory)
        (CloseEncounterTransitionEvidence(close_encounter_transition_tuple(entry.transition_diagnostics)),
            CloseEncounterTransitionEvidence(close_encounter_transition_tuple(exit.transition_diagnostics)))
    else
        (CloseEncounterTransitionEvidence(close_encounter_transition_tuple(trajectory.entry_continuity)),
            CloseEncounterTransitionEvidence(close_encounter_transition_tuple(trajectory.exit_continuity)))
    end
end

function _close_regularized_propagation_facts(method, trajectory, configuration,
    problem, times, controls, interval; transition_runner=_close_regularized_transition_evidence)
    if method == :automatic
        states = close_encounter_automatic_states(trajectory, times, controls)
        work = close_encounter_automatic_work(trajectory)
        segment_count, switch_count = length(trajectory.segments), length(trajectory.switch_events)
        achieved = Float64(trajectory.final_time)
    else
        states = close_encounter_explicit_states(trajectory, times, controls)
        work = close_encounter_explicit_work(trajectory)
        segment_count, switch_count = 3, 2
        achieved = last(times)
    end
    transitions, failure = try
        (transition_runner(method, trajectory), nothing)
    catch error
        ((), sprint(showerror, error))
    end
    facts = CloseEncounterRegularizedPropagationFacts(configuration, method, interval,
        achieved, transitions, states, work, segment_count, switch_count)
    (facts=facts, transition_failure=failure)
end

_close_regularized_propagation_evidence(facts, reference, event_evidence) =
    CloseEncounterRegularizedPropagationEvidence(facts, reference.boundaries, event_evidence)

function _close_regularized_method_endpoint(method, trajectory, interval)
    if method == :automatic
        segment = close_encounter_automatic_regularized_segment(trajectory)
        s = Float64(segment.location.fictitious_time)
        time = Float64(segment.location.regularized_result.solution(s)[14])
    else
        s = Float64(trajectory.regularized_segment.exit_fictitious_time)
        time = Float64(trajectory.regularized_segment.regularized_result.solution(s)[14])
    end
    CloseEncounterMethodFictitiousEndpointEvidence(method, interval[2], s, time,
        time - interval[2])
end

function _close_regularized_method_measurement(propagation, trajectory, reference,
    problem, times, controls)
    state_at_time = propagation.method == :automatic ?
        time -> close_encounter_automatic_state(trajectory, time, controls) :
        time -> close_encounter_explicit_state(trajectory, time, controls)
    _close_regularized_reference_measurement(propagation.method, trajectory,
        state_at_time, reference, problem, times, collect(propagation.sampled_states),
        propagation.work, propagation.segment_count, propagation.switch_count,
        propagation.transitions)
end

function attempt_close_encounter_regularized_pair(configuration::AbstractCloseEncounterRegularizedConfiguration,
    reference::CloseEncounterReferenceExecution; automatic_runner=close_encounter_automatic_propagation,
    interval_runner=close_encounter_automatic_interval,
    event_runner=close_encounter_switch_events,
    event_evidence_runner=CloseEncounterAutomaticEventEvidence,
    explicit_runner=close_encounter_explicit_propagation,
    automatic_propagation_facts_runner=_close_regularized_propagation_facts,
    explicit_propagation_facts_runner=_close_regularized_propagation_facts,
    automatic_transition_runner=_close_regularized_transition_evidence,
    explicit_transition_runner=_close_regularized_transition_evidence,
    automatic_propagation_evidence_runner=_close_regularized_propagation_evidence,
    explicit_propagation_evidence_runner=_close_regularized_propagation_evidence,
    automatic_method_measurement_runner=_close_regularized_method_measurement,
    explicit_method_measurement_runner=_close_regularized_method_measurement,
    automatic_endpoint_measurement_runner=_close_regularized_method_endpoint,
    explicit_endpoint_measurement_runner=_close_regularized_method_endpoint,
    comparison_runner=_close_regularized_comparison,
    matched_endpoint_runner=CloseEncounterMatchedEndpointEvidence)
    controls = _close_regularized_controls(configuration)
    problem = close_encounter_problem(Float64)
    times = close_encounter_sample_times(problem.tspan)
    automatic = try automatic_runner(problem, controls) catch error
        summary = sprint(showerror, error)
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            ExecutionOutcome(actual_errored; summary), ExecutionOutcome(actual_terminated;
                summary="Not executed because automatic interval was unavailable: $summary"),
            nothing, nothing, nothing, nothing, nothing, nothing)
    end
    interval = try interval_runner(automatic) catch error
        summary = sprint(showerror, error)
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            ExecutionOutcome(actual_terminated; summary), ExecutionOutcome(actual_terminated; summary="Not executed because automatic interval was unavailable: $summary"),
            nothing, nothing, nothing, nothing, nothing, nothing)
    end
    append_failure(current, value) = isnothing(current) ? value : "$current; $value"
    automatic_facts = nothing
    automatic_failure = nothing
    try
        result = automatic_propagation_facts_runner(:automatic, automatic,
            configuration, problem, times, controls, interval;
            transition_runner=automatic_transition_runner)
        automatic_facts = result.facts
        automatic_failure = result.transition_failure
    catch error
        automatic_failure = sprint(showerror, error)
    end
    entry = exit = event_evidence = nothing
    event_extracted = true
    try
        entry, exit = event_runner(automatic)
    catch error
        event_extracted = false
        automatic_failure = append_failure(automatic_failure, sprint(showerror, error))
    end
    if event_extracted
        try
            event_evidence = configuration isa CloseEncounterRegularizedToleranceConfiguration ?
                event_evidence_runner(entry, exit, reference.boundaries) :
                event_evidence_runner(entry, exit, reference.boundaries, configuration)
        catch error
            automatic_failure = append_failure(automatic_failure, sprint(showerror, error))
        end
    end
    automatic_propagation = nothing
    if !isnothing(automatic_facts) && length(automatic_facts.transitions) == 2 &&
        !isnothing(event_evidence)
        try
            automatic_propagation = automatic_propagation_evidence_runner(
                automatic_facts, reference, event_evidence)
        catch error
            automatic_failure = append_failure(automatic_failure, sprint(showerror, error))
        end
    end
    function measure_method(method, propagation, trajectory, measurement_runner,
        endpoint_runner)
        isnothing(propagation) && return (nothing, nothing)
        measured = try
            measurement_runner(propagation, trajectory, reference, problem, times, controls)
        catch error
            return (nothing, sprint(showerror, error))
        end
        reference_evidence = measured isa CloseEncounterRegularizedMethodEvidence ?
            measured.reference : measured
        endpoint = try
            endpoint_runner(method, trajectory, interval)
        catch error
            return (CloseEncounterRegularizedMethodEvidence(propagation,
                reference_evidence, nothing), sprint(showerror, error))
        end
        (CloseEncounterRegularizedMethodEvidence(propagation, reference_evidence,
            endpoint), nothing)
    end
    automatic_method, automatic_measurement_failure = measure_method(:automatic,
        automatic_propagation, automatic, automatic_method_measurement_runner,
        automatic_endpoint_measurement_runner)
    isnothing(automatic_measurement_failure) ||
        (automatic_failure = append_failure(automatic_failure, automatic_measurement_failure))

    explicit = try explicit_runner(problem, interval, controls) catch error
        summary = sprint(showerror, error)
        automatic_execution = isnothing(automatic_failure) ?
            ExecutionOutcome(actual_completed; exit_code=0) :
            ExecutionOutcome(actual_errored; summary=automatic_failure)
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            automatic_execution, ExecutionOutcome(actual_errored; summary),
            automatic_method, nothing,
            isnothing(automatic_method) ? (isnothing(automatic_propagation) ? automatic_facts : automatic_propagation) : nothing,
            nothing, nothing, nothing)
    end
    explicit_failure = nothing
    explicit_facts = nothing
    explicit_propagation = nothing
    try
        result = explicit_propagation_facts_runner(:explicit, explicit,
            configuration, problem, times, controls, interval;
            transition_runner=explicit_transition_runner)
        explicit_facts = result.facts
        explicit_failure = result.transition_failure
    catch error
        explicit_failure = sprint(showerror, error)
    end
    if isnothing(event_evidence)
        explicit_failure = append_failure(explicit_failure,
            "Explicit propagation evidence unavailable: $(automatic_failure)")
    elseif !isnothing(explicit_facts) && length(explicit_facts.transitions) == 2
        try
            explicit_propagation = explicit_propagation_evidence_runner(
                explicit_facts, reference, event_evidence)
        catch error
            explicit_failure = append_failure(explicit_failure, sprint(showerror, error))
        end
    end
    explicit_method, explicit_measurement_failure = measure_method(:explicit,
        explicit_propagation, explicit, explicit_method_measurement_runner,
        explicit_endpoint_measurement_runner)
    isnothing(explicit_measurement_failure) ||
        (explicit_failure = append_failure(explicit_failure, explicit_measurement_failure))
    automatic_execution = isnothing(automatic_failure) ?
        ExecutionOutcome(actual_completed; exit_code=0) :
        ExecutionOutcome(actual_errored; summary=automatic_failure)
    explicit_execution = isnothing(explicit_failure) ?
        ExecutionOutcome(actual_completed; exit_code=0) :
        ExecutionOutcome(actual_errored; summary=explicit_failure)
    if isnothing(automatic_method) || isnothing(explicit_method)
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            automatic_execution, explicit_execution, automatic_method, explicit_method,
            isnothing(automatic_method) ? (isnothing(automatic_propagation) ? automatic_facts : automatic_propagation) : nothing,
            isnothing(explicit_method) ? (isnothing(explicit_propagation) ? explicit_facts : explicit_propagation) : nothing,
            nothing, nothing)
    end
    if isnothing(automatic_method.endpoint) || isnothing(explicit_method.endpoint)
        endpoint_failure = isnothing(automatic_method.endpoint) ? automatic_failure : explicit_failure
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            automatic_execution, explicit_execution, automatic_method, explicit_method,
            nothing, nothing, nothing, nothing, endpoint_failure)
    end
    comparison = try comparison_runner(automatic, explicit, interval, reference, controls, times) catch error
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            ExecutionOutcome(actual_errored; summary="Matched comparison failed: $(sprint(showerror, error))"),
            ExecutionOutcome(actual_errored; summary="Matched comparison failed: $(sprint(showerror, error))"),
            automatic_method, explicit_method, nothing, nothing, nothing, nothing,
            sprint(showerror, error))
    end
    matched = try matched_endpoint_runner(automatic_method.endpoint,
        explicit_method.endpoint,
        explicit_method.endpoint.terminal_fictitious_time - automatic_method.endpoint.terminal_fictitious_time) catch error
        return CloseEncounterRegularizedPairAttempt(configuration, reference,
            ExecutionOutcome(actual_errored; summary="Matched endpoint construction failed: $(sprint(showerror, error))"),
            ExecutionOutcome(actual_errored; summary="Matched endpoint construction failed: $(sprint(showerror, error))"),
            automatic_method, explicit_method, nothing, nothing, comparison, nothing,
            sprint(showerror, error))
    end
    CloseEncounterRegularizedPairAttempt(configuration, reference,
        automatic_execution, explicit_execution, automatic_method, explicit_method,
        nothing, nothing, comparison, matched)
end

const _CLOSE_REGULARIZED_REQUIRED_METRICS = (
    :maximum_pair_relative_position_error, :maximum_pair_relative_velocity_error,
    :maximum_full_state_error, :final_pair_relative_position_error,
    :final_pair_relative_velocity_error, :final_full_state_error,
    :dense_periapsis_time_error, :dense_periapsis_separation_error,
    :maximum_relative_energy_drift, :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift, :maximum_center_of_mass_residual,
    :minimum_sampled_pair_separation, :entry_full_state_difference,
    :periapsis_full_state_difference, :exit_full_state_difference,
    :final_full_state_difference, :maximum_interval_full_state_difference,
    :entry_transition_state_residual, :exit_transition_state_residual,
    :maximum_transition_state_residual, :terminal_physical_time_residual,
)

function _close_regularized_fixed_controls(method)
    (ValidationParameter(:method, method), ValidationParameter(:selected_pair, (1, 2)),
        ValidationParameter(:physical_interval, (0.0, 1.6)),
        ValidationParameter(:physical_sample_step, 0.002),
        ValidationParameter(:cartesian_algorithm, :Vern9),
        ValidationParameter(:cartesian_solver_selector, :accurate),
        ValidationParameter(:cartesian_relative_tolerance, 1e-13),
        ValidationParameter(:cartesian_absolute_tolerance, 1e-13),
        ValidationParameter(:entry_threshold, 0.1),
        ValidationParameter(:ambiguity_threshold, 0.25),
        ValidationParameter(:exit_threshold, 0.25),
        ValidationParameter(:minimum_separation_ratio, 10.0),
        ValidationParameter(:maximum_switches, 10),
        ValidationParameter(:state_evaluation_tolerance, 1e-14),
        ValidationParameter(:state_evaluation_maximum_iterations, 256),
        ValidationParameter(:regularized_representation, :planar_levi_civita),
        ValidationParameter(:regularized_initial_step, 0.1),
        ValidationParameter(:regularized_maximum_iterations, 256),
        ValidationParameter(:explicit_interval_source, :corresponding_automatic_run),
        ValidationParameter(:reference_arithmetic, :BigFloat),
        ValidationParameter(:reference_precision, 256),
        ValidationParameter(:reference_solver_selector, :extreme),
        ValidationParameter(:reference_relative_tolerance, "1e-30"),
        ValidationParameter(:reference_absolute_tolerance, "1e-30"),
        ValidationParameter(:reference_dense_output, true),
        ValidationParameter(:reference_save_everystep, true))
end

function close_encounter_regularized_investigation_definition(method::Symbol)
    method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
    id = Symbol(:close_encounter_, method, :_regularized_tolerance)
    InvestigationDefinition(id, "Close-encounter $(method) regularised-tolerance series",
        "Descriptive matched regularised-tolerance evidence using one independent reference.",
        close_encounter_case_definition(), :regularized_tolerance,
        _close_regularized_fixed_controls(method), _CLOSE_REGULARIZED_REQUIRED_METRICS, (),
        CLOSE_ENCOUNTER_REGULARIZED_DEFINITION_VERSION)
end

function _close_regularized_validation_configuration(configuration, method)
    ValidationConfiguration(solver=:accurate,
        relative_tolerance=configuration.regularized_relative_tolerance,
        absolute_tolerance=configuration.regularized_absolute_tolerance,
        time_interval=(0.0, 1.6), sampling="step=0.002", selected_pair=(1, 2),
        thresholds=(ValidationParameter(:entry_threshold, configuration.entry_threshold),
            ValidationParameter(:ambiguity_threshold, configuration.ambiguity_threshold),
            ValidationParameter(:exit_threshold, configuration.exit_threshold)),
        parameters=(ValidationParameter(:method, method),
            ValidationParameter(:cartesian_relative_tolerance, configuration.cartesian_relative_tolerance),
            ValidationParameter(:cartesian_absolute_tolerance, configuration.cartesian_absolute_tolerance),
            ValidationParameter(:state_evaluation_tolerance, configuration.state_evaluation_tolerance),
            ValidationParameter(:regularized_initial_step, configuration.regularized_initial_step),
            ValidationParameter(:regularized_maximum_iterations, configuration.regularized_maximum_iterations),
            ValidationParameter(:state_evaluation_maximum_iterations, configuration.state_evaluation_maximum_iterations),
            ValidationParameter(:explicit_interval_source, :corresponding_automatic_run)))
end

function _close_regularized_token(tolerance)
    index = findfirst(==(Float64(tolerance)), CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    isnothing(index) && throw(ArgumentError("Unsupported regularised tolerance."))
    ("1e_10", "1e_11", "1e_12", "1e_13")[index]
end
close_encounter_regularized_performance_benchmark_id(method, tolerance) =
    Symbol(:close_encounter_, method, :_regularized_tolerance_, _close_regularized_token(tolerance))

function close_encounter_regularized_performance_definition(method, configuration)
    method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
    PerformanceBenchmarkDefinition(close_encounter_regularized_performance_benchmark_id(
        method, configuration.regularized_relative_tolerance),
        "Close-encounter $(method) regularised tolerance point",
        method == :automatic ? "Automatic switching propagation only." :
            "Explicit composition only; corresponding automatic interval is untimed setup.",
        "examples/validation/performance/close_encounter_regularized_tolerance.jl",
        (:close_encounter, method, :regularized_tolerance),
        (:close_encounter, :investigation_2), "2.0.0",
        (:elapsed_time, :solver_statistics, :saved_states),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

function close_encounter_regularized_performance_operation(method, configuration;
    automatic_runner=close_encounter_automatic_propagation,
    explicit_runner=close_encounter_explicit_propagation,
    interval_runner=close_encounter_automatic_interval,
    automatic_work_runner=close_encounter_automatic_work,
    explicit_work_runner=close_encounter_explicit_work,
    automatic_count_runner=trajectory ->
        (length(trajectory.segments), length(trajectory.switch_events)))
    controls = _close_regularized_controls(configuration)
    problem = close_encounter_problem(Float64)
    if method == :automatic
        return () -> begin
            trajectory = automatic_runner(problem, controls)
            interval_runner(trajectory)
            work = automatic_work_runner(trajectory)
            segment_count, switch_count = automatic_count_runner(trajectory)
            PerformanceObservation(solver_statistics=SolverStatistics(
                accepted_steps=work.accepted_steps, rejected_steps=work.rejected_steps,
                rhs_evaluations=work.rhs_evaluations, saved_states=work.saved_states,
                segment_count=segment_count, switch_count=switch_count),
                saved_states=work.saved_states)
        end
    elseif method == :explicit
        automatic = automatic_runner(problem, controls)
        interval = interval_runner(automatic)
        return () -> begin
            trajectory = explicit_runner(problem, interval, controls)
            work = explicit_work_runner(trajectory)
            PerformanceObservation(solver_statistics=SolverStatistics(
                accepted_steps=work.accepted_steps, rejected_steps=work.rejected_steps,
                rhs_evaluations=work.rhs_evaluations, saved_states=work.saved_states,
                segment_count=3, switch_count=2),
                saved_states=work.saved_states)
        end
    end
    throw(ArgumentError("Unsupported regularised method."))
end

function close_encounter_regularized_performance_entry(method, configuration;
    policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    PerformanceBenchmarkEntry(close_encounter_regularized_performance_definition(method, configuration),
        _close_regularized_validation_configuration(configuration, method), policy,
        joinpath(performance_directory, "close_encounter_regularized_tolerance.jl"))
end

function close_encounter_regularized_performance_entries(; kwargs...)
    Tuple(close_encounter_regularized_performance_entry(method,
        CloseEncounterRegularizedToleranceConfiguration(tolerance); kwargs...)
        for method in (:automatic, :explicit)
        for tolerance in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
end

function decode_close_encounter_regularized_benchmark_id(id::Symbol)
    for method in (:automatic, :explicit), tolerance in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES
        close_encounter_regularized_performance_benchmark_id(method, tolerance) == id &&
            return (method=method, configuration=CloseEncounterRegularizedToleranceConfiguration(tolerance))
    end
    throw(ArgumentError("Unsupported close-encounter regularised benchmark ID $(id)."))
end

struct CloseEncounterRegularizedSupportingEvidence
    method::Symbol
    method_evidence::Union{Nothing,CloseEncounterRegularizedMethodEvidence}
    propagation_evidence::Union{Nothing,CloseEncounterRegularizedPropagationEvidence,CloseEncounterRegularizedPropagationFacts}
    comparison::Union{Nothing,CloseEncounterAutomaticExplicitComparisonEvidence}
    matched_endpoints::Union{Nothing,CloseEncounterMatchedEndpointEvidence}
    stage::Symbol
    summary::Union{Nothing,String}
    function CloseEncounterRegularizedSupportingEvidence(method, method_evidence,
        propagation_evidence, comparison, matched_endpoints, stage; summary=nothing)
        method in (:automatic, :explicit) || throw(ArgumentError("Unsupported supporting-evidence method."))
        isnothing(method_evidence) && isnothing(propagation_evidence) &&
            throw(ArgumentError("Supporting evidence must retain propagation facts or method evidence."))
        (isnothing(method_evidence) || isnothing(propagation_evidence)) ||
            throw(ArgumentError("Complete and partial method evidence are mutually exclusive."))
        retained = isnothing(method_evidence) ? propagation_evidence : method_evidence.propagation
        retained.method == method || throw(ArgumentError("Supporting-evidence method differs."))
        stage in (:propagation, :measurement, :comparison, :complete) || throw(ArgumentError("Unsupported evidence stage."))
        normalized = isnothing(summary) ? nothing : _nonempty_string(summary, "summary")
        if stage == :propagation
            isnothing(method_evidence) && !isnothing(propagation_evidence) &&
                isnothing(comparison) && isnothing(matched_endpoints) &&
                !isnothing(normalized) || throw(ArgumentError("Propagation-stage evidence is contradictory."))
        elseif stage == :measurement
            !isnothing(method_evidence) && isnothing(propagation_evidence) &&
                isnothing(comparison) && isnothing(matched_endpoints) &&
                !isnothing(normalized) || throw(ArgumentError("Measurement-stage evidence is contradictory."))
        elseif stage == :comparison
            !isnothing(method_evidence) && !isnothing(method_evidence.endpoint) &&
                isnothing(propagation_evidence) && !isnothing(comparison) &&
                isnothing(matched_endpoints) && !isnothing(normalized) ||
                throw(ArgumentError("Comparison-stage evidence is contradictory."))
        else
            !isnothing(method_evidence) && !isnothing(method_evidence.endpoint) &&
                isnothing(propagation_evidence) && !isnothing(comparison) &&
                !isnothing(matched_endpoints) && isnothing(normalized) ||
                throw(ArgumentError("Complete supporting evidence is contradictory."))
        end
        if !isnothing(comparison)
            comparison.automatic_interval == retained.automatic_interval ||
                throw(ArgumentError("Supporting comparison interval differs from method evidence."))
            comparison.samples[2].location == :periapsis &&
                comparison.samples[2].time == method_evidence.reference.boundaries.periapsis_time ||
                throw(ArgumentError("Supporting comparison periapsis differs from the independent reference."))
        end
        if !isnothing(matched_endpoints)
            endpoint = method == :automatic ? matched_endpoints.automatic : matched_endpoints.explicit
            _record_fields_equal(method_evidence.endpoint, endpoint) ||
                throw(ArgumentError("Supporting method endpoint differs from matched evidence."))
        end
        new(method, method_evidence, propagation_evidence, comparison,
            matched_endpoints, stage, normalized)
    end
end

function _close_regularized_method_metrics(evidence)
    r = evidence.reference
    errors = r.errors; conservation = r.conservation; transitions = r.transitions
    common = (ValidationMetric(:maximum_pair_relative_position_error, "Maximum pair-relative position error", errors.maximum_position),
        ValidationMetric(:maximum_pair_relative_velocity_error, "Maximum pair-relative velocity error", errors.maximum_velocity),
        ValidationMetric(:maximum_full_state_error, "Maximum full-state error", errors.maximum_full_state),
        ValidationMetric(:final_pair_relative_position_error, "Final pair-relative position error", errors.final_position),
        ValidationMetric(:final_pair_relative_velocity_error, "Final pair-relative velocity error", errors.final_velocity),
        ValidationMetric(:final_full_state_error, "Final full-state error", errors.final_full_state),
        ValidationMetric(:dense_periapsis_time_error, "Dense periapsis time error", r.dense_periapsis.time_error),
        ValidationMetric(:dense_periapsis_separation_error, "Dense periapsis separation error", r.dense_periapsis.separation_error),
        ValidationMetric(:maximum_relative_energy_drift, "Maximum relative energy drift", conservation.maximum_relative_energy_drift),
        ValidationMetric(:maximum_linear_momentum_drift, "Maximum linear momentum drift", conservation.maximum_momentum_drift),
        ValidationMetric(:maximum_angular_momentum_drift, "Maximum angular momentum drift", conservation.maximum_angular_momentum_drift),
        ValidationMetric(:maximum_center_of_mass_residual, "Maximum centre-of-mass residual", conservation.maximum_com_residual),
        ValidationMetric(:minimum_sampled_pair_separation, "Minimum sampled pair separation", conservation.minimum_separation),
        ValidationMetric(:entry_transition_state_residual, "Entry transition state residual", transitions[1].state_residual),
        ValidationMetric(:exit_transition_state_residual, "Exit transition state residual", transitions[2].state_residual),
        ValidationMetric(:maximum_transition_state_residual, "Maximum transition state residual", max(transitions[1].state_residual, transitions[2].state_residual)))
    isnothing(evidence.endpoint) ? common : (common...,
        ValidationMetric(:terminal_physical_time_residual, "Terminal physical-time residual",
            abs(evidence.endpoint.terminal_physical_time_residual)))
end

function _close_regularized_comparison_metrics(c)
    s = c.samples
    (ValidationMetric(:entry_full_state_difference, "Entry full-state difference", s[1].full_state_difference),
        ValidationMetric(:periapsis_full_state_difference, "Periapsis full-state difference", s[2].full_state_difference),
        ValidationMetric(:exit_full_state_difference, "Exit full-state difference", s[3].full_state_difference),
        ValidationMetric(:final_full_state_difference, "Final full-state difference", s[4].full_state_difference),
        ValidationMetric(:maximum_interval_full_state_difference, "Maximum interval full-state difference", c.maximum_full_state_difference))
end

function _close_regularized_combined_execution(direct, performance)
    if direct.actual != actual_completed
        summary = direct.summary
        if performance.actual != actual_completed && !isnothing(performance.summary)
            summary = isnothing(summary) ? "Performance execution: $(performance.summary)" :
                "Direct execution: $summary; performance execution: $(performance.summary)"
        end
        return ExecutionOutcome(direct.actual; exit_code=direct.exit_code,
            elapsed_seconds=direct.elapsed_seconds, summary)
    elseif performance.actual != actual_completed
        return performance
    end
    ExecutionOutcome(actual_completed; exit_code=0)
end

function _close_regularized_paired_direct_execution(attempt, method)
    method in (:automatic, :explicit) || throw(ArgumentError("Unsupported paired method."))
    selected = method == :automatic ? attempt.automatic_execution : attempt.explicit_execution
    corresponding = method == :automatic ? attempt.explicit_execution : attempt.automatic_execution
    selected.actual != actual_completed && return selected
    corresponding.actual != actual_completed && return ExecutionOutcome(corresponding.actual;
        exit_code=corresponding.exit_code, elapsed_seconds=corresponding.elapsed_seconds,
        summary=corresponding.summary)
    complete_methods = !isnothing(attempt.automatic_evidence) &&
        !isnothing(attempt.automatic_evidence.endpoint) &&
        !isnothing(attempt.explicit_evidence) && !isnothing(attempt.explicit_evidence.endpoint)
    complete_methods || return ExecutionOutcome(actual_errored;
        summary="Paired method evidence is incomplete.")
    if isnothing(attempt.comparison)
        return ExecutionOutcome(actual_errored; summary=attempt.comparison_failure)
    elseif isnothing(attempt.matched_endpoints)
        return ExecutionOutcome(actual_errored; summary=attempt.comparison_failure)
    end
    ExecutionOutcome(actual_completed; exit_code=0)
end

function _close_regularized_suite_reports(suite)
    expected = Tuple(close_encounter_regularized_performance_benchmark_id(method, tolerance)
        for method in (:automatic, :explicit) for tolerance in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    ids = Tuple(report.definition.benchmark_id for report in suite.benchmarks)
    ids == expected || throw(ArgumentError("Performance reports are missing, extra, duplicated, or reordered."))
    reports = Dict{Symbol,PerformanceBenchmarkReport}()
    for report in suite.benchmarks
        decoded = decode_close_encounter_regularized_benchmark_id(report.definition.benchmark_id)
        expected_definition = close_encounter_regularized_performance_definition(decoded.method, decoded.configuration)
        _record_fields_equal(report.definition, expected_definition) || throw(ArgumentError("Performance definition differs."))
        _record_fields_equal(report.configuration,
            _close_regularized_validation_configuration(decoded.configuration, decoded.method)) ||
            throw(ArgumentError("Performance configuration differs."))
        _record_fields_equal(report.policy, StandardBenchmark()) || throw(ArgumentError("Performance policy differs."))
        _record_fields_equal(report.environment, suite.environment) || throw(ArgumentError("Performance environment differs."))
        reports[report.definition.benchmark_id] = report
    end
    reports
end

function close_encounter_regularized_investigation_series(suite::PerformanceSuiteReport, attempts)
    ordered = Tuple(attempts)
    length(ordered) == 4 || throw(ArgumentError("Exactly four matched attempts are required."))
    map(x -> x.configuration.regularized_relative_tolerance, ordered) == CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES ||
        throw(ArgumentError("Matched tolerance attempts are reordered."))
    all(attempt -> attempt.reference === first(ordered).reference, ordered) ||
        throw(ArgumentError("All matched attempts must reuse one reference execution."))
    reports = _close_regularized_suite_reports(suite)
    function make_series(method)
        definition = close_encounter_regularized_investigation_definition(method)
        points = map(ordered) do attempt
            evidence = method == :automatic ? attempt.automatic_evidence : attempt.explicit_evidence
            partial = method == :automatic ? attempt.automatic_partial : attempt.explicit_partial
            direct = _close_regularized_paired_direct_execution(attempt, method)
            id = close_encounter_regularized_performance_benchmark_id(method,
                attempt.configuration.regularized_relative_tolerance)
            haskey(reports, id) || throw(ArgumentError("Missing performance report $id."))
            performance = reports[id]
            execution = _close_regularized_combined_execution(direct, performance.execution)
            propagation = isnothing(evidence) ? partial : evidence.propagation
            metrics = if isnothing(evidence)
                ()
            elseif isnothing(attempt.comparison)
                _close_regularized_method_metrics(evidence)
            else
                (_close_regularized_method_metrics(evidence)...,
                    _close_regularized_comparison_metrics(attempt.comparison)...)
            end
            statistics = isnothing(propagation) ? nothing : SolverStatistics(
                accepted_steps=propagation.work.accepted_steps,
                rejected_steps=propagation.work.rejected_steps,
                rhs_evaluations=propagation.work.rhs_evaluations,
                saved_states=propagation.work.saved_states,
                segment_count=propagation.segment_count,
                switch_count=propagation.switch_count)
            stage = !isnothing(evidence) && !isnothing(attempt.comparison) && !isnothing(attempt.matched_endpoints) ?
                :complete : !isnothing(evidence) && !isnothing(attempt.comparison) ?
                :comparison : !isnothing(evidence) ? :measurement : :propagation
            supporting_summary = stage == :complete ? nothing :
                (!isnothing(attempt.comparison_failure) ? attempt.comparison_failure : direct.summary)
            supporting = isnothing(propagation) ? nothing : CloseEncounterRegularizedSupportingEvidence(
                method, evidence, partial, attempt.comparison, attempt.matched_endpoints,
                stage; summary=supporting_summary)
            InvestigationMeasurementPoint(Symbol(:regularized_tolerance_,
                _close_regularized_token(attempt.configuration.regularized_relative_tolerance)),
                definition, _close_regularized_validation_configuration(attempt.configuration, method),
                ValidationParameter(:regularized_tolerance, attempt.configuration.regularized_relative_tolerance),
                suite.environment, execution, metrics,
                statistics; performance_report=performance, supporting_evidence=supporting,
                notes=execution.actual == actual_completed ? nothing : execution.summary)
        end
        InvestigationMeasurementSeries(definition.family_id, definition.title,
            definition.description, definition, Tuple(points))
    end
    (automatic=make_series(:automatic), explicit=make_series(:explicit))
end
