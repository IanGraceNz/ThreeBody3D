"""
    cross_validate_ks_levi_civita(μ, q, v, sample_times; initial_time=0)

Cross-check isolated planar Kepler propagation using the existing
Levi–Civita and spatial KS regularizations. Comparisons are performed only in
physical Cartesian variables; no relationship between the internal
regularized coordinates is assumed.

`q` and `v` are two-component planar vectors. `sample_times` contains physical
times. The returned named tuple contains per-sample reconstructed states and
maximum scale-aware discrepancies in position, velocity, physical time,
specific energy, and endpoint transition data.
"""
function cross_validate_ks_levi_civita(
    μ::Real,
    q::AbstractVector{<:Real},
    v::AbstractVector{<:Real},
    sample_times::AbstractVector{<:Real};
    initial_time::Real=0,
)
    length(q) == 2 || throw(ArgumentError("q must contain two components."))
    length(v) == 2 || throw(ArgumentError("v must contain two components."))
    isempty(sample_times) && throw(ArgumentError("sample_times must not be empty."))

    T = float(promote_type(typeof(μ), eltype(q), eltype(v), eltype(sample_times), typeof(initial_time)))
    μT = T(μ)
    q2 = SVector{2,T}(q)
    v2 = SVector{2,T}(v)
    times = T.(sample_times)
    t0 = T(initial_time)

    isfinite(μT) && μT > zero(T) || throw(ArgumentError("μ must be finite and positive."))
    all(isfinite, q2) || throw(ArgumentError("q must be finite."))
    all(isfinite, v2) || throw(ArgumentError("v must be finite."))
    all(isfinite, times) || throw(ArgumentError("sample_times must be finite."))
    isfinite(t0) || throw(ArgumentError("initial_time must be finite."))
    norm(q2) > zero(T) || throw(DomainError(norm(q2), "Initial position must be non-collisional."))

    lc = LeviCivitaOscillator(μT, q2, v2)
    q3 = SVector{3,T}(q2[1], q2[2], zero(T))
    v3 = SVector{3,T}(v2[1], v2[2], zero(T))
    ks = KSTwoBodyProblem(μT, q3, v3; initial_time=t0)
    initial_specific_energy = dot(v2, v2) / T(2) - μT / norm(q2)

    samples = map(times) do target
        lc_state = levi_civita_state_at_time(lc, target; initial_time=t0)
        sks = ks_fictitious_time(ks, target)
        uks, wks, hks, tks = ks_exact_state(ks, sks)
        qks3 = ks_position(uks)
        vks3 = ks_to_cartesian_velocity(uks, wks)
        qks = SVector{2,T}(qks3[1], qks3[2])
        vks = SVector{2,T}(vks3[1], vks3[2])
        qlc = SVector{2,T}(lc_state.position)
        vlc = SVector{2,T}(lc_state.velocity)
        energy_lc = dot(vlc, vlc) / T(2) - μT / norm(qlc)
        energy_ks = dot(vks, vks) / T(2) - μT / norm(qks)

        position_scale = max(one(T), norm(qlc), norm(qks))
        velocity_scale = max(one(T), norm(vlc), norm(vks))
        time_scale = max(one(T), abs(target), abs(t0))
        energy_scale = max(one(T), abs(initial_specific_energy), abs(energy_lc), abs(energy_ks))

        (
            physical_time=target,
            levi_civita_fictitious_time=lc_state.fictitious_time,
            ks_fictitious_time=sks,
            levi_civita_position=qlc,
            ks_position=qks,
            levi_civita_velocity=vlc,
            ks_velocity=vks,
            ks_reconstructed_time=tks,
            ks_binding_energy=hks,
            position_error=norm(qks - qlc) / position_scale,
            velocity_error=norm(vks - vlc) / velocity_scale,
            time_error=abs(tks - target) / time_scale,
            energy_error=abs(energy_ks - energy_lc) / energy_scale,
            levi_civita_energy_drift=abs(energy_lc - initial_specific_energy) / energy_scale,
            ks_energy_drift=abs(energy_ks - initial_specific_energy) / energy_scale,
        )
    end

    first_sample = first(samples)
    last_sample = last(samples)
    transition_position_error = norm(last_sample.ks_position - last_sample.levi_civita_position) /
        max(one(T), norm(last_sample.ks_position), norm(last_sample.levi_civita_position))
    transition_velocity_error = norm(last_sample.ks_velocity - last_sample.levi_civita_velocity) /
        max(one(T), norm(last_sample.ks_velocity), norm(last_sample.levi_civita_velocity))

    return (
        numeric_type=T,
        gravitational_parameter=μT,
        initial_time=t0,
        initial_position=q2,
        initial_velocity=v2,
        initial_specific_energy=initial_specific_energy,
        samples=samples,
        maximum_position_error=maximum(s.position_error for s in samples),
        maximum_velocity_error=maximum(s.velocity_error for s in samples),
        maximum_time_error=maximum(s.time_error for s in samples),
        maximum_energy_error=maximum(s.energy_error for s in samples),
        maximum_levi_civita_energy_drift=maximum(s.levi_civita_energy_drift for s in samples),
        maximum_ks_energy_drift=maximum(s.ks_energy_drift for s in samples),
        initial_transition_position_error=first_sample.position_error,
        initial_transition_velocity_error=first_sample.velocity_error,
        final_transition_position_error=transition_position_error,
        final_transition_velocity_error=transition_velocity_error,
    )
end
