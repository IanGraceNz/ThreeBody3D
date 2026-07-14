using ThreeBody3D

# Construct reference inputs from decimal strings. Converting Float64 values to
# BigFloat later increases arithmetic precision but cannot restore rounded digits.
setprecision(BigFloat, 256) do
    x = parse(BigFloat, "0.97000436")
    y = parse(BigFloat, "0.24308753")
    vx = parse(BigFloat, "0.466203685")
    vy = parse(BigFloat, "0.432365730")
    zero_big = parse(BigFloat, "0")
    one_big = parse(BigFloat, "1")
    period = parse(BigFloat, "6.32591398")

    system = ThreeBodySystem((one_big, one_big, one_big); G=one_big)
    u0 = statevector(
        [-x,  y, zero_big], [ vx,  vy, zero_big],
        [ x, -y, zero_big], [ vx,  vy, zero_big],
        [zero_big, zero_big, zero_big], [-2vx, -2vy, zero_big],
    )

    println("Candidate BigFloat reference solvers:")
    benchmarks = benchmark_extreme_solvers(
        system, u0, (zero_big, period);
        precision=256,
        reltol="1e-30",
        abstol="1e-30",
        saveat=period / 100,
        period=period,
    )
    foreach(benchmark -> println(benchmark, '\n'), benchmarks)

    reference = simulate(
        system, u0, (zero_big, period);
        solver=:extreme,
        precision=256,
        saveat=period / 100,
    )
    println(diagnostics_report(reference))
end
