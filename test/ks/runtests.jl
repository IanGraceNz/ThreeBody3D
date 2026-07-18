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

@testset "KS deterministic inverse position lift" begin
    fixtures = (
        SVector(1.0, 0.0, 0.0),
        SVector(-1.0, 0.0, 0.0),
        SVector(0.0, 1.0, 0.0),
        SVector(0.0, 0.0, 1.0),
        SVector(3.0, -4.0, 12.0),
        SVector(-7.0, 2.5, -1.25),
        SVector(1.0e-18, -2.0e-18, 3.0e-18),
        SVector(-1.0e18, 2.0e17, -3.0e17),
    )

    for q in fixtures
        u = ThreeBody3D.cartesian_to_ks_position(q)
        rho = norm(q)
        tolerance = 2000eps(Float64)
        @test isapprox(
            ThreeBody3D.ks_position(u),
            q;
            rtol=tolerance,
            atol=tolerance * max(rho, 1.0),
        )
        @test isapprox(
            ThreeBody3D.ks_radius(u),
            rho;
            rtol=tolerance,
            atol=tolerance * max(rho, 1.0),
        )
    end

    positive_axis = ThreeBody3D.cartesian_to_ks_position(SVector(9.0, 0.0, 0.0))
    @test positive_axis == SVector(0.0, -0.0, 0.0, -3.0)

    negative_axis = ThreeBody3D.cartesian_to_ks_position(SVector(-9.0, 0.0, 0.0))
    @test negative_axis == SVector(0.0, 3.0, 0.0, 0.0)

    positive_chart = ThreeBody3D.cartesian_to_ks_position(SVector(0.25, 2.0, -3.0))
    negative_chart = ThreeBody3D.cartesian_to_ks_position(SVector(-0.25, 2.0, -3.0))
    @test iszero(positive_chart[1])
    @test iszero(negative_chart[3])
end

@testset "KS inverse lift axis robustness" begin
    scales = (1.0e-12, 1.0, 1.0e12)
    offsets = (0.0, 1.0e-12, -1.0e-12, 1.0e-8, -1.0e-8)

    for scale in scales, offset in offsets
        q_positive = SVector(scale, scale * offset, -2scale * offset)
        q_negative = SVector(-scale, scale * offset, -2scale * offset)
        for q in (q_positive, q_negative)
            u = ThreeBody3D.cartesian_to_ks_position(q)
            tolerance = 5000eps(Float64)
            @test all(isfinite, u)
            @test isapprox(
                ThreeBody3D.ks_position(u),
                q;
                rtol=tolerance,
                atol=tolerance * max(norm(q), 1.0),
            )
        end
    end

    boundary_vectors = (
        SVector(0.0, 1.0, 2.0),
        SVector(eps(Float64), 1.0, 2.0),
        SVector(-eps(Float64), 1.0, 2.0),
    )
    for q in boundary_vectors
        u = ThreeBody3D.cartesian_to_ks_position(q)
        @test isapprox(
            ThreeBody3D.ks_position(u),
            q;
            rtol=5000eps(Float64),
            atol=5000eps(Float64) * norm(q),
        )
    end
end

@testset "KS inverse lift reference alignment" begin
    q = SVector(-2.5, 1.75, 0.625)
    candidate = ThreeBody3D.cartesian_to_ks_position(q)
    reference = ThreeBody3D.ks_gauge_transform(candidate, 1.234)
    aligned = ThreeBody3D.cartesian_to_ks_position(q; reference=reference)
    tolerance = 2000eps(Float64)

    @test norm(aligned - reference) <= tolerance * max(norm(reference), 1.0)
    @test norm(aligned - reference) <= norm(candidate - reference)
    @test isapprox(
        ThreeBody3D.ks_position(aligned),
        q;
        rtol=tolerance,
        atol=tolerance * max(norm(q), 1.0),
    )

    opposite = -reference
    aligned_opposite = ThreeBody3D.cartesian_to_ks_position(q; reference=opposite)
    @test norm(aligned_opposite - opposite) <= tolerance * max(norm(opposite), 1.0)

    nearby_positions = (
        q,
        q + SVector(1.0e-10, -2.0e-10, 3.0e-10),
        q + SVector(-2.0e-10, 1.0e-10, -1.0e-10),
    )
    previous = reference
    for nearby in nearby_positions
        current = ThreeBody3D.cartesian_to_ks_position(nearby; reference=previous)
        @test dot(current, previous) >= zero(eltype(current))
        @test isapprox(
            ThreeBody3D.ks_position(current),
            nearby;
            rtol=5000eps(Float64),
            atol=5000eps(Float64) * max(norm(nearby), 1.0),
        )
        previous = current
    end
end

@testset "KS inverse lift precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        q = SVector{3,T}(T(-3.25), T(1.5), T(-0.875))
        candidate = ThreeBody3D.cartesian_to_ks_position(q)
        phi = T === BigFloat ? big"0.918273645546372819" : T(0.9182736)
        reference = ThreeBody3D.ks_gauge_transform(candidate, phi)
        aligned = ThreeBody3D.cartesian_to_ks_position(q; reference=reference)
        tolerance = T(5000) * eps(T)
        rho = norm(q)

        @test eltype(candidate) === T
        @test eltype(aligned) === T
        @test isapprox(
            ThreeBody3D.ks_position(candidate),
            q;
            rtol=tolerance,
            atol=tolerance * max(rho, one(T)),
        )
        @test isapprox(
            ThreeBody3D.ks_radius(candidate),
            rho;
            rtol=tolerance,
            atol=tolerance * max(rho, one(T)),
        )
        @test norm(aligned - reference) <= tolerance * max(norm(reference), one(T))
    end

    mixed = ThreeBody3D.cartesian_to_ks_position(
        Float32[-1, 2, 3];
        reference=BigFloat[0, 1, 0, 0],
    )
    @test eltype(mixed) === BigFloat

    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_position([1.0, 2.0])
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_position([1.0, 2.0, Inf])
    @test_throws DomainError ThreeBody3D.cartesian_to_ks_position(zeros(3))
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_position(
        ones(3);
        reference=zeros(3),
    )
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_position(
        ones(3);
        reference=[0.0, 0.0, NaN, 0.0],
    )
end
