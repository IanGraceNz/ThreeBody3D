using ThreeBody3D

# Stage 9 baseline: extend the established automatic-switching encounter over a
# longer physical interval and measure conservation on a uniform physical-time
# grid. This is a controller hardening benchmark, not yet a difficult physical
# three-body validation case; later Stage 9 increments will add stronger systems.
system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)

u0 = statevector(
    [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
    [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
    [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
)

parameters = AutomaticSwitchingParameters(
    enter_threshold=0.2,
    exit_threshold=0.4,
    ambiguity_threshold=0.3,
    minimum_separation_ratio=2.0,
    maximum_switches=20,
)

trajectory = simulate_experimental_switching(
    system,
    u0,
    (0.0, 20.0),
    parameters;
    cartesian_kwargs=(saveat=0.1,),
    regularized_kwargs=(saveat=0.025,),
)

trajectory.status == :completed || error(
    "Automatic switching ended with status $(trajectory.status): " *
    "$(trajectory.failure)",
)

report = diagnostics_report(trajectory; dt=0.02)
println(report)
