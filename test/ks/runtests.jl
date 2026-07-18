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

@testset "KS velocity transformations" begin
    fixtures = (
        (SVector(3.0, -4.0, 12.0), SVector(-0.5, 1.25, 0.75)),
        (SVector(-7.0, 2.5, -1.25), SVector(2.0, -0.25, 1.5)),
        (SVector(1.0e-14, -2.0e-14, 3.0e-14), SVector(4.0, -5.0, 6.0)),
        (SVector(-1.0e14, 2.0e13, -3.0e13), SVector(-2.0, 0.5, 3.0)),
    )

    for (q, v) in fixtures
        u, w = ThreeBody3D.cartesian_to_ks_state(q, v)
        tolerance = 5000eps(Float64)
        @test isapprox(
            ThreeBody3D.ks_position(u), q;
            rtol=tolerance,
            atol=tolerance * max(norm(q), 1.0),
        )
        @test isapprox(
            ThreeBody3D.ks_to_cartesian_velocity(u, w), v;
            rtol=tolerance,
            atol=tolerance * max(norm(v), 1.0),
        )
        @test abs(ThreeBody3D.ks_constraint_residual(u, w)) <=
            tolerance * max(norm(u) * norm(w), 1.0)
    end
end

@testset "KS horizontal velocity projection" begin
    u = SVector(0.7, -1.1, 0.4, 1.3)
    v = SVector(-0.6, 1.4, 0.25)
    w = ThreeBody3D.cartesian_to_ks_velocity(u, v)
    reconstructed = ThreeBody3D.ks_to_cartesian_velocity(u, w)
    tolerance = 2000eps(Float64)

    @test isapprox(reconstructed, v; rtol=tolerance, atol=tolerance * norm(v))
    @test abs(ThreeBody3D.ks_constraint_residual(u, w)) <=
        tolerance * max(norm(u) * norm(w), 1.0)
    @test isapprox(
        ThreeBody3D.cartesian_to_ks_velocity(u, reconstructed),
        w;
        rtol=tolerance,
        atol=tolerance * max(norm(w), 1.0),
    )

    arbitrary_w = SVector(-0.2, 0.8, 1.1, -0.35)
    projected_w = ThreeBody3D.cartesian_to_ks_velocity(
        u,
        ThreeBody3D.ks_to_cartesian_velocity(u, arbitrary_w),
    )
    gauge = ThreeBody3D.ks_gauge_direction(u)
    expected = arbitrary_w - gauge * (
        dot(gauge, arbitrary_w) / dot(gauge, gauge)
    )
    @test isapprox(
        projected_w,
        expected;
        rtol=tolerance,
        atol=tolerance * max(norm(expected), 1.0),
    )
    @test abs(ThreeBody3D.ks_constraint_residual(u, projected_w)) <=
        tolerance * max(norm(u) * norm(projected_w), 1.0)
end

@testset "KS velocity gauge invariance" begin
    q = SVector(-2.5, 1.75, 0.625)
    v = SVector(0.4, -1.2, 2.1)
    u, w = ThreeBody3D.cartesian_to_ks_state(q, v)
    transformed_u, transformed_w = ThreeBody3D.ks_gauge_transform(u, w, 1.137)
    tolerance = 3000eps(Float64)

    @test isapprox(
        ThreeBody3D.ks_position(transformed_u), q;
        rtol=tolerance,
        atol=tolerance * max(norm(q), 1.0),
    )
    @test isapprox(
        ThreeBody3D.ks_to_cartesian_velocity(transformed_u, transformed_w), v;
        rtol=tolerance,
        atol=tolerance * max(norm(v), 1.0),
    )

    reference = ThreeBody3D.ks_gauge_transform(u, -0.83)
    aligned_u, aligned_w = ThreeBody3D.cartesian_to_ks_state(q, v; reference=reference)
    @test norm(aligned_u - reference) <= tolerance * max(norm(reference), 1.0)
    @test isapprox(
        ThreeBody3D.ks_to_cartesian_velocity(aligned_u, aligned_w), v;
        rtol=tolerance,
        atol=tolerance * max(norm(v), 1.0),
    )
end

