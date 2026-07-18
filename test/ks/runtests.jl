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

@testset "KS gauge transformations" begin
    fixtures = (
        (SVector(0.7, -1.1, 0.4, 1.3), SVector(-0.2, 0.5, 0.8, -0.6), 0.37),
        (SVector(-2.0, 0.25, 1.5, -0.75), SVector(0.4, -1.2, 0.3, 0.9), -1.1),
        (SVector(1.0e-7, -2.0e-7, 3.0e-7, 4.0e-7), SVector(0.5, 0.25, -0.75, 1.0), 2.3),
    )

    for (u, w, phi) in fixtures
        transformed_u, transformed_w = ThreeBody3D.ks_gauge_transform(u, w, phi)
        rho = ThreeBody3D.ks_radius(u)
        tolerance = 1000eps(Float64)

        @test isapprox(
            ThreeBody3D.ks_position(transformed_u),
            ThreeBody3D.ks_position(u);
            rtol=tolerance,
            atol=tolerance * max(rho, 1.0),
        )
        @test isapprox(
            ThreeBody3D.ks_radius(transformed_u),
            rho;
            rtol=tolerance,
            atol=tolerance * max(rho, 1.0),
        )
        @test isapprox(
            ThreeBody3D.ks_jacobian(transformed_u) * transformed_w,
            ThreeBody3D.ks_jacobian(u) * w;
            rtol=tolerance,
            atol=tolerance * max(norm(ThreeBody3D.ks_jacobian(u) * w), 1.0),
        )
        @test isapprox(
            ThreeBody3D.ks_constraint_residual(transformed_u, transformed_w),
            ThreeBody3D.ks_constraint_residual(u, w);
            rtol=tolerance,
            atol=tolerance * max(norm(u) * norm(w), 1.0),
        )
    end

    u = SVector(0.7, -1.1, 0.4, 1.3)
    phi1 = 0.41
    phi2 = -1.27
    composed = ThreeBody3D.ks_gauge_transform(
        ThreeBody3D.ks_gauge_transform(u, phi2),
        phi1,
    )
    direct = ThreeBody3D.ks_gauge_transform(u, phi1 + phi2)
    @test isapprox(composed, direct; rtol=500eps(Float64), atol=500eps(Float64) * norm(u))
    @test ThreeBody3D.ks_gauge_transform(u, 0.0) == u
    @test isapprox(
        ThreeBody3D.ks_gauge_transform(u, pi),
        -u;
        rtol=500eps(Float64),
        atol=500eps(Float64) * norm(u),
    )
end

@testset "KS gauge alignment" begin
    u = SVector(0.6, -0.9, 1.1, 0.35)
    w = SVector(-0.3, 0.8, 0.2, -0.5)
    reference = ThreeBody3D.ks_gauge_transform(u, 1.17)
    aligned_u, aligned_w = ThreeBody3D.align_ks_gauge(u, w, reference)

    tolerance = 1000eps(Float64)
    @test norm(aligned_u - reference) <= tolerance * max(norm(reference), 1.0)
    @test norm(aligned_u - reference) <= norm(u - reference)
    @test isapprox(
        ThreeBody3D.ks_position(aligned_u),
        ThreeBody3D.ks_position(u);
        rtol=tolerance,
        atol=tolerance * max(ThreeBody3D.ks_radius(u), 1.0),
    )
    @test isapprox(
        ThreeBody3D.ks_jacobian(aligned_u) * aligned_w,
        ThreeBody3D.ks_jacobian(u) * w;
        rtol=tolerance,
        atol=tolerance * max(norm(ThreeBody3D.ks_jacobian(u) * w), 1.0),
    )

    opposite_reference = -reference
    opposite_u, opposite_w = ThreeBody3D.align_ks_gauge(u, w, opposite_reference)
    @test norm(opposite_u - opposite_reference) <= tolerance * max(norm(opposite_reference), 1.0)
    @test isapprox(
        ThreeBody3D.ks_jacobian(opposite_u) * opposite_w,
        ThreeBody3D.ks_jacobian(u) * w;
        rtol=tolerance,
        atol=tolerance * max(norm(ThreeBody3D.ks_jacobian(u) * w), 1.0),
    )
end

@testset "KS gauge precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        u = SVector{4,T}(T(0.75), T(-0.5), T(1.25), T(0.375))
        w = SVector{4,T}(T(-0.25), T(0.625), T(0.5), T(-0.75))
        reference = SVector{4,T}(T(-0.2), T(0.9), T(0.4), T(-1.1))
        phi = T === BigFloat ? big"0.7312345678901234567890123456789" : T(0.7312345)

        transformed_u, transformed_w = ThreeBody3D.ks_gauge_transform(u, w, phi)
        aligned_u, aligned_w = ThreeBody3D.align_ks_gauge(u, w, reference)
        tolerance = T(2000) * eps(T)
        rho = ThreeBody3D.ks_radius(u)

        @test eltype(transformed_u) === T
        @test eltype(transformed_w) === T
        @test eltype(aligned_u) === T
        @test eltype(aligned_w) === T
        @test isapprox(
            ThreeBody3D.ks_position(transformed_u),
            ThreeBody3D.ks_position(u);
            rtol=tolerance,
            atol=tolerance * max(rho, one(T)),
        )
        @test isapprox(
            ThreeBody3D.ks_radius(transformed_u),
            rho;
            rtol=tolerance,
            atol=tolerance * max(rho, one(T)),
        )
        @test norm(aligned_u - reference) <= norm(u - reference) + tolerance * max(norm(u), norm(reference), one(T))
    end

    @test_throws ArgumentError ThreeBody3D.ks_gauge_transform([1.0, 2.0, 3.0], 0.5)
    @test_throws ArgumentError ThreeBody3D.ks_gauge_transform(zeros(4), [1.0, 2.0, 3.0], 0.5)
    @test_throws ArgumentError ThreeBody3D.ks_gauge_transform(zeros(4), zeros(4), Inf)
    @test_throws ArgumentError ThreeBody3D.ks_gauge_transform([1.0, 2.0, NaN, 4.0], 0.5)
    @test_throws ArgumentError ThreeBody3D.align_ks_gauge(zeros(3), zeros(4), zeros(4))
    @test_throws ArgumentError ThreeBody3D.align_ks_gauge(zeros(4), zeros(3), zeros(4))
    @test_throws ArgumentError ThreeBody3D.align_ks_gauge(zeros(4), zeros(4), zeros(3))
    @test_throws ArgumentError ThreeBody3D.align_ks_gauge(zeros(4), zeros(4), [0.0, 0.0, Inf, 0.0])
end
