const DEFAULT_RELTOL = 1e-12
const DEFAULT_ABSTOL = 1e-12

"""
    AccuracyProfile

Named integration configuration containing a solver algorithm and default
relative and absolute tolerances. Construct profiles with [`accuracy_profile`](@ref).
"""
struct AccuracyProfile{A,T<:AbstractFloat}
    name::Symbol
    algorithm::A
    reltol::T
    abstol::T
end

"""
    accuracy_profile(name=:accurate)

Return a built-in integration profile:

- `:fast` uses `Tsit5()` with `1e-9` tolerances.
- `:accurate` uses `Vern9()` with `1e-12` tolerances.
- `:extreme` uses `Vern9()` with `1e-13` tolerances.

The profiles are starting points, not universal guarantees. Close encounters
may require stricter tolerances, shorter spans, and eventually regularized
coordinates.
"""
function accuracy_profile(name::Symbol=:accurate)
    name === :fast && return AccuracyProfile(:fast, Tsit5(), 1e-9, 1e-9)
    name === :accurate && return AccuracyProfile(:accurate, Vern9(), 1e-12, 1e-12)
    name === :extreme && return AccuracyProfile(:extreme, Vern9(), 1e-13, 1e-13)
    throw(ArgumentError("Unknown accuracy profile $name. Use :fast, :accurate, or :extreme."))
end

"""
    SimulationResult

Result returned by [`simulate`](@ref). The underlying SciML solution is in
`result.solution`; `result.system` retains the physical model for diagnostics.
"""
struct SimulationResult{S,Y}
    solution::S
    system::Y
end

Base.length(result::SimulationResult) = length(result.solution)
Base.getindex(result::SimulationResult, i) = result.solution[i]
(result::SimulationResult)(t) = result.solution(t)

function make_problem(system::ThreeBodySystem, u0::AbstractVector, tspan::Tuple{<:Real,<:Real})
    validate_state(u0)
    tspan[2] > tspan[1] || throw(ArgumentError("tspan must satisfy t_final > t_initial."))
    T = promote_type(eltype(u0), typeof(system.G), typeof(float(tspan[1])), typeof(float(tspan[2])))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    ODEProblem(threebody!, T.(u0), (T(tspan[1]), T(tspan[2])), converted_system)
end

function _resolve_solver(solver, reltol, abstol)
    if solver isa Symbol
        profile = accuracy_profile(solver)
        resolved_reltol = isnothing(reltol) ? profile.reltol : reltol
        resolved_abstol = isnothing(abstol) ? profile.abstol : abstol
        return profile.algorithm, resolved_reltol, resolved_abstol
    end
    resolved_reltol = isnothing(reltol) ? DEFAULT_RELTOL : reltol
    resolved_abstol = isnothing(abstol) ? DEFAULT_ABSTOL : abstol
    solver, resolved_reltol, resolved_abstol
end

"""
    simulate(system, u0, tspan; solver=:accurate, reltol=nothing,
             abstol=nothing, saveat=nothing, maxiters=10^7, kwargs...)

Integrate the Newtonian three-body equations. `solver` may be one of the
built-in profile names `:fast`, `:accurate`, or `:extreme`, or any compatible
OrdinaryDiffEq algorithm object. Explicit `reltol` and `abstol` values override
the selected profile defaults.

For reliable diagnostics, pass a sufficiently dense `saveat`; diagnostics are
computed from saved states. Exact point-mass collisions remain mathematical
singularities and raise an error rather than being softened. Additional
keywords are forwarded to `OrdinaryDiffEq.solve`.
"""
function simulate(system::ThreeBodySystem, u0::AbstractVector,
                  tspan::Tuple{<:Real,<:Real};
                  solver=:accurate, reltol::Union{Nothing,Real}=nothing,
                  abstol::Union{Nothing,Real}=nothing, saveat=nothing,
                  maxiters::Integer=10^7, kwargs...)
    algorithm, resolved_reltol, resolved_abstol = _resolve_solver(solver, reltol, abstol)
    resolved_reltol > 0 || throw(ArgumentError("reltol must be positive."))
    resolved_abstol > 0 || throw(ArgumentError("abstol must be positive."))
    maxiters > 0 || throw(ArgumentError("maxiters must be positive."))

    problem = make_problem(system, u0, tspan)
    sol = isnothing(saveat) ?
        solve(problem, algorithm; reltol=resolved_reltol, abstol=resolved_abstol,
              maxiters, kwargs...) :
        solve(problem, algorithm; reltol=resolved_reltol, abstol=resolved_abstol,
              saveat, maxiters, kwargs...)
    SciMLBase.successful_retcode(sol) || error("Integration failed with retcode $(sol.retcode).")
    SimulationResult(sol, problem.p)
end