@testset "KS velocity precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        q = SVector{3,T}(T(-3.25), T(1.5), T(-0.875))
        v = SVector{3,T}(T(0.625), T(-1.125), T(2.25))
        u, w = ThreeBody3D.cartesian_to_ks_state(q, v)
        tolerance = T(8000) * eps(T)

        @test eltype(u) === T
        @test eltype(w) === T
        @test eltype(ThreeBody3D.ks_to_cartesian_velocity(u, w)) === T
        @test isapprox(
            ThreeBody3D.ks_position(u), q;
            rtol=tolerance,
            atol=tolerance * max(norm(q), one(T)),
        )
        @test isapprox(
            ThreeBody3D.ks_to_cartesian_velocity(u, w), v;
            rtol=tolerance,
            atol=tolerance * max(norm(v), one(T)),
        )
        @test abs(ThreeBody3D.ks_constraint_residual(u, w)) <=
            tolerance * max(norm(u) * norm(w), one(T))
    end

    mixed_u, mixed_w = ThreeBody3D.cartesian_to_ks_state(
        Float32[-1, 2, 3],
        BigFloat[0.5, -1.0, 2.0],
    )
    @test eltype(mixed_u) === BigFloat
    @test eltype(mixed_w) === BigFloat

    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_velocity(zeros(3), zeros(3))
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_velocity(zeros(4), zeros(4))
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_velocity(zeros(4), [0.0, Inf, 0.0])
    @test_throws ArgumentError ThreeBody3D.ks_to_cartesian_velocity(zeros(3), zeros(4))
    @test_throws ArgumentError ThreeBody3D.ks_to_cartesian_velocity(zeros(4), zeros(3))
    @test_throws DomainError ThreeBody3D.ks_to_cartesian_velocity(zeros(4), zeros(4))
    @test_throws ArgumentError ThreeBody3D.ks_to_cartesian_velocity(ones(4), [0.0, 0.0, NaN, 0.0])
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_state(zeros(2), zeros(3))
    @test_throws ArgumentError ThreeBody3D.cartesian_to_ks_state(ones(3), zeros(2))
    @test_throws DomainError ThreeBody3D.cartesian_to_ks_state(zeros(3), zeros(3))
end

@testset "KS transformation diagnostics" begin
    u = SVector(1.0, 2.0, 3.0, 4.0)
    q = ThreeBody3D.ks_position(u)
    v = SVector(-0.5, 1.25, 0.75)
    w = ThreeBody3D.cartesian_to_ks_velocity(u, v)
    mu = 7.0
    h = (mu - 2dot(w, w)) / dot(u, u)
    tolerance = 5000eps(Float64)

    @test ThreeBody3D.ks_radial_identity_residual(SVector(1.0, 0.0, 0.0, 0.0)) == 0.0
    @test ThreeBody3D.ks_jacobian_identity_residual(SVector(1.0, 0.0, 0.0, 0.0)) == 0.0
    @test ThreeBody3D.ks_scaled_constraint_residual(u, w) <= tolerance
    @test ThreeBody3D.ks_position_roundtrip_residual(q) <= tolerance
    @test ThreeBody3D.ks_velocity_roundtrip_residual(q, v) <= tolerance
    @test ThreeBody3D.ks_energy_consistency_residual(u, w, h, mu) <= tolerance

    corrupted_w = w + 0.25 * ThreeBody3D.ks_gauge_direction(u)
    corrupted_h = h + 0.5
    @test ThreeBody3D.ks_scaled_constraint_residual(u, corrupted_w) > 1.0e-3
    @test ThreeBody3D.ks_energy_consistency_residual(u, w, corrupted_h, mu) > 1.0e-3

    collision_w = SVector(sqrt(mu / 2), 0.0, 0.0, 0.0)
    @test isfinite(ThreeBody3D.ks_energy_consistency_residual(zeros(4), collision_w, 3.0, mu))
    @test ThreeBody3D.ks_energy_consistency_residual(zeros(4), collision_w, 3.0, mu) <= tolerance
end

@testset "KS diagnostic scaling and precision" begin
    for T in (Float32, Float64, BigFloat)
        tolerance = T(12000) * eps(T)
        for scale in (T(1.0e-12), one(T), T(1.0e12))
            u = scale * SVector{4,T}(T(0.7), T(-1.1), T(0.4), T(1.3))
            q = ThreeBody3D.ks_position(u)
            v = SVector{3,T}(T(-0.6), T(1.4), T(0.25))
            w = ThreeBody3D.cartesian_to_ks_velocity(u, v)
            mu = T(2.75)
            h = (mu - T(2) * dot(w, w)) / dot(u, u)

            @test ThreeBody3D.ks_radial_identity_residual(u) <= tolerance
            @test ThreeBody3D.ks_jacobian_identity_residual(u) <= tolerance
            @test ThreeBody3D.ks_scaled_constraint_residual(u, w) <= tolerance
            @test ThreeBody3D.ks_position_roundtrip_residual(q) <= tolerance
            @test ThreeBody3D.ks_velocity_roundtrip_residual(q, v) <= tolerance
            @test ThreeBody3D.ks_energy_consistency_residual(u, w, h, mu) <= tolerance
        end
    end

    mixed = ThreeBody3D.ks_energy_consistency_residual(
        Float32[1, 0, 0, 0],
        BigFloat[0, 0, 0, 0],
        big"2.0",
        big"2.0",
    )
    @test mixed isa BigFloat
end

