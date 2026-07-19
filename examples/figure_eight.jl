using ThreeBody3D

# Equal-mass figure-eight orbit in dimensionless units.
system = ThreeBodySystem((1.0, 1.0, 1.0))
u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [0.0, 0.0, 0.0],                [-0.93240737,  -0.86473146, 0.0],
)

result = simulate(system, u0, (0.0, 6.4); saveat=0.01)
println(diagnostics_report(result))
show_plot = lowercase(get(ENV, "THREEBODY3D_SHOW_PLOTS", "true")) == "true"
figure = plot_trajectory(result; show=show_plot)
println("Trajectory figure: ", typeof(figure))

# Uncomment either line for playback or MP4 output.
# animate(result; duration=12)
# record_animation(result, joinpath(@__DIR__, "figure_eight.mp4"); duration=12)
