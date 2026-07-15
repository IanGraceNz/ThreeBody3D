module ThreeBody3D

using LinearAlgebra
using StaticArrays
using OrdinaryDiffEq
using SciMLBase

include("Types.jl")
include("StateVector.jl")
include("Regularization/Regularization.jl")
include("Physics.jl")
include("Integrator.jl")
include("Diagnostics.jl")
include("Validation.jl")
include("Visualization.jl")

export ThreeBodySystem,
       STATE_SIZE, statevector, body_position, velocity,
       PairCoordinates, to_pair_coordinates, from_pair_coordinates,
       LeviCivitaCoordinates, levi_civita_position,
       levi_civita_velocity, to_levi_civita, from_levi_civita,
       LeviCivitaOscillator, LeviCivitaFictitiousResult,
       levi_civita_fictitious_state, levi_civita_cartesian_state,
       integrate_levi_civita_fictitious,
       LeviCivitaSundmanResult, levi_civita_physical_time,
       levi_civita_fictitious_time, levi_civita_state_at_time,
       levi_civita_sundman_state, integrate_levi_civita_sundman,
       KeplerReference, kepler_state, kepler_specific_energy,
       kepler_angular_momentum, radial_free_fall_time,
       radial_free_fall_state,
       AccuracyProfile, accuracy_profile,
       CloseApproachEvent, SimulationResult, simulate,
       terminated_by_close_approach,
       center_of_mass, center_of_mass_velocity,
       linear_momentum, angular_momentum,
       kinetic_energy, potential_energy, total_energy,
       minimum_separation, relative_energy_error,
       DiagnosticsReport, diagnostics_report,
       periodicity_error, CloseApproachReport, close_approach_report,
       SolverBenchmark, benchmark_solvers, benchmark_extreme_solvers,
       plot_trajectory, animate, record_animation

end