@testset "KS diagnostic validation and immutability" begin
    u = [0.7, -1.1, 0.4, 1.3]
    w = [-0.2, 0.8, 1.1, -0.35]
    q = [1.0, 2.0, 3.0]
    v = [-0.5, 0.25, 1.5]
    original_u = copy(u)
    original_w = copy(w)
    original_q = copy(q)
    original_v = copy(v)

    ThreeBody3D.ks_radial_identity_residual(u)
    ThreeBody3D.ks_jacobian_identity_residual(u)
    ThreeBody3D.ks_scaled_constraint_residual(u, w)
    ThreeBody3D.ks_position_roundtrip_residual(q)
    ThreeBody3D.ks_velocity_roundtrip_residual(q, v)
    ThreeBody3D.ks_energy_consistency_residual(u, w, 1.0, 2.0)

    @test u == original_u
    @test w == original_w
    @test q == original_q
    @test v == original_v

    @test_throws ArgumentError ThreeBody3D.ks_radial_identity_residual(zeros(3))
    @test_throws ArgumentError ThreeBody3D.ks_jacobian_identity_residual([0.0, Inf, 0.0, 0.0])
    @test_throws ArgumentError ThreeBody3D.ks_scaled_constraint_residual(zeros(4), zeros(3))
    @test_throws ArgumentError ThreeBody3D.ks_scaled_constraint_residual(zeros(4), [0.0, NaN, 0.0, 0.0])
    @test_throws ArgumentError ThreeBody3D.ks_position_roundtrip_residual(zeros(2))
    @test_throws DomainError ThreeBody3D.ks_position_roundtrip_residual(zeros(3))
    @test_throws ArgumentError ThreeBody3D.ks_velocity_roundtrip_residual(ones(3), zeros(2))
    @test_throws DomainError ThreeBody3D.ks_velocity_roundtrip_residual(zeros(3), zeros(3))
    @test_throws ArgumentError ThreeBody3D.ks_energy_consistency_residual(zeros(3), zeros(4), 1.0, 1.0)
    @test_throws ArgumentError ThreeBody3D.ks_energy_consistency_residual(zeros(4), zeros(4), Inf, 1.0)
    @test_throws ArgumentError ThreeBody3D.ks_energy_consistency_residual(zeros(4), zeros(4), 1.0, NaN)
end

@testset "KS unperturbed state and RHS" begin
    mu = 2.0
    q = SVector(1.5, -0.4, 0.8)
    v = SVector(-0.2, 0.7, 0.3)
    problem = ThreeBody3D.KSTwoBodyProblem(mu, q, v; initial_time=1.25)
    y0 = ThreeBody3D.ks_initial_state(problem)
    u, w, h, t = ThreeBody3D.ks_unpack_state(y0)
    rhs = ThreeBody3D.ks_unperturbed_rhs(y0)

    @test u == problem.u0
    @test w == problem.w0
    @test h == problem.binding_energy
    @test t == problem.initial_time
    @test SVector{4,Float64}(rhs[1:4]) == w
    @test SVector{4,Float64}(rhs[5:8]) ≈ -(h / 2) * u
    @test rhs[9] == 0.0
    @test rhs[10] == dot(u, u)
    @test ThreeBody3D.ks_energy_consistency_residual(u, w, h, mu) <= 1000eps(Float64)
    @test ThreeBody3D.ks_scaled_constraint_residual(u, w) <= 1000eps(Float64)

    q2, v2, t2 = ThreeBody3D.ks_cartesian_state(y0)
    @test q2 ≈ q
    @test v2 ≈ v
    @test t2 == 1.25
end

@testset "KS exact unperturbed propagation" begin
    cases = (
        (SVector(1.0, 0.0, 0.0), SVector(0.0, 1.0, 0.0)),
        (SVector(1.0, 0.0, 0.0), SVector(0.0, 0.6, 0.35)),
        (SVector(1.0, 0.0, 0.0), SVector(0.0, 1.8, 0.4)),
        (SVector(1.0, 0.0, 0.0), SVector(0.0, 0.0, 0.0)),
    )
    for (q, v) in cases
        problem = ThreeBody3D.KSTwoBodyProblem(1.0, q, v)
        for s in (0.0, 0.15, 0.7)
            u, w, h, t = ThreeBody3D.ks_exact_state(problem, s)
            @test isfinite(t)
            @test h == problem.binding_energy
            @test ThreeBody3D.ks_scaled_constraint_residual(u, w) <= 3000eps(Float64)
            @test ThreeBody3D.ks_energy_consistency_residual(u, w, h, 1.0) <= 5000eps(Float64)
        end
    end
end

