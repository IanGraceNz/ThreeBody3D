"""
    PerturbedLeviCivitaProblem

Initial data for one explicitly selected planar binary embedded in a Newtonian
three-body system and written in Levi-Civita coordinates.

The selected pair uses the ordered relative coordinate `rᵢ-rⱼ`; reversing the
pair changes the Levi-Civita gauge/orientation but not the reconstructed
physical state. The regularized state evolves in fictitious time `s` with
`dt/ds = |u|²`. This experimental Stage 5 type does not perform automatic pair
selection or switching.
"""
struct PerturbedLeviCivitaProblem{T<:AbstractFloat,S<:ThreeBodySystem}
    system::S
    pair::Tuple{Int,Int}
    third::Int
    branch::Int
    u0::SVector{2,T}
    uprime0::SVector{2,T}
    binary_specific_energy0::T
    binary_com_position0::SVector{2,T}
    binary_com_velocity0::SVector{2,T}
    third_position0::SVector{2,T}
    third_velocity0::SVector{2,T}
    initial_time::T
end

@inline function _planar_vector(v::SVector{3,T}, name::AbstractString) where {T}
    tolerance = T(64) * eps(T) * max(one(T), norm(v))
    abs(v[3]) <= tolerance ||
        throw(ArgumentError("$name must be planar (zero z component)."))
    SVector{2,T}(v[1], v[2])
end

"""
    PerturbedLeviCivitaProblem(system, u0, pair; branch=1, initial_time=0)

Construct the explicit selected-pair regularized problem from an ordinary
18-element planar three-body state.

All positions and velocities must have negligible `z` components. The selected
binary must not begin at collision. `branch` selects one of the two equivalent
Levi-Civita square-root gauges.
"""
function PerturbedLeviCivitaProblem(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer};
    branch::Integer=1,
    initial_time::Real=zero(eltype(state)),
)
    validate_state(state)
    i, j, k = _validate_pair(pair)
    branch in (-1, 1) || throw(ArgumentError("branch must be either 1 or -1."))
    T = float(promote_type(eltype(system.masses), eltype(state), typeof(initial_time)))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    coordinates = to_pair_coordinates(converted_system, T.(state), (i, j))

    q = _planar_vector(SVector{3,T}(coordinates.relative_position), "relative_position")
    qdot = _planar_vector(SVector{3,T}(coordinates.relative_velocity), "relative_velocity")
    R = _planar_vector(SVector{3,T}(coordinates.binary_com_position), "binary_com_position")
    V = _planar_vector(SVector{3,T}(coordinates.binary_com_velocity), "binary_com_velocity")
    rk = _planar_vector(SVector{3,T}(coordinates.third_position), "third_position")
    vk = _planar_vector(SVector{3,T}(coordinates.third_velocity), "third_velocity")

    lc = to_levi_civita(q, qdot; branch=branch)
    radius = norm(q)
    μ = converted_system.G * (mass(converted_system, i) + mass(converted_system, j))
    h = dot(qdot, qdot) / T(2) - μ / radius
    w = radius * lc.udot
    t0 = T(initial_time)
    isfinite(t0) || throw(ArgumentError("initial_time must be finite."))

    PerturbedLeviCivitaProblem{T,typeof(converted_system)}(
        converted_system, (i, j), k, Int(branch), lc.u, w, h,
        R, V, rk, vk, t0,
    )
end

@inline function _lc_transpose_multiply(u::SVector{2,T}, f::SVector{2,T}) where {T}
    SVector{2,T}(u[1] * f[1] + u[2] * f[2],
                 -u[2] * f[1] + u[1] * f[2])
end

@inline function _planar_inverse_cube(d::SVector{2,T}, label::AbstractString) where {T}
    r2 = dot(d, d)
    iszero(r2) && throw(DomainError(r2, "$label is singular."))
    inv(r2 * sqrt(r2))
end

function _perturbed_lc_rhs(y, problem::PerturbedLeviCivitaProblem{T}, _s) where {T}
    u = SVector{2,T}(y[1], y[2])
    w = SVector{2,T}(y[3], y[4])
    R = SVector{2,T}(y[5], y[6])
    V = SVector{2,T}(y[7], y[8])
    rk = SVector{2,T}(y[9], y[10])
    vk = SVector{2,T}(y[11], y[12])
    h = y[13]

    i, j = problem.pair
    mi = T(mass(problem.system, i))
    mj = T(mass(problem.system, j))
    mk = T(mass(problem.system, problem.third))
    M = mi + mj
    G = T(problem.system.G)

    radius = dot(u, u)
    q = levi_civita_position(u)
    ri = R + (mj / M) * q
    rj = R - (mi / M) * q

    dik = rk - ri
    djk = rk - rj
    inv_dik3 = _planar_inverse_cube(dik, "Third body coincides with the first selected body")
    inv_djk3 = _planar_inverse_cube(djk, "Third body coincides with the second selected body")

    ai_external = G * mk * inv_dik3 * dik
    aj_external = G * mk * inv_djk3 * djk
    perturbation = ai_external - aj_external
    binary_com_acceleration = (mi * ai_external + mj * aj_external) / M
    third_acceleration = -G * mi * inv_dik3 * dik - G * mj * inv_djk3 * djk

    transformed_perturbation = _lc_transpose_multiply(u, perturbation)
    wprime = (h / T(2)) * u + (radius / T(2)) * transformed_perturbation
    hprime = T(2) * dot(w, transformed_perturbation)

    SVector{14,T}(
        w[1], w[2],
        wprime[1], wprime[2],
        radius * V[1], radius * V[2],
        radius * binary_com_acceleration[1], radius * binary_com_acceleration[2],
        radius * vk[1], radius * vk[2],
        radius * third_acceleration[1], radius * third_acceleration[2],
        hprime,
        radius,
    )
