using ThreeBody3D

# A close inner binary orbited by a lighter third body. Dimensionless units.
system = ThreeBodySystem((1.0, 0.8, 0.2))
u0 = statevector(
    [-0.4, 0.0, 0.0], [0.0, -0.65, 0.05],
    [ 0.5, 0.0, 0.0], [0.0,  0.81, -0.0625],
    [ 0.0, 4.0, 0.5], [-0.34, 0.0, 0.0],
)

result = simulate(system, u0, (0.0, 25.0); saveat=0.02,
                  reltol=1e-13, abstol=1e-13)
report = diagnostics_report(result)
println(report)

show_plot = lowercase(get(ENV, "THREEBODY3D_SHOW_PLOTS", "true")) == "true"
figure = plot_trajectory(result; show=show_plot)
println("Trajectory figure: ", typeof(figure))
# record_animation(result, joinpath(@__DIR__, "hierarchical_triple.mp4"); duration=15)