@testset "KS numerical unperturbed integration" begin
    problem = ThreeBody3D.KSTwoBodyProblem(
        1.0, SVector(1.2, -0.3, 0.7), SVector(-0.1, 0.55, 0.25); initial_time=0.4)
    result = ThreeBody3D.integrate_ks_two_body(problem, (0.0, 3.0); saveat=0.1)
    for s in (0.0, 0.3, 1.1, 2.7, 3.0)
        u, w, h, t = ThreeBody3D.ks_state(result, s)
        ue, we, he, te = ThreeBody3D.ks_exact_state(problem, s)
        @test u ≈ ue rtol=2e-10 atol=2e-11
        @test w ≈ we rtol=2e-10 atol=2e-11
        @test h ≈ he rtol=2e-12 atol=2e-12
        @test t ≈ te rtol=3e-10 atol=3e-11
        @test ThreeBody3D.ks_scaled_constraint_residual(u, w) <= 2e-10
        @test ThreeBody3D.ks_energy_consistency_residual(u, w, h, 1.0) <= 2e-10
    end
end

@testset "KS physical final-time targeting" begin
    problem = ThreeBody3D.KSTwoBodyProblem(
        1.0, SVector(1.0, 0.0, 0.0), SVector(0.0, 0.8, 0.3); initial_time=2.0)
    for target in (1.7, 2.4, 3.2)
        s = ThreeBody3D.ks_fictitious_time(problem, target)
        _, _, _, exact_time = ThreeBody3D.ks_exact_state(problem, s)
        @test exact_time ≈ target rtol=2e-12 atol=2e-12
    end
    result = ThreeBody3D.integrate_ks_two_body_to_time(problem, 2.75)
    @test result.solution.u[end][10] ≈ 2.75 rtol=2e-10 atol=2e-11
end

@testset "KS radial collision continuation" begin
    problem = ThreeBody3D.KSTwoBodyProblem(1.0, SVector(1.0, 0.0, 0.0), zeros(3))
    collision_s = pi / sqrt(2.0)
    uc, wc, hc, tc = ThreeBody3D.ks_exact_state(problem, collision_s)
    @test norm(uc) <= 2e-15
    @test all(isfinite, wc)
    @test isfinite(hc)
    @test isfinite(tc)
    @test ThreeBody3D.ks_energy_consistency_residual(uc, wc, hc, 1.0) <= 1000eps(Float64)

    before = ThreeBody3D.ks_exact_state(problem, collision_s - 1e-3)
    after = ThreeBody3D.ks_exact_state(problem, collision_s + 1e-3)
    @test ThreeBody3D.ks_position(before[1]) ≈ ThreeBody3D.ks_position(after[1]) rtol=1e-10
    @test all(isfinite, after[1]) && all(isfinite, after[2])
    @test_throws DomainError ThreeBody3D.ks_to_cartesian_velocity(zeros(4), wc)

    result = ThreeBody3D.integrate_ks_two_body(problem, (0.0, collision_s + 0.2);
        tstops=[collision_s], reltol=1e-13, abstol=1e-13)
    u_after, w_after, _, _ = ThreeBody3D.ks_state(result, collision_s + 0.1)
    ue_after, we_after, _, _ = ThreeBody3D.ks_exact_state(problem, collision_s + 0.1)
    @test u_after ≈ ue_after rtol=2e-10 atol=2e-11
    @test w_after ≈ we_after rtol=2e-10 atol=2e-11
end

@testset "KS dynamics precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        problem = ThreeBody3D.KSTwoBodyProblem(T(1), SVector{3,T}(1,0,0), SVector{3,T}(0,1,0))
        y = ThreeBody3D.ks_initial_state(problem)
        rhs = ThreeBody3D.ks_unperturbed_rhs(y)
        state = ThreeBody3D.ks_exact_state(problem, T(0.2))
        @test eltype(y) == T
        @test eltype(rhs) == T
        @test eltype(state[1]) == T
        @test state[3] isa T
        @test state[4] isa T
    end

    @test_throws ArgumentError ThreeBody3D.KSTwoBodyProblem(0.0, ones(3), zeros(3))
    @test_throws ArgumentError ThreeBody3D.KSTwoBodyProblem(1.0, ones(2), zeros(3))
    @test_throws DomainError ThreeBody3D.KSTwoBodyProblem(1.0, zeros(3), zeros(3))
    @test_throws ArgumentError ThreeBody3D.ks_pack_state(zeros(3), zeros(4), 1.0, 0.0)
    @test_throws ArgumentError ThreeBody3D.ks_unpack_state(zeros(9))
    @test_throws ArgumentError ThreeBody3D.ks_unperturbed_rhs([zeros(9); NaN])
    @test_throws ArgumentError ThreeBody3D.integrate_ks_two_body(
        ThreeBody3D.KSTwoBodyProblem(1.0, ones(3), zeros(3)), (0.0, 0.0))
end

