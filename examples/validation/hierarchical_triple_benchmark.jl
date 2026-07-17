using ThreeBody3D

# Long-duration weakly perturbed hierarchical system. The benchmark tracks the
# ratio of the outer-body distance from the inner-binary centre of mass to the
# instantaneous inner separation. A ratio comfortably above one indicates that
# the system remains hierarchical throughout the integration.
report = run_validation_benchmark(
    :hierarchical_triple;
    duration=100.0,
    solver=:accurate,
    saveat=0.02,
    reltol=1e-13,
    abstol=1e-13,
)
println(report)
