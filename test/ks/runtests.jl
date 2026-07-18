@testset "KS forward transformations" begin
    basis_cases = (
        (SVector(1.0, 0.0, 0.0, 0.0), SVector(1.0, 0.0, 0.0)),
        (SVector(0.0, 1.0, 0.0, 0.0), SVector(-1.0, 0.0, 0.0)),
        (SVector(0.0, 0.0, 1.0, 0.0), SVector(-1.0, 0.0, 0.0)),
        (SVector(0.0, 0.0, 0.0, 1.0), SVector(1.0, 0.0, 0.0)),
    )
    for (u, expected) in basis_cases
        @test ThreeBody3D.ks_position(u) == expected
        @test ThreeBody3D.ks_radius(u) == 1.0
    end

    mixed = SVector(1.0, 2.0, 3.0, 4.0)
    @test ThreeBody3D.ks_position(mixed) == SVector(4.0, -20.0, 22.0)
    @test ThreeBody3D.ks_radius(mixed) == 30.0

    fixtures = (
        SVector(1.0, 2.0, 3.0, 4.0),
        SVector(-0.25, 0.5, -0.75, 1.25),
        SVector(1.0e-8, -2.0e-8, 3.0e-8, -4.0e-8),
        SVector(1.0e8, -2.0e8, 3.0e8, -4.0e8),
    )
    for u in fixtures
        q = ThreeBody3D.ks_position(u)
        rho = ThreeBody3D.ks_radius(u)
        J = ThreeBody3D.ks_jacobian(u)
        g = ThreeBody3D.ks_gauge_direction(u)
        @test isapprox(norm(q), rho; rtol=100eps(Float64), atol=100eps(Float64) * max(rho, 1.0))
        @test isapprox(J * transpose(J), 4rho * I(3); rtol=500eps(Float64), atol=500eps(Float64) * max(rho, 1.0))
        @test isapprox(J * g, zeros(3); rtol=0, atol=500eps(Float64) * max(rho, 1.0))
    end
end

@testset "KS analytic Jacobian" begin
    u = SVector(0.7, -1.1, 0.4, 1.3)
    J = ThreeBody3D.ks_jacobian(u)
    step = cbrt(eps(Float64))
    for column in 1:4
        direction = SVector{4,Float64}(ntuple(i -> i == column ? 1.0 : 0.0, 4))
        numerical = (
            ThreeBody3D.ks_position(u + step * direction) -
            ThreeBody3D.ks_position(u - step * direction)
        ) / (2step)
        @test isapprox(numerical, J[:, column]; rtol=1e-9, atol=1e-9)
    end
end

@testset "KS precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        u = SVector{4,T}(T(0.75), T(-0.5), T(1.25), T(0.375))
        w = SVector{4,T}(T(-0.25), T(0.625), T(0.5), T(-0.75))
        q = ThreeBody3D.ks_position(u)
        rho = ThreeBody3D.ks_radius(u)
        J = ThreeBody3D.ks_jacobian(u)
        g = ThreeBody3D.ks_gauge_direction(u)

        @test eltype(q) === T
        @test rho isa T
        @test eltype(J) === T
        @test eltype(g) === T
        @test ThreeBody3D.ks_constraint_residual(u, w) isa T

        tolerance = T(1000) * eps(T)
        @test isapprox(norm(q), rho; rtol=tolerance, atol=tolerance * max(rho, one(T)))
        @test isapprox(J * transpose(J), T(4) * rho * I(3); rtol=tolerance, atol=tolerance * max(rho, one(T)))
        @test isapprox(J * g, zeros(T, 3); rtol=zero(T), atol=tolerance * max(rho, one(T)))
    end

    u = SVector(1.0, 2.0, 3.0, 4.0)
    horizontal = ThreeBody3D.ks_jacobian(u)' * SVector(0.5, -0.25, 0.75)
    @test abs(ThreeBody3D.ks_constraint_residual(u, horizontal)) <= 100eps(Float64) * norm(u) * norm(horizontal)

    @test_throws ArgumentError ThreeBody3D.ks_position([1.0, 2.0, 3.0])
    @test_throws ArgumentError ThreeBody3D.ks_radius([1.0, 2.0, 3.0])
    @test_throws ArgumentError ThreeBody3D.ks_jacobian([1.0, 2.0, 3.0])
    @test_throws ArgumentError ThreeBody3D.ks_gauge_direction([1.0, 2.0, 3.0])
    @test_throws ArgumentError ThreeBody3D.ks_constraint_residual([1.0, 2.0, 3.0], zeros(4))
    @test_throws ArgumentError ThreeBody3D.ks_constraint_residual(zeros(4), [1.0, 2.0, 3.0])
    @test_throws ArgumentError ThreeBody3D.ks_position([1.0, 2.0, 3.0, Inf])
    @test_throws ArgumentError ThreeBody3D.ks_constraint_residual(zeros(4), [0.0, 0.0, NaN, 0.0])
end
