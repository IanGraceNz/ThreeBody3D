using ThreeBody3D

# Stage 9 common-format baseline for the equal-mass figure-eight choreography.
# Increase `periods` to study long-duration phase and conservation behaviour.
report = run_validation_benchmark(
    :figure_eight;
    periods=10,
    solver=:accurate,
    saveat=0.02,
)

println(report)
