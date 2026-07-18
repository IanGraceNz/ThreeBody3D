"""
    KSTwoBodyProblem

Internal initial data for an isolated spatial Kepler pair in KS coordinates.
The fictitious-time state is `(u, w, h, t)`, where `h` is the positive
binding-energy parameter `μ/r - |v|²/2` and `dt/ds = |u|²`.
"""
struct KSTwoBodyProblem{T<:AbstractFloat}
    gravitational_parameter::T
    u0::SVector{4,T}
    w0::SVector{4,T}
    binding_energy::T
    initial_time::T

    function KSTwoBodyProblem{T}(
        gravitational_parameter::T,
        u0::SVector{4,T},
        w0::SVector{4,T},
        binding_energy::T,
        initial_time::T,
    ) where {T<:AbstractFloat}
        isfinite(gravitational_parameter) && gravitational_parameter > zero(T) ||
            throw(ArgumentError("gravitational_parameter must be finite and positive."))
        all(isfinite, u0) || throw(ArgumentError("u0 must be finite."))
        all(isfinite, w0) || throw(ArgumentError("w0 must be finite."))
        isfinite(binding_energy) || throw(ArgumentError("binding_energy must be finite."))
        isfinite(initial_time) || throw(ArgumentError("initial_time must be finite."))
        new{T}(gravitational_parameter, u0, w0, binding_energy, initial_time)
    end
end

"""
    KSTwoBodyProblem(μ, q, v; reference=nothing, initial_time=0)

Construct isolated unperturbed KS initial data from a non-collisional Cartesian
relative position and physical velocity.
"""
function KSTwoBodyProblem(
    μ::Real,
    q::AbstractVector{<:Real},
    v::AbstractVector{<:Real};
    reference=nothing,
    initial_time::Real=0,
)
    length(q) == 3 || throw(ArgumentError("q must contain three components."))
    length(v) == 3 || throw(ArgumentError("v must contain three components."))
    reference === nothing || length(reference) == 4 ||
        throw(ArgumentError("reference must contain four components."))
    T = float(promote_type(typeof(μ), eltype(q), eltype(v), typeof(initial_time),
        reference === nothing ? Float16 : eltype(reference)))
    μT = T(μ)
    qT = SVector{3,T}(q)
    vT = SVector{3,T}(v)
    t0 = T(initial_time)
    isfinite(μT) && μT > zero(T) || throw(ArgumentError("μ must be finite and positive."))
    all(isfinite, qT) || throw(ArgumentError("q must be finite."))
    all(isfinite, vT) || throw(ArgumentError("v must be finite."))
    isfinite(t0) || throw(ArgumentError("initial_time must be finite."))
    refT = reference === nothing ? nothing : SVector{4,T}(reference)
    refT === nothing || all(isfinite, refT) || throw(ArgumentError("reference must be finite."))

    u, w = cartesian_to_ks_state(qT, vT; reference=refT)
    radius = norm(qT)
    h = μT / radius - dot(vT, vT) / T(2)
    KSTwoBodyProblem{T}(μT, u, w, h, t0)
end

@inline function ks_pack_state(
    u::SVector{4,T},
    w::SVector{4,T},
    h::Real,
    t::Real,
) where {T<:Real}
    R = float(promote_type(T, typeof(h), typeof(t)))
    uR = SVector{4,R}(u)
    wR = SVector{4,R}(w)
    hR = R(h)
    tR = R(t)
    all(isfinite, uR) && all(isfinite, wR) && isfinite(hR) && isfinite(tR) ||
        throw(ArgumentError("KS state components must be finite."))
    SVector{10,R}(uR[1], uR[2], uR[3], uR[4],
        wR[1], wR[2], wR[3], wR[4], hR, tR)
end

function ks_pack_state(u::AbstractVector{<:Real}, w::AbstractVector{<:Real}, h::Real, t::Real)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    T = float(promote_type(eltype(u), eltype(w), typeof(h), typeof(t)))
    uT = SVector{4,T}(u); wT = SVector{4,T}(w); hT = T(h); tT = T(t)
    all(isfinite, uT) && all(isfinite, wT) && isfinite(hT) && isfinite(tT) ||
        throw(ArgumentError("KS state components must be finite."))
    ks_pack_state(uT, wT, hT, tT)
end

function ks_unpack_state(y::AbstractVector{<:Real})
    length(y) == 10 || throw(ArgumentError("KS state must contain ten components."))
    all(isfinite, y) || throw(ArgumentError("KS state must be finite."))
    T = eltype(y)
    return SVector{4,T}(y[1:4]), SVector{4,T}(y[5:8]), y[9], y[10]
end

"""Return the unperturbed KS right-hand side for state `(u,w,h,t)`."""
function ks_unperturbed_rhs(y::AbstractVector{<:Real})
    u, w, h, _ = ks_unpack_state(y)
    T = eltype(y)
    acceleration = -(h / T(2)) * u
    ks_pack_state(w, acceleration, zero(T), dot(u, u))
end

@inline ks_initial_state(problem::KSTwoBodyProblem{T}) where {T} =
    ks_pack_state(problem.u0, problem.w0, problem.binding_energy, problem.initial_time)

function _ks_exact_uw(problem::KSTwoBodyProblem{T}, s::T) where {T}
    h = problem.binding_energy
    u0, w0 = problem.u0, problem.w0
    if h > zero(T)
        omega = sqrt(h / T(2)); theta = omega * s
        c, sn = cos(theta), sin(theta)
        return c*u0 + (sn/omega)*w0, (-omega*sn)*u0 + c*w0
    elseif h < zero(T)
        kappa = sqrt(-h / T(2)); theta = kappa * s
        c, sh = cosh(theta), sinh(theta)
        return c*u0 + (sh/kappa)*w0, (kappa*sh)*u0 + c*w0
    else
        return u0 + s*w0, w0
    end