@testset "KS and Levi-Civita planar cross-validation" begin
    cases = (
        (1.0, SVector(1.0, 0.0), SVector(0.0, 1.0), collect(range(0.0, 2π; length=17))),
        (1.0, SVector(1.0, 0.0), SVector(0.0, 0.35), collect(range(0.0, 1.0; length=15))),
        (1.0, SVector(1.0, 0.0), SVector(0.0, 1.7), collect(range(0.0, 0.8; length=13))),
    )

    for (mu, q, v, times) in cases
        report = ThreeBody3D.cross_validate_ks_levi_civita(mu, q, v, times)
        tolerance = 2.0e-10
        @test report.numeric_type === Float64
        @test length(report.samples) == length(times)
        @test report.maximum_position_error <= tolerance
        @test report.maximum_velocity_error <= tolerance
        @test report.maximum_time_error <= tolerance
        @test report.maximum_energy_error <= tolerance
        @test report.maximum_levi_civita_energy_drift <= tolerance
        @test report.maximum_ks_energy_drift <= tolerance
        @test report.initial_transition_position_error <= tolerance
        @test report.initial_transition_velocity_error <= tolerance
        @test report.final_transition_position_error <= tolerance
        @test report.final_transition_velocity_error <= tolerance
    end
end

@testset "KS and Levi-Civita near-collision cross-validation" begin
    mu = 1.0
    q = SVector(2.0, 0.0)
    v = SVector(0.0, 0.0)
    lc = LeviCivitaOscillator(mu, q, v)
    collision_time = levi_civita_physical_time(lc, π)
    times = [0.0, collision_time * 0.5, collision_time * 0.9,
        collision_time * (1 - 1.0e-6), collision_time * (1 + 1.0e-6)]
    report = ThreeBody3D.cross_validate_ks_levi_civita(mu, q, v, times)

    @test report.maximum_position_error <= 5.0e-9
    @test report.maximum_velocity_error <= 5.0e-7
    @test report.maximum_time_error <= 5.0e-10
    @test report.maximum_energy_error <= 5.0e-7
    @test all(isfinite, (report.maximum_position_error, report.maximum_velocity_error,
        report.maximum_time_error, report.maximum_energy_error))
end

@testset "KS and Levi-Civita BigFloat cross-validation" begin
    setprecision(BigFloat, 256) do
        mu = big"1.0"
        q = SVector{2,BigFloat}(big"1.0", big"0.0")
        v = SVector{2,BigFloat}(big"0.0", big"0.08")
        times = BigFloat[big"0.0", big"0.1", big"0.25", big"0.5", big"0.8"]
        report = ThreeBody3D.cross_validate_ks_levi_civita(mu, q, v, times)
        tolerance = big"1e-55"

        @test report.numeric_type === BigFloat
        @test report.maximum_position_error <= tolerance
        @test report.maximum_velocity_error <= tolerance
        @test report.maximum_time_error <= tolerance
        @test report.maximum_energy_error <= tolerance
        @test report.maximum_levi_civita_energy_drift <= tolerance
        @test report.maximum_ks_energy_drift <= tolerance
    end
end

@testset "KS and Levi-Civita cross-validation input validation" begin
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [1.0], [0.0, 1.0], [0.0])
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [1.0, 0.0], [0.0], [0.0])
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [1.0, 0.0], [0.0, 1.0], Float64[])
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(0.0, [1.0, 0.0], [0.0, 1.0], [0.0])
    @test_throws DomainError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [0.0, 0.0], [0.0, 1.0], [0.0])
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [Inf, 0.0], [0.0, 1.0], [0.0])
    @test_throws ArgumentError ThreeBody3D.cross_validate_ks_levi_civita(1.0, [1.0, 0.0], [0.0, 1.0], [NaN])
end

