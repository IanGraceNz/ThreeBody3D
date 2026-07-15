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
