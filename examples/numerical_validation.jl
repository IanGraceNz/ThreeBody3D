using ThreeBody3D

# Published equal-mass figure-eight initial conditions in dimensionless units.
const FIGURE_EIGHT_PERIOD = 6.32591398

system = ThreeBodySystem((1.0, 1.0, 1.0))
u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [0.0, 0.0, 0.0],                [-0.93240737, -0.86473146, 0.0],
)

benchmarks = benchmark_solvers(
    system,
    u0,
    (0.0, FIGURE_EIGHT_PERIOD);
    profiles=(:fast, :accurate, :extreme),
    saveat=0.01,
    period=FIGURE_EIGHT_PERIOD,
)

for benchmark in benchmarks
    println("\n", benchmark)
end

result = simulate(system, u0, (0.0, FIGURE_EIGHT_PERIOD);
                  solver=:accurate, saveat=0.005)
println("\n", diagnostics_report(result))
println("Periodicity error: ", periodicity_error(result, FIGURE_EIGHT_PERIOD))
println(close_approach_report(result; threshold=0.7))
