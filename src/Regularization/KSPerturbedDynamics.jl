"""
    KSPerturbedProblem(μ, q, v, perturbation; reference=nothing, initial_time=0)

Internal initial data for an isolated spatial Kepler pair subject to a smooth
Cartesian perturbing acceleration `perturbation(q, v, t)`. The regularized
state is `(u, w, h, t)` and the callback must return three finite components.
At exact collision, where Cartesian velocity is undefined, the callback receives
`v = nothing`; a force intended to remain regular through collision must handle
that case without reconstructing Cartesian velocity.
"""
struct KSPerturbedProblem{T<:AbstractFloat,F}
    gravitational_parameter::T
    u0::SVector{4,T}
    w0::SVector{4,T}
    binding_energy::T
    initial_time::T
    perturbation::F
end

function KSPerturbedProblem(
    μ::Real,
    q::AbstractVector{<:Real},
    v::AbstractVector{<:Real},
    perturbation;
    reference=nothing,
    initial_time::Real=0,
)
    base = KSTwoBodyProblem(μ, q, v; reference=reference, initial_time=initial_time)
    problem = KSPerturbedProblem(
        base.gravitational_parameter, base.u0, base.w0,
        base.binding_energy, base.initial_time, perturbation,
    )
    _ks_perturbing_acceleration(problem, base.u0, base.w0, base.initial_time)
    problem
end

@inline ks_initial_state(problem::KSPerturbedProblem) =
    ks_pack_state(problem.u0, problem.w0, problem.binding_energy, problem.initial_time)

function _ks_perturbing_acceleration(
    problem::KSPerturbedProblem{T}, u::SVector{4,T}, w::SVector{4,T}, t::T,
) where {T}
    q = ks_position(u)
    rho = dot(u, u)
    v = iszero(rho) ? nothing : ks_to_cartesian_velocity(u, w)
    raw = problem.perturbation(q, v, t)
    raw isa AbstractVector || throw(ArgumentError("perturbation must return a vector."))
    length(raw) == 3 || throw(ArgumentError("perturbation must return three components."))
    f = SVector{3,T}(raw)
    all(isfinite, f) || throw(ArgumentError("perturbation must return finite components."))
    f
end

"""Return the perturbed KS right-hand side for state `(u,w,h,t)`."""
function ks_perturbed_rhs(y::AbstractVector{<:Real}, problem::KSPerturbedProblem{T}) where {T}
    u0, w0, h0, t0 = ks_unpack_state(y)
    u = SVector{4,T}(u0); w = SVector{4,T}(w0); h = T(h0); t = T(t0)
    rho = dot(u, u)
    f = _ks_perturbing_acceleration(problem, u, w, t)
    J = ks_jacobian(u)
    qprime = J * w
    wprime = -(h / T(2)) * u + (rho / T(4)) * (transpose(J) * f)
    hprime = -dot(qprime, f)
    ks_pack_state(w, SVector{4,T}(wprime), hprime, rho)
end

struct KSPerturbedResult{P,S}
    problem::P
    solution::S
end

"""Integrate isolated perturbed KS dynamics over a fictitious-time interval."""
function integrate_ks_perturbed(
    problem::KSPerturbedProblem{T},
    sspan::Tuple{<:Real,<:Real};
    algorithm=Vern9(), reltol=nothing, abstol=nothing, kwargs...
) where {T}
    s0, s1 = T(sspan[1]), T(sspan[2])
    all(isfinite, (s0, s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    s0 != s1 || throw(ArgumentError("sspan endpoints must differ."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt > zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at > zero(T) || throw(ArgumentError("abstol must be finite and positive."))
    rhs(y,p,s) = ks_perturbed_rhs(y, p)
    sol = solve(ODEProblem(rhs, ks_initial_state(problem), (s0,s1), problem), algorithm;
        reltol=rt, abstol=at, kwargs...)
    SciMLBase.successful_retcode(sol) || error("Perturbed KS integration failed with retcode $(sol.retcode).")
    KSPerturbedResult(problem, sol)
end

function ks_state(result::KSPerturbedResult, s::Real)
    ks_unpack_state(result.solution(s))
end

function ks_cartesian_state(result::KSPerturbedResult, s::Real)
    ks_cartesian_state(result.solution(s))
end