end

function _ks_elapsed_time(problem::KSTwoBodyProblem{T}, s::T) where {T}
    h = problem.binding_energy
    A = dot(problem.u0, problem.u0)
    B = dot(problem.u0, problem.w0)
    C = dot(problem.w0, problem.w0)
    if h > zero(T)
        omega = sqrt(h / T(2)); theta = omega*s
        icc = s/T(2) + sin(T(2)*theta)/(T(4)*omega)
        iss = s/T(2) - sin(T(2)*theta)/(T(4)*omega)
        ics = sin(theta)^2/(T(2)*omega)
        return A*icc + (T(2)*B/omega)*ics + (C/omega^2)*iss
    elseif h < zero(T)
        kappa = sqrt(-h / T(2)); theta = kappa*s
        icc = s/T(2) + sinh(T(2)*theta)/(T(4)*kappa)
        iss = -s/T(2) + sinh(T(2)*theta)/(T(4)*kappa)
        ics = sinh(theta)^2/(T(2)*kappa)
        return A*icc + (T(2)*B/kappa)*ics + (C/kappa^2)*iss
    else
        return A*s + B*s^2 + C*s^3/T(3)
    end
end

"""Return exact unperturbed KS state `(u,w,h,t)` at fictitious time `s`."""
function ks_exact_state(problem::KSTwoBodyProblem{T}, s::Real) where {T}
    sT = T(s); isfinite(sT) || throw(ArgumentError("s must be finite."))
    u, w = _ks_exact_uw(problem, sT)
    return u, w, problem.binding_energy, problem.initial_time + _ks_elapsed_time(problem, sT)
end

"""Reconstruct Cartesian relative `(q,v,t)` from a finite noncollision KS state."""
function ks_cartesian_state(y::AbstractVector{<:Real})
    u, w, _, t = ks_unpack_state(y)
    return ks_position(u), ks_to_cartesian_velocity(u, w), t
end

struct KSTwoBodyResult{P,S}
    problem::P
    solution::S
end

"""Numerically integrate isolated unperturbed KS dynamics over fictitious time."""
function integrate_ks_two_body(
    problem::KSTwoBodyProblem{T},
    sspan::Tuple{<:Real,<:Real};
    algorithm=Vern9(), reltol=nothing, abstol=nothing, kwargs...
) where {T}
    s0, s1 = T(sspan[1]), T(sspan[2])
    all(isfinite, (s0,s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    s0 != s1 || throw(ArgumentError("sspan endpoints must differ."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt > zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at > zero(T) || throw(ArgumentError("abstol must be finite and positive."))
    rhs(y,p,s) = ks_unperturbed_rhs(y)
    sol = solve(ODEProblem(rhs, ks_initial_state(problem), (s0,s1)), algorithm;
        reltol=rt, abstol=at, kwargs...)
    SciMLBase.successful_retcode(sol) || error("KS two-body integration failed with retcode $(sol.retcode).")
    KSTwoBodyResult(problem, sol)
end

function ks_state(result::KSTwoBodyResult, s::Real)
    y = result.solution(s)
    ks_unpack_state(y)
end

function ks_cartesian_state(result::KSTwoBodyResult, s::Real)
    y = result.solution(s)
    ks_cartesian_state(y)
end

"""Locate fictitious time corresponding to a target physical time by monotone bisection."""
function ks_fictitious_time(problem::KSTwoBodyProblem{T}, target_time::Real;
    tolerance=nothing, initial_step::Real=one(T), max_iterations::Integer=256) where {T}
    target = T(target_time); step0 = T(initial_step)
    isfinite(target) && isfinite(step0) || throw(ArgumentError("target_time and initial_step must be finite."))
    step0 > zero(T) || throw(ArgumentError("initial_step must be positive."))
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    delta = target - problem.initial_time
    iszero(delta) && return zero(T)
    tol = isnothing(tolerance) ? T(64)*eps(T)*max(one(T),abs(target),abs(problem.initial_time)) : T(tolerance)
    isfinite(tol) && tol > zero(T) || throw(ArgumentError("tolerance must be finite and positive."))
    direction = sign(delta)
    f(s) = problem.initial_time + _ks_elapsed_time(problem,s) - target
    a = zero(T); fa = -delta; b = direction*step0; fb = f(b)
    n = 0
    while signbit(fa) == signbit(fb) && !iszero(fb)
        n += 1; n <= max_iterations || error("Fictitious-time bracket did not reach target_time.")
        b *= T(2); isfinite(b) || error("Fictitious-time bracket overflowed.")
        fb = f(b)
    end
    iszero(fb) && return b
    lo, hi = min(a,b), max(a,b)
    for _ in 1:max_iterations
        mid = (lo+hi)/T(2); fm = f(mid)
        abs(fm) <= tol && return mid
        if fm < zero(T); lo = mid else hi = mid end
    end
    return (lo+hi)/T(2)
end

"""Integrate exactly to a requested physical final time using the monotone Sundman map."""
function integrate_ks_two_body_to_time(problem::KSTwoBodyProblem{T}, target_time::Real; kwargs...) where {T}
    target = T(target_time)
    isfinite(target) || throw(ArgumentError("target_time must be finite."))
    target != problem.initial_time || throw(ArgumentError("target_time must differ from initial_time."))
    sf = ks_fictitious_time(problem, target)
    integrate_ks_two_body(problem, (zero(T), sf); kwargs...)
end
