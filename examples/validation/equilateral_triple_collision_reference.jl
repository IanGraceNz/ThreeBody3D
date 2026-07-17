using ThreeBody3D
using LinearAlgebra

# RESEARCH VALIDATION REFERENCE — NOT A SOLVER CAPABILITY EXAMPLE
#
# ThreeBody3D does not currently regularize or numerically continue through a
# simultaneous triple collision. The numerical branch below stops before the
# singularity. The outbound branch and full-cycle animation are analytic,
# time-symmetric reference constructions intended for validation and future
# triple-collision research.

# Equal point masses released from rest at the vertices of an equilateral
# triangle undergo a homothetic collapse: the triangle remains equilateral and
# shrinks to a simultaneous triple collision in finite physical time.
#
# Important limitation: an exact Newtonian point-mass triple collision is a
# singular state with unbounded physical velocities. ThreeBody3D's current
# Levi-Civita implementation regularizes one isolated binary pair; it does not
# regularize a simultaneous triple collision. Consequently this example:
#
#   1. integrates the physical equations only to a small pre-collision
#      separation and compares that result with the analytic homothetic motion;
#   2. constructs the conventional time-symmetric collision-ejection reference
#      solution analytically, through one return to the starting positions and
#      slightly into the next inward leg.
#
# The analytic post-collision branch is a chosen symmetric continuation, not a
# numerical claim that the current solver propagated through the singularity.

const G = 1.0
const MASS = 1.0
const SIDE_LENGTH = 1.0
const CLOSE_APPROACH_THRESHOLD = 1.0e-5
const VALIDATION_MINIMUM_SEPARATION = 1.0e-3

system = ThreeBodySystem((MASS, MASS, MASS); G=G)

# Centred equilateral triangle of side SIDE_LENGTH.
circumradius = SIDE_LENGTH / sqrt(3.0)
initial_positions = (
    [0.0, circumradius, 0.0],
    [-SIDE_LENGTH / 2, -circumradius / 2, 0.0],
    [SIDE_LENGTH / 2, -circumradius / 2, 0.0],
)
zero_velocity = zeros(3)

u0 = statevector(
    initial_positions[1], zero_velocity,
    initial_positions[2], zero_velocity,
    initial_positions[3], zero_velocity,
)

# Each body follows a one-dimensional radial free fall toward the centre with
# effective gravitational parameter G*m/sqrt(3).
effective_mu = G * MASS / sqrt(3.0)
collision_time = radial_free_fall_time(effective_mu, circumradius)
return_time = 2collision_time
final_time = return_time + 0.05collision_time

"""Analytic homothetic state away from the singular collision instant."""
function homothetic_collision_ejection_state(t::Real)
    0.0 <= t <= final_time || throw(ArgumentError("t must lie in [0, final_time]."))

    # Fold successive collision-ejection cycles onto the first cycle.
    phase = mod(float(t), return_time)
    inbound = phase < collision_time
    radial_time = inbound ? phase : return_time - phase

    # The exact collision has zero radius and infinite physical speed, so no
    # finite Cartesian state exists at that instant.
    isapprox(radial_time, collision_time; atol=16eps(collision_time), rtol=0.0) &&
        throw(DomainError(t, "The exact triple-collision state has unbounded physical velocities."))

    reference_position, reference_velocity = radial_free_fall_state(
        effective_mu,
        initial_positions[1],
        radial_time,
    )

    scale = norm(reference_position) / circumradius
    scale_rate = dot(initial_positions[1], reference_velocity) / circumradius^2
    inbound || (scale_rate = -scale_rate)

    statevector(
        scale .* initial_positions[1], scale_rate .* initial_positions[1],
        scale .* initial_positions[2], scale_rate .* initial_positions[2],
        scale .* initial_positions[3], scale_rate .* initial_positions[3],
    )
end

# Stop the ordinary Cartesian integration before the singularity. Continuous
# event location makes the stopping time independent of saveat.
numerical = simulate(
    system,
    u0,
    (0.0, collision_time);
    solver=:accurate,
    reltol=1e-13,
    abstol=1e-13,
    saveat=collision_time / 500,
    close_approach_threshold=CLOSE_APPROACH_THRESHOLD,
    close_approach_policy=:terminate,
)

terminated_by_close_approach(numerical) ||
    error("The numerical integration did not stop at the requested close-approach threshold.")

event = only(numerical.close_approach_events)

# Absolute velocity error at the final event is not a useful validation metric:
# the exact Newtonian velocity diverges as the collision is approached. Instead,
# evaluate dimensionless errors only while every pair remains safely above a
# declared validation separation. Fixed characteristic scales also avoid a
# singular relative error at the zero-velocity initial state.
position_scale = circumradius
velocity_scale = sqrt(effective_mu / circumradius)
validation_indices = findall(eachindex(numerical.solution.t)) do index
    minimum(pair_separations(numerical.solution.u[index])) >= VALIDATION_MINIMUM_SEPARATION
end
isempty(validation_indices) && error("No saved states satisfy the validation separation cutoff.")

function maximum_scaled_state_errors(
    numerical,
    validation_indices,
    position_scale,
    velocity_scale,
)
    maximum_scaled_position_error = 0.0
    maximum_scaled_velocity_error = 0.0

    for index in validation_indices
        t = numerical.solution.t[index]
        numerical_state = numerical.solution.u[index]
        reference_state = homothetic_collision_ejection_state(t)

        for body in 1:3
            position_error = norm(
                body_position(numerical_state, body) - body_position(reference_state, body),
            ) / position_scale
            velocity_error = norm(
                velocity(numerical_state, body) - velocity(reference_state, body),
            ) / velocity_scale

            maximum_scaled_position_error = max(maximum_scaled_position_error, position_error)
            maximum_scaled_velocity_error = max(maximum_scaled_velocity_error, velocity_error)
        end
    end

    maximum_scaled_position_error, maximum_scaled_velocity_error