@testset "KS perturbed dynamics controlled forcing" begin
    q0 = SVector(1.2, -0.3, 0.5)
    v0 = SVector(-0.1, 0.45, 0.2)
    zero_force(q,v,t) = zero(q)
    p0 = ThreeBody3D.KSPerturbedProblem(1.0, q0, v0, zero_force; initial_time=0.2)
    base = ThreeBody3D.KSTwoBodyProblem(1.0, q0, v0; initial_time=0.2)
    @test ThreeBody3D.ks_perturbed_rhs(ThreeBody3D.ks_initial_state(p0), p0) ≈
          ThreeBody3D.ks_unperturbed_rhs(ThreeBody3D.ks_initial_state(base))
    r0 = ThreeBody3D.integrate_ks_perturbed(p0, (0.0, 1.5); reltol=1e-13, abstol=1e-13)
    ru = ThreeBody3D.integrate_ks_two_body(base, (0.0, 1.5); reltol=1e-13, abstol=1e-13)
    for s in (0.0, 0.4, 1.0, 1.5)
        @test r0.solution(s) ≈ ru.solution(s) rtol=2e-10 atol=2e-11
    end

    a = SVector(0.03, -0.02, 0.01)
    constant_force(q,v,t) = a
    pc = ThreeBody3D.KSPerturbedProblem(1.0, q0, v0, constant_force)
    yc = ThreeBody3D.ks_initial_state(pc)
    rhs = ThreeBody3D.ks_perturbed_rhs(yc, pc)
    u,w,h,t = ThreeBody3D.ks_unpack_state(yc)
    J = ThreeBody3D.ks_jacobian(u); rho = dot(u,u)
    @test SVector{4,Float64}(rhs[5:8]) ≈ -(h/2)*u + (rho/4)*(transpose(J)*a)
    @test rhs[9] ≈ -dot(J*w, a)
    @test rhs[10] == rho

    linear_force(q,v,t) = -0.015q
    pl = ThreeBody3D.KSPerturbedProblem(1.0, q0, v0, linear_force)
    rl = ThreeBody3D.integrate_ks_perturbed(pl, (0.0, 2.0); saveat=0.05)
    for y in rl.solution.u
        u,w,h,t = ThreeBody3D.ks_unpack_state(y)
        @test all(isfinite, y)
        @test ThreeBody3D.ks_scaled_constraint_residual(u,w) <= 2e-9
        @test ThreeBody3D.ks_energy_consistency_residual(u,w,h,1.0) <= 2e-9
    end

    timed_force(q,v,t) = SVector(0.01sin(t), -0.02cos(t), 0.005sin(2t))
    pt = ThreeBody3D.KSPerturbedProblem(1.0, q0, v0, timed_force)
    rt = ThreeBody3D.integrate_ks_perturbed(pt, (0.0, 0.8))
    @test all(isfinite, rt.solution.u[end])
end

@testset "KS perturbed dynamics collision regularity" begin
    smooth_force(q,v,t) = SVector(0.2, -0.1, 0.05)
    p = ThreeBody3D.KSPerturbedProblem(1.0, SVector(1.0,0.0,0.0), zeros(3), smooth_force)
    ycollision = ThreeBody3D.ks_pack_state(zeros(4), SVector(0.0,0.0,0.0,inv(sqrt(2.0))), 1.0, 1.0)
    rhs = ThreeBody3D.ks_perturbed_rhs(ycollision, p)
    @test all(isfinite, rhs)
    @test SVector{4,Float64}(rhs[5:8]) == zeros(4)
    @test rhs[10] == 0.0
end

@testset "KS perturbed dynamics precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        force(q,v,t) = SVector{3,T}(T(0.01), T(-0.02), T(0.03))
        p = ThreeBody3D.KSPerturbedProblem(T(1), SVector{3,T}(1,0,0), SVector{3,T}(0,1,0), force)
        y = ThreeBody3D.ks_initial_state(p)
        rhs = ThreeBody3D.ks_perturbed_rhs(y,p)
        @test eltype(y) == T
        @test eltype(rhs) == T
    end
    @test_throws ArgumentError ThreeBody3D.KSPerturbedProblem(1.0, ones(3), zeros(3), (q,v,t)->ones(2))
    @test_throws ArgumentError ThreeBody3D.KSPerturbedProblem(1.0, ones(3), zeros(3), (q,v,t)->[1.0,NaN,0.0])
    p = ThreeBody3D.KSPerturbedProblem(1.0, ones(3), zeros(3), (q,v,t)->zeros(3))
    @test_throws ArgumentError ThreeBody3D.integrate_ks_perturbed(p, (0.0,0.0))
end

@testset "KS pair-centred three-body reconstruction" begin
    system = ThreeBodySystem((1.2,0.8,0.5); G=0.9)
    state = statevector(
        SVector(-0.4,0.2,0.1), SVector(0.1,0.35,-0.05),
        SVector(0.6,-0.1,-0.2), SVector(-0.2,-0.25,0.08),
        SVector(4.0,2.0,-1.0), SVector(0.03,-0.04,0.02),
    )
    for pair in ((1,2),(1,3),(2,3))
        p = ThreeBody3D.KSThreeBodyProblem(system,state,pair; initial_time=0.3)
        y = ThreeBody3D.ks_initial_state(p)
        reconstructed = ThreeBody3D.ks_three_body_cartesian_state(p,y)
        @test reconstructed ≈ state rtol=5e-14 atol=5e-14
        @test y[10] == 0.3
        @test p.pair == pair
        @test p.third == 6-pair[1]-pair[2]
    end
end

