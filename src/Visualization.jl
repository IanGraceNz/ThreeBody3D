using GLMakie

function _sample_solution(result::SimulationResult, nframes::Integer)
    nframes >= 2 || throw(ArgumentError("nframes must be at least 2."))
    sol = result.solution
    times = collect(range(first(sol.t), last(sol.t); length=nframes))
    points = ntuple(_ -> Vector{Point3f}(undef, nframes), 3)
    for k in eachindex(times)
        u = sol(times[k])
        for i in 1:3
            r = body_position(u, i)
            points[i][k] = Point3f(Float32(r[1]), Float32(r[2]), Float32(r[3]))
        end
    end
    times, points
end

function _sample_solution(trajectory::ExperimentalSwitchingTrajectory, nframes::Integer)
    nframes >= 2 || throw(ArgumentError("nframes must be at least 2."))
    trajectory.final_time > first(trajectory.tspan) ||
        throw(ArgumentError("trajectory must span a positive physical-time interval."))
    times = collect(range(first(trajectory.tspan), trajectory.final_time; length=nframes))
    samples = sample_experimental_switching(trajectory, times; include_switches=false)
    points = ntuple(_ -> Vector{Point3f}(undef, length(samples)), 3)
    for k in eachindex(samples)
        u = samples[k]
        for i in 1:3
            r = body_position(u, i)
            points[i][k] = Point3f(Float32(r[1]), Float32(r[2]), Float32(r[3]))
        end
    end
    samples.times, points
end

function _axis_limits(pointsets; margin::Real=0.05)
    0 <= margin < 1 || throw(ArgumentError("margin must be in [0, 1)."))
    allpoints = Iterators.flatten(pointsets)
    xs = Float64[]; ys = Float64[]; zs = Float64[]
    for p in allpoints
        push!(xs, p[1]); push!(ys, p[2]); push!(zs, p[3])
    end
    function padded(v)
        lo, hi = extrema(v)
        span = hi-lo
        if iszero(span)
            scale = max(abs(lo), 1.0)
            span = 2sqrt(eps(Float64))*scale
        end
        pad = margin*span
        (lo-pad, hi+pad)
    end
    padded(xs), padded(ys), padded(zs)
end

function _validate_visual_options(fps, duration, markersize, bodycolors, margin)
    fps > 0 || throw(ArgumentError("fps must be positive."))
    duration > 0 || throw(ArgumentError("duration must be positive."))
    markersize > 0 || throw(ArgumentError("markersize must be positive."))
    length(bodycolors) == 3 || throw(ArgumentError("bodycolors must contain three colors."))
    0 <= margin < 1 || throw(ArgumentError("margin must be in [0, 1)."))
end

"""
    plot_trajectory(result; bodycolors=(:red,:green,:blue), margin=0.05,
                    show=true, npoints=nothing)

Create a 3D trajectory plot for a Cartesian [`SimulationResult`](@ref) or an
[`ExperimentalSwitchingTrajectory`](@ref). Hybrid trajectories are sampled in
physical time and rendered as one continuous path. Set `show=false` for tests
or headless workflows. Returns a Makie `Figure`.
"""
function plot_trajectory(result::Union{SimulationResult,ExperimentalSwitchingTrajectory};
                         bodycolors=(:red,:green,:blue), margin::Real=0.05,
                         show::Bool=true, npoints::Union{Nothing,Integer}=nothing)
    length(bodycolors) == 3 || throw(ArgumentError("bodycolors must contain three colors."))
    default_npoints = result isa SimulationResult ? length(result.solution.t) : max(200, 50 * length(result.segments))
    sample_count = isnothing(npoints) ? max(2, default_npoints) : npoints
    sample_count >= 2 || throw(ArgumentError("npoints must be at least 2."))
    _, points = _sample_solution(result, sample_count)
    fig = Figure(size=(900,700))
    ax = Axis3(fig[1,1], xlabel="x", ylabel="y", zlabel="z", aspect=:data)
    for i in 1:3
        lines!(ax, points[i], color=bodycolors[i])
        scatter!(ax, points[i][end:end], color=bodycolors[i], markersize=12)
    end
    xl, yl, zl = _axis_limits(points; margin)
    xlims!(ax, xl...); ylims!(ax, yl...); zlims!(ax, zl...)
    show && display(fig)
    fig
end

function _animation_scene(result; fps, duration, markersize, bodycolors, margin)
    _validate_visual_options(fps, duration, markersize, bodycolors, margin)
    nframes = max(2, round(Int, fps*duration))
    _, points = _sample_solution(result, nframes)
    fig = Figure(size=(1000,800))
    ax = Axis3(fig[1,1], xlabel="x", ylabel="y", zlabel="z", aspect=:data)
    xl, yl, zl = _axis_limits(points; margin)
    xlims!(ax, xl...); ylims!(ax, yl...); zlims!(ax, zl...)
    index = Observable(1)
    for i in 1:3
        trail = @lift(points[i][1:$index])
        marker = @lift([points[i][$index]])
        lines!(ax, trail, color=bodycolors[i])
        scatter!(ax, marker, color=bodycolors[i], markersize=markersize)
    end
    fig, index, nframes
end

"""
    animate(result; fps=30, duration=10, markersize=18,
            bodycolors=(:red,:green,:blue), margin=0.05)

Display an interactive real-time animation compressed into `duration` seconds.
The simulation's physical time span does not determine playback duration.
Returns the Makie `Figure` after playback.
"""
function animate(result::SimulationResult; fps::Integer=30, duration::Real=10,
                 markersize::Real=18, bodycolors=(:red,:green,:blue),
                 margin::Real=0.05)
    fig, index, nframes = _animation_scene(result; fps, duration, markersize,
                                            bodycolors, margin)
    display(fig)
    for k in 1:nframes
        index[] = k
        sleep(1/fps)
    end
    fig
end

"""
    record_animation(result, filename; fps=30, duration=10, markersize=18,
                     bodycolors=(:red,:green,:blue), margin=0.05)

Record an MP4 animation and return its absolute path. The output directory must
exist and the filename must end in `.mp4`.
"""
function record_animation(result::SimulationResult, filename::AbstractString;
                          fps::Integer=30, duration::Real=10,
                          markersize::Real=18,
                          bodycolors=(:red,:green,:blue), margin::Real=0.05)
    endswith(lowercase(filename), ".mp4") || throw(ArgumentError("filename must end in .mp4"))
    dir = dirname(abspath(filename))
    isdir(dir) || throw(ArgumentError("Output directory does not exist: $dir"))
    fig, index, nframes = _animation_scene(result; fps, duration, markersize,
                                            bodycolors, margin)
    record(fig, filename, 1:nframes; framerate=fps) do k
        index[] = k
    end
    abspath(filename)
end
