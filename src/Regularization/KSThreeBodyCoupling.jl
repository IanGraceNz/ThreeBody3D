"""
    KSThreeBodyProblem(system, state, pair; reference=nothing, initial_time=0)

Internal initial data for a complete three-body segment in which the ordered
pair `(i,j)` is represented by KS relative variables and the pair centre of
mass and remaining body remain Cartesian. The relative coordinate is
`r_i-r_j`, matching [`PairCoordinates`](@ref).
"""
struct KSThreeBodyProblem{T<:AbstractFloat,S}
    system::S
    pair::Tuple{Int,Int}
    third::Int
    u0::SVector{4,T}
    w0::SVector{4,T}
    binding_energy::T
    initial_time::T
    pair_com_position::SVector{3,T}
    pair_com_velocity::SVector{3,T}
    third_position::SVector{3,T}
    third_velocity::SVector{3,T}
end

function KSThreeBodyProblem(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer};
    reference=nothing,
    initial_time::Real=0,
)
    validate_state(state)
    i, j, k = _validate_pair(pair)
    T = float(promote_type(eltype(system.masses), eltype(state), typeof(initial_time)))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    coordinates = to_pair_coordinates(converted_system, T.(state), (i,j))
    μ = T(converted_system.G * (mass(converted_system,i) + mass(converted_system,j)))
    base = KSTwoBodyProblem(
        μ,
        coordinates.relative_position,
        coordinates.relative_velocity;
        reference=reference,
        initial_time=T(initial_time),
    )
    KSThreeBodyProblem{T,typeof(converted_system)}(
        converted_system,
        (i,j),
        k,
        base.u0,
        base.w0,
        base.binding_energy,
        base.initial_time,
        SVector{3,T}(coordinates.binary_com_position),
        SVector{3,T}(coordinates.binary_com_velocity),
        SVector{3,T}(coordinates.third_position),
        SVector{3,T}(coordinates.third_velocity),
    )
end

const KS_THREE_BODY_STATE_SIZE = 22

function ks_pack_three_body_state(u, w, h, t, R, V, rk, vk)
    length(u) == 4 || throw(ArgumentError("u must contain four components."))
    length(w) == 4 || throw(ArgumentError("w must contain four components."))
    length(R) == 3 || throw(ArgumentError("R must contain three components."))
    length(V) == 3 || throw(ArgumentError("V must contain three components."))
    length(rk) == 3 || throw(ArgumentError("rk must contain three components."))
    length(vk) == 3 || throw(ArgumentError("vk must contain three components."))
    T = float(promote_type(eltype(u), eltype(w), typeof(h), typeof(t),
                           eltype(R), eltype(V), eltype(rk), eltype(vk)))
    y = Vector{T}(undef, KS_THREE_BODY_STATE_SIZE)
    y[1:4] .= u; y[5:8] .= w; y[9] = h; y[10] = t
    y[11:13] .= R; y[14:16] .= V; y[17:19] .= rk; y[20:22] .= vk
    all(isfinite, y) || throw(ArgumentError("KS three-body state must be finite."))
    y
end

function ks_unpack_three_body_state(y::AbstractVector{<:Real})
    length(y) == KS_THREE_BODY_STATE_SIZE ||
        throw(ArgumentError("KS three-body state must contain $KS_THREE_BODY_STATE_SIZE elements."))
    all(isfinite, y) || throw(ArgumentError("KS three-body state must be finite."))
    T = float(eltype(y))
    (
        SVector{4,T}(y[1:4]), SVector{4,T}(y[5:8]), T(y[9]), T(y[10]),
        SVector{3,T}(y[11:13]), SVector{3,T}(y[14:16]),
        SVector{3,T}(y[17:19]), SVector{3,T}(y[20:22]),
    )
end

@inline ks_initial_state(problem::KSThreeBodyProblem) = ks_pack_three_body_state(
    problem.u0, problem.w0, problem.binding_energy, problem.initial_time,
    problem.pair_com_position, problem.pair_com_velocity,
    problem.third_position, problem.third_velocity,
)

@inline function _ks_pair_body_positions(problem::KSThreeBodyProblem{T}, u, R) where {T}
    i,j = problem.pair
    mi = T(mass(problem.system,i)); mj = T(mass(problem.system,j)); M = mi+mj
    q = ks_position(u)
    R + (mj/M)*q, R - (mi/M)*q