@testset "KS three-body acceleration decomposition" begin
    system = ThreeBodySystem((1.0,2.0,0.7); G=1.3)
    state = statevector(
        SVector(-0.5,0.1,0.2), SVector(0.2,0.3,-0.1),
        SVector(0.4,-0.2,-0.1), SVector(-0.15,-0.25,0.05),
        SVector(3.0,1.5,0.7), SVector(0.04,-0.03,0.02),
    )
    for pair in ((1,2),(1,3),(2,3))
        p = ThreeBody3D.KSThreeBodyProblem(system,state,pair)
        y = ThreeBody3D.ks_initial_state(p)
        u,w,h,t,R,V,rk,vk = ThreeBody3D.ks_unpack_three_body_state(y)
        f,aR,ak = ThreeBody3D.ks_three_body_accelerations(p,u,R,rk)
        du = similar(state); ThreeBody3D.threebody!(du,state,system,0.0)
        i,j = pair; k = p.third
        ai = SVector{3,Float64}(du[(6i-2):(6i)])
        aj = SVector{3,Float64}(du[(6j-2):(6j)])
        akk = SVector{3,Float64}(du[(6k-2):(6k)])
        q = body_position(state,i)-body_position(state,j)
        μ = system.G*(system.masses[i]+system.masses[j])
        mutual = -μ*q/(norm(q)^3)
        @test f ≈ (ai-aj)-mutual rtol=2e-14 atol=2e-14
        @test aR ≈ (system.masses[i]*ai+system.masses[j]*aj)/(system.masses[i]+system.masses[j]) rtol=2e-14 atol=2e-14
        @test ak ≈ akk rtol=2e-14 atol=2e-14
        @test norm((system.masses[i]+system.masses[j])*aR + system.masses[k]*ak) <= 5e-14
    end
end

@testset "KS coupled three-body RHS and integration" begin
    system = ThreeBodySystem((1.0,0.4,0.2))
    state = statevector(
        SVector(-0.3,0.0,0.0), SVector(0.0,-0.45,0.08),
        SVector(0.7,0.0,0.0), SVector(0.0,0.65,-0.12),
        SVector(6.0,1.0,0.5), SVector(-0.03,0.02,0.01),
    )
    p = ThreeBody3D.KSThreeBodyProblem(system,state,(1,2))
    y0 = ThreeBody3D.ks_initial_state(p)
    rhs = ThreeBody3D.ks_three_body_rhs(y0,p)
    u,w,h,t,R,V,rk,vk = ThreeBody3D.ks_unpack_three_body_state(y0)
    du,dw,dh,dt,dR,dV,drk,dvk = ThreeBody3D.ks_unpack_three_body_state(rhs)
    rho = dot(u,u)
    @test du == w
    @test dt == rho
    @test dR ≈ rho*V
    @test drk ≈ rho*vk
    @test ThreeBody3D.ks_scaled_constraint_residual(u,w) <= 1e-14
    @test ThreeBody3D.ks_energy_consistency_residual(u,w,h,system.G*(system.masses[1]+system.masses[2])) <= 1e-14

    result = ThreeBody3D.integrate_ks_three_body(p,(0.0,0.35); reltol=1e-13,abstol=1e-13)
    yend = result.solution(0.35)
    tend = yend[10]
    regularized = ThreeBody3D.ks_three_body_cartesian_state(p,yend)
    direct = simulate(system,state,(0.0,tend); solver=:accurate,reltol=1e-13,abstol=1e-13)
    @test regularized ≈ direct.solution(tend) rtol=2e-10 atol=2e-11

    initial_energy = total_energy(system,state)
    initial_momentum = linear_momentum(system,state)
    for s in range(0.0,0.35;length=15)
        cart = ThreeBody3D.ks_cartesian_state(result,s)
        @test abs(total_energy(system,cart)-initial_energy) <= 2e-10
        @test norm(linear_momentum(system,cart)-initial_momentum) <= 2e-11
        @test norm(body_position(cart,1)-body_position(cart,3)) > 1.0
        @test norm(body_position(cart,2)-body_position(cart,3)) > 1.0
        uu,ww,_,_,_,_,_,_ = ThreeBody3D.ks_state(result,s)
        @test ThreeBody3D.ks_scaled_constraint_residual(uu,ww) <= 2e-10
    end
end

