"""
    ThreeBodySystem(masses; G=1)

Newtonian three-body model containing three strictly positive masses and the
positive gravitational constant `G`. Inputs are promoted to a common floating-
point type.

# Examples
```julia
system = ThreeBodySystem((1.0, 1.0, 1.0))
solar = ThreeBodySystem((1.0, 3.0e-6, 3.7e-8); G=4π^2)
```
"""
struct ThreeBodySystem{T<:AbstractFloat}
    masses::SVector{3,T}
    G::T

    function ThreeBodySystem{T}(
        masses::SVector{3,T},
        G::T,
    ) where {T<:AbstractFloat}

        if !all(isfinite, masses)
            throw(ArgumentError("Masses must be finite."))
        end

        if !all(mass -> mass > zero(mass), masses)
            throw(ArgumentError("All masses must be positive."))
        end

        if !Base.isfinite(G) || G <= zero(G)
            throw(ArgumentError("G must be finite and positive."))
        end

        return new{T}(masses, G)
    end
end


function ThreeBodySystem(
    masses::Tuple{A,B,C};
    G::Real=1,
) where {A<:Real,B<:Real,C<:Real}
    T = float(promote_type(A, B, C, typeof(G)))
    ThreeBodySystem{T}(SVector{3,T}(masses), T(G))
end

function ThreeBodySystem(masses::AbstractVector{<:Real}; G::Real=1)
    length(masses) == 3 || throw(ArgumentError("Exactly three masses are required."))
    ThreeBodySystem((masses[1], masses[2], masses[3]); G)
end

@inline mass(system::ThreeBodySystem, i::Integer) = system.masses[i]
@inline total_mass(system::ThreeBodySystem) = sum(system.masses)
@inline gravitational_constant(system::ThreeBodySystem) = system.G
