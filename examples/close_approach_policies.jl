using ThreeBody3D

system = ThreeBodySystem((1.0, 1.0, 1.0))
u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [0.0, 0.0, 0.0],                [-0.93240737, -0.86473146, 0.0],
)

threshold = 0.8

recorded = simulate(
    system, u0, (0.0, 4.0);
    solver=:accurate,
    saveat=1.0,
    close_approach_threshold=threshold,
    close_approach_policy=:ignore,
)

println("Recorded events:")
foreach(println, recorded.close_approach_events)
println("Terminated: ", terminated_by_close_approach(recorded))

stopped = simulate(
    system, u0, (0.0, 4.0);
    solver=:accurate,
    saveat=1.0,
    close_approach_threshold=threshold,
    close_approach_policy=:terminate,
)

println("\nTermination event:")
foreach(println, stopped.close_approach_events)
println("Terminated: ", terminated_by_close_approach(stopped))
println("Final integration time: ", last(stopped.solution.t))