@testset "KS three-body precision and validation" begin
    for T in (Float32,Float64,BigFloat)
        system = ThreeBodySystem((T(1),T(0.5),T(0.25));G=T(1))
        state = statevector(
            SVector{3,T}(-1,0,0),SVector{3,T}(0,-T(0.2),0),
            SVector{3,T}(1,0,0),SVector{3,T}(0,T(0.4),0),
            SVector{3,T}(5,1,0),SVector{3,T}(0,0,0),
        )
        p=ThreeBody3D.KSThreeBodyProblem(system,state,(1,2))
        y=ThreeBody3D.ks_initial_state(p)
        dy=ThreeBody3D.ks_three_body_rhs(y,p)
        @test eltype(y) === T
        @test eltype(dy) === T
        @test eltype(ThreeBody3D.ks_three_body_cartesian_state(p,y)) === T
    end
    system=ThreeBodySystem((1.0,1.0,1.0))
    state=statevector(SVector(-1.0,0,0),zeros(3),SVector(1.0,0,0),zeros(3),SVector(4.0,0,0),zeros(3))
    @test_throws ArgumentError ThreeBody3D.KSThreeBodyProblem(system,state,(1,1))
    p=ThreeBody3D.KSThreeBodyProblem(system,state,(1,2))
    @test_throws ArgumentError ThreeBody3D.ks_unpack_three_body_state(zeros(21))
    @test_throws ArgumentError ThreeBody3D.integrate_ks_three_body(p,(0.0,0.0))
    y=ThreeBody3D.ks_initial_state(p)
    u,_,_,_,R,_,_,_=ThreeBody3D.ks_unpack_three_body_state(y)
    ri,_=ThreeBody3D._ks_pair_body_positions(p,u,R)
    y[17:19].=ri
    @test_throws DomainError ThreeBody3D.ks_three_body_rhs(y,p)
end

@testset "Explicit KS regularized segment" begin
    system = ThreeBodySystem((1.0, 0.4, 0.2))
    state = statevector(
        SVector(-0.3,0.0,0.0), SVector(0.0,-0.45,0.08),
        SVector(0.7,0.0,0.0), SVector(0.0,0.65,-0.12),
        SVector(6.0,1.0,0.5), SVector(-0.03,0.02,0.01),
    )
    segment = ThreeBody3D.propagate_ks_segment(
        system, state, (1,2), 0.0, 0.2; reltol=1e-13, abstol=1e-13,
    )
    @test segment.start_time == 0.0
    @test segment.end_time == 0.2
    @test segment.ks_result.solution === segment.ks_result.solution
    @test segment.ks_result.solution.u[end][10] ≈ 0.2 atol=5e-14
    @test segment(0.0) == state
    @test segment(0.2) == segment.exit_state
    @test length(segment.times) == length(segment.states) == length(segment.ks_result.solution.t)
    @test issorted(segment.times)

    for index in eachindex(segment.times)
        @test segment(segment.times[index]) ≈ segment.states[index] rtol=3e-10 atol=3e-11
    end
    midpoint = 0.1
    first_eval = segment(midpoint)
    second_eval = segment(midpoint)
    @test first_eval == second_eval
    direct = simulate(system, state, (0.0, midpoint); solver=:accurate, reltol=1e-13, abstol=1e-13)
    @test first_eval ≈ direct.solution(midpoint) rtol=3e-10 atol=3e-11
    @test segment.diagnostics.entry_transition.state_residual <= 5e-15
    @test segment.diagnostics.exit_transition.state_residual <= 5e-15
    @test segment.diagnostics.maximum_scaled_constraint_residual <= 5e-10
    @test segment.diagnostics.maximum_relative_energy_drift <= 5e-10
    @test segment.diagnostics.minimum_nonselected_separation > 1.0
    @test segment.diagnostics.solver_statistics.saved_states == length(segment.ks_result.solution.t)
end

@testset "Explicit KS segment precision and validation" begin
    for T in (Float32, Float64, BigFloat)
        system = ThreeBodySystem((T(1), T(0.5), T(0.25)); G=T(1))
        state = statevector(
            SVector{3,T}(-1,0,0), SVector{3,T}(0,-T(0.2),0),
            SVector{3,T}(1,0,0), SVector{3,T}(0,T(0.4),0),
            SVector{3,T}(5,1,0), SVector{3,T}(0,0,0),
        )
        segment = ThreeBody3D.propagate_ks_segment(system, state, (1,2), T(0), T(0.02))
        @test eltype(segment.exit_state) === T
        @test eltype(segment(T(0.01))) === T
    end
    system = ThreeBodySystem((1.0,1.0,1.0))
    state = statevector(SVector(-1.0,0,0),zeros(3),SVector(1.0,0,0),zeros(3),SVector(4.0,0,0),zeros(3))
    @test_throws ArgumentError ThreeBody3D.propagate_ks_segment(system,state,(1,2),1.0,0.5)
    @test_throws ArgumentError ThreeBody3D.propagate_ks_segment(system,state,(1,2),0.0,0.0)
    segment = ThreeBody3D.propagate_ks_segment(system,state,(1,2),0.0,0.02)
    @test_throws ArgumentError segment(-0.01)
    @test_throws ArgumentError segment(0.03)
    @test_throws ArgumentError ThreeBody3D.propagate_ks_segment(
        system,state,(1,2),0.0,0.02; nonselected_threshold=-1.0,
    )
    close_state = copy(state)
    close_state[13:15] .= close_state[1:3] .+ [1e-3,0.0,0.0]
    @test_throws DomainError ThreeBody3D.propagate_ks_segment(
        system, close_state, (1,2), 0.0, 0.02; nonselected_threshold=2e-3,
    )
end