end

"""Return `(f, aR, ak)`, the relative perturbation, pair-centre acceleration,
and third-body acceleration for one coupled KS state."""
function ks_three_body_accelerations(problem::KSThreeBodyProblem{T}, u, R, rk) where {T}
    uu = SVector{4,T}(u); RR = SVector{3,T}(R); rkk = SVector{3,T}(rk)
    ri, rj = _ks_pair_body_positions(problem, uu, RR)
    i,j,k = problem.pair[1], problem.pair[2], problem.third
    mi = T(mass(problem.system,i)); mj = T(mass(problem.system,j)); mk = T(mass(problem.system,k))
    M = mi+mj; G = T(problem.system.G)
    di = rkk-ri; dj = rkk-rj
    qi = G*_inverse_cube(di); qj = G*_inverse_cube(dj)
    ai3 = mk*qi*di
    aj3 = mk*qj*dj
    f = ai3-aj3
    aR = (mi*ai3 + mj*aj3)/M
    ak = -mi*qi*di - mj*qj*dj
    f, aR, ak
end

"""Return the complete pair-centred KS three-body right-hand side."""
function ks_three_body_rhs(y::AbstractVector{<:Real}, problem::KSThreeBodyProblem{T}) where {T}
    u0,w0,h0,t0,R0,V0,rk0,vk0 = ks_unpack_three_body_state(y)
    u=SVector{4,T}(u0); w=SVector{4,T}(w0); h=T(h0); t=T(t0)
    R=SVector{3,T}(R0); V=SVector{3,T}(V0); rk=SVector{3,T}(rk0); vk=SVector{3,T}(vk0)
    rho = dot(u,u)
    f,aR,ak = ks_three_body_accelerations(problem,u,R,rk)
    J = ks_jacobian(u); qprime = J*w
    wprime = -(h/T(2))*u + (rho/T(4))*(transpose(J)*f)
    hprime = -dot(qprime,f)
    ks_pack_three_body_state(w,wprime,hprime,rho,
        rho*V,rho*aR,rho*vk,rho*ak)
end

"""Reconstruct the ordinary 18-component Cartesian state from a coupled KS state."""
function ks_three_body_cartesian_state(problem::KSThreeBodyProblem{T}, y::AbstractVector{<:Real}) where {T}
    u0,w0,_,_,R0,V0,rk0,vk0 = ks_unpack_three_body_state(y)
    u=SVector{4,T}(u0); w=SVector{4,T}(w0)
    q = ks_position(u)
    qdot = ks_to_cartesian_velocity(u,w)
    coordinates = PairCoordinates{T}(
        q,qdot,SVector{3,T}(R0),SVector{3,T}(V0),
        SVector{3,T}(rk0),SVector{3,T}(vk0),problem.pair,problem.third,
    )
    Vector{T}(from_pair_coordinates(problem.system,coordinates))
end

struct KSThreeBodyResult{P,S}
    problem::P
    solution::S
end

"""Integrate the complete pair-centred KS three-body equations in fictitious time."""
function integrate_ks_three_body(
    problem::KSThreeBodyProblem{T}, sspan::Tuple{<:Real,<:Real};
    algorithm=Vern9(), reltol=nothing, abstol=nothing, kwargs...
) where {T}
    s0,s1=T(sspan[1]),T(sspan[2])
    all(isfinite,(s0,s1)) || throw(ArgumentError("sspan endpoints must be finite."))
    s0 != s1 || throw(ArgumentError("sspan endpoints must differ."))
    rt=isnothing(reltol) ? T(1e-12) : T(reltol)
    at=isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt>zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at>zero(T) || throw(ArgumentError("abstol must be finite and positive."))
    rhs(y,p,s)=ks_three_body_rhs(y,p)
    sol=solve(ODEProblem(rhs,ks_initial_state(problem),(s0,s1),problem),algorithm;
        reltol=rt,abstol=at,kwargs...)
    SciMLBase.successful_retcode(sol) || error("KS three-body integration failed with retcode $(sol.retcode).")
    KSThreeBodyResult(problem,sol)
end

ks_state(result::KSThreeBodyResult,s::Real)=ks_unpack_three_body_state(result.solution(s))
ks_cartesian_state(result::KSThreeBodyResult,s::Real)=
    ks_three_body_cartesian_state(result.problem,result.solution(s))