end

"""
    PerturbedLeviCivitaResult

Numerical fixed-fictitious-time solution for an explicit selected planar binary
in a full three-body system. The internal state contains Levi-Civita binary
variables, binary centre-of-mass motion, third-body motion, evolving binary
specific energy, and physical time.
"""
struct PerturbedLeviCivitaResult{P,S}
    problem::P
    solution::S
end

"""
    integrate_perturbed_levi_civita(problem, sspan; kwargs...)

Integrate an explicit selected planar binary and the third body over a fixed
fictitious-time interval beginning at `s=0`.

The regularized equations use

`u'' = (h/2)u + (|u|²/2)L(u)'F`,
`h' = 2u'⋅L(u)'F`, and `dt/ds = |u|²`,

where `F` is the differential acceleration of the selected pair caused by the
third body. This Stage 5 function performs no automatic switching or
physical-time targeting. Solver keywords are forwarded to `solve`.
"""
function integrate_perturbed_levi_civita(
    problem::PerturbedLeviCivitaProblem{T},
    sspan::Tuple{<:Real,<:Real};
    algorithm=Vern9(),
    reltol=nothing,
    abstol=nothing,
    kwargs...,
) where {T}
    s0, s1 = T(sspan[1]), T(sspan[2])
    all(isfinite, (s0, s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    iszero(s0) || throw(ArgumentError("The fixed-fictitious-time interval must begin at zero."))
    s1 != s0 || throw(ArgumentError("sspan endpoints must differ."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt > zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at > zero(T) || throw(ArgumentError("abstol must be finite and positive."))

    y0 = SVector{14,T}(
        problem.u0[1], problem.u0[2],
        problem.uprime0[1], problem.uprime0[2],
        problem.binary_com_position0[1], problem.binary_com_position0[2],
        problem.binary_com_velocity0[1], problem.binary_com_velocity0[2],
        problem.third_position0[1], problem.third_position0[2],
        problem.third_velocity0[1], problem.third_velocity0[2],
        problem.binary_specific_energy0,
        problem.initial_time,
    )
    ode = ODEProblem(_perturbed_lc_rhs, y0, (s0, s1), problem)
    solution = solve(ode, algorithm; reltol=rt, abstol=at, kwargs...)
    SciMLBase.successful_retcode(solution) ||
        error("Perturbed Levi-Civita integration failed with retcode $(solution.retcode).")
    PerturbedLeviCivitaResult(problem, solution)
end

"""
    perturbed_levi_civita_state(result, s)

Evaluate a [`PerturbedLeviCivitaResult`](@ref) at fictitious time `s`.

Returns a named tuple containing physical time, regularized variables, binary
specific energy, and the reconstructed ordinary 18-element physical state.
Cartesian velocity reconstruction throws `DomainError` at an exact selected
binary collision, although the internal regularized solution remains finite.
"""
function perturbed_levi_civita_state(result::PerturbedLeviCivitaResult, s::Real)
    y = result.solution(s)
    T = eltype(y)
    u = SVector{2,T}(y[1], y[2])
    w = SVector{2,T}(y[3], y[4])
    R = SVector{2,T}(y[5], y[6])
    V = SVector{2,T}(y[7], y[8])
    rk = SVector{2,T}(y[9], y[10])
    vk = SVector{2,T}(y[11], y[12])
    h = y[13]
    physical_time = y[14]
    radius = dot(u, u)
    radius > zero(T) ||
        throw(DomainError(radius, "Cartesian velocity is undefined at exact selected binary collision."))

    q = levi_civita_position(u)
    qdot = levi_civita_velocity(u, w / radius)
    pair_coordinates = PairCoordinates{T}(
        SVector{3,T}(q[1], q[2], zero(T)),
        SVector{3,T}(qdot[1], qdot[2], zero(T)),
        SVector{3,T}(R[1], R[2], zero(T)),
        SVector{3,T}(V[1], V[2], zero(T)),
        SVector{3,T}(rk[1], rk[2], zero(T)),
        SVector{3,T}(vk[1], vk[2], zero(T)),
        result.problem.pair,
        result.problem.third,
    )
    physical_state = from_pair_coordinates(result.problem.system, pair_coordinates)
    (
        physical_time=physical_time,
        regularized_position=u,
        regularized_derivative=w,
        binary_specific_energy=h,
        physical_state=physical_state,
    )
end