end

maximum_scaled_position_error, maximum_scaled_velocity_error = maximum_scaled_state_errors(
    numerical,
    validation_indices,
    position_scale,
    velocity_scale,
)

println("Equilateral triple-collision research validation reference")
println("  masses:                         ", system.masses)
println("  initial side length:            ", SIDE_LENGTH)
println("  initial velocities:             all zero")
println("  analytic collision time:        ", collision_time)
println("  analytic return time:           ", return_time)
println("  requested final time:           ", final_time)
println("  numerical stop time:            ", event.time)
println("  numerical stop separation:      ", event.separation)
println("  validation separation cutoff:   ", VALIDATION_MINIMUM_SEPARATION)
println("  validated saved states:          ", length(validation_indices))
println("  maximum scaled position error:   ", maximum_scaled_position_error)
println("  maximum scaled velocity error:   ", maximum_scaled_velocity_error)
println()

# Demonstrate the requested full physical-time interval without evaluating the
# singular instant itself.
offset = collision_time * 1.0e-6
check_times = (
    0.0,
    collision_time - offset,
    collision_time + offset,
    return_time,
    final_time,
)

println("Analytic symmetric continuation")
for t in check_times
    state = homothetic_collision_ejection_state(t)
    separations = pair_separations(state)
    radial_motion = dot(body_position(state, 1), velocity(state, 1))
    direction = radial_motion < 0 ? "inward" : radial_motion > 0 ? "outward" : "stationary"
    println(
        "  t=", t,
        ": side length=", first(separations),
        ", motion=", direction,
    )
end

println()
println("At t = collision_time all three positions coincide and physical velocities diverge.")
println("The outbound branch shown above is the conventional time-symmetric analytic continuation.")

# The numerical SimulationResult ends before the singularity, so animate(numerical)
# correctly shows only the inbound collapse. Use this function to animate the
# analytic time-symmetric collision-ejection reference over the full requested
# physical-time interval.
using GLMakie

"""
    animate_collision_ejection_reference(; fps=30, duration=12, markersize=18,
                                           bodycolors=(:red, :green, :blue),
                                           margin=0.05)

Animate the analytic equilateral collision-ejection continuation from `t = 0`
through return to the starting triangle and slightly into the next collapse.
`duration` is playback duration in seconds; the title displays physical time.

At the exact collision frame the three positions are set to the common centre.
No finite physical velocity is assigned or implied there.
"""
function animate_collision_ejection_reference(
    ;
    fps::Integer=30,
    duration::Real=12,
    markersize::Real=18,
    bodycolors=(:red, :green, :blue),
    margin::Real=0.05,
)
    fps > 0 || throw(ArgumentError("fps must be positive."))
    duration > 0 || throw(ArgumentError("duration must be positive."))
    markersize > 0 || throw(ArgumentError("markersize must be positive."))
    length(bodycolors) == 3 ||
        throw(ArgumentError("bodycolors must contain three colors."))
    0 <= margin < 1 || throw(ArgumentError("margin must lie in [0, 1)."))

    nframes = max(2, round(Int, fps * duration))
    times = collect(range(0.0, final_time; length=nframes))
    points = ntuple(_ -> Vector{Point3f}(undef, nframes), 3)

    for (k, t) in pairs(times)
        phase = mod(t, return_time)
        radial_time = phase <= collision_time ? phase : return_time - phase

        # Position remains finite at collision even though physical velocity
        # diverges. Set the homothetic scale exactly to zero at that instant.
        scale = if isapprox(
            radial_time,
            collision_time;
            atol=32eps(collision_time),
            rtol=0.0,
        )
            0.0
        else
            reference_position, _ = radial_free_fall_state(
                effective_mu,
                initial_positions[1],
                radial_time,
            )
            norm(reference_position) / circumradius
        end

        for body in 1:3
            r = scale .* initial_positions[body]
            points[body][k] = Point3f(Float32(r[1]), Float32(r[2]), Float32(r[3]))
        end
    end

    pad = margin * SIDE_LENGTH
    half_width = SIDE_LENGTH / 2 + pad
    vertical_half_width = circumradius + pad

    fig = Figure(size=(1000, 800))
    frame = Observable(1)
    title = @lift(
        "Analytic triple-collision reference — physical time = " *
        string(round(times[$frame]; digits=6)),
    )
    ax = Axis3(
        fig[1, 1];
        xlabel="x",
        ylabel="y",
        zlabel="z",
        aspect=:data,
        title=title,
    )
    xlims!(ax, -half_width, half_width)
    ylims!(ax, -vertical_half_width, vertical_half_width)
    zlims!(ax, -pad, pad)

    for body in 1:3
        trail = @lift(points[body][1:$frame])
        marker = @lift([points[body][$frame]])
        lines!(ax, trail; color=bodycolors[body])
        scatter!(ax, marker; color=bodycolors[body], markersize=markersize)
    end

    display(fig)
    for k in eachindex(times)
        frame[] = k
        sleep(1 / fps)
    end
    fig
end

println()
println("For the full collision-ejection animation, run:")
println("  animate_collision_ejection_reference()")
