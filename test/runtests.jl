using GeometryBasics
using OASIS
using Test

@testset "Read data" begin
    @testset "Read unsigned integers" begin
        @test OASIS.rui(IOBuffer([0x00])) == 0
        @test OASIS.rui(IOBuffer([0x7f])) == 127
        @test OASIS.rui(IOBuffer([0x80, 0x01])) == 128
        @test OASIS.rui(IOBuffer([0xff, 0x7f])) == 16383
        @test OASIS.rui(IOBuffer([0x80, 0x80, 0x01])) == 16384
    end
    @testset "Read signed integers" begin
        @test OASIS.read_signed_integer(IOBuffer([0x00])) == 0
        @test OASIS.read_signed_integer(IOBuffer([0x02])) == 1
        @test OASIS.read_signed_integer(IOBuffer([0x03])) == -1
        @test OASIS.read_signed_integer(IOBuffer([0x7e])) == 63
        @test OASIS.read_signed_integer(IOBuffer([0x81, 0x01])) == -64
        @test OASIS.read_signed_integer(IOBuffer([0xfe, 0x7f])) == 8191
        @test OASIS.read_signed_integer(IOBuffer([0x81, 0x80, 0x01])) == -8192
    end
    @testset "Read reals" begin
        @test OASIS.read_real(IOBuffer([0x00, 0x00])) == 0.0
        @test OASIS.read_real(IOBuffer([0x00, 0x01])) == 1.0
        @test OASIS.read_real(IOBuffer([0x03, 0x02])) == -0.5
        @test OASIS.read_real(IOBuffer([0x04, 0x05, 0x10])) == 0.3125
        @test OASIS.read_real(IOBuffer([0x02, 0x03])) == 1/3
        @test OASIS.read_real(IOBuffer([0x05, 0x02, 0x0d])) == -2/13
        # In line below, LHS outputs Float64. Conversion to Float32 needed due to inherently
        # limited precision.
        @test OASIS.read_real(IOBuffer([0x06, 0xd9, 0x89, 0x1d, 0xbe])) == Float32(-2/13)
        @test OASIS.read_real(IOBuffer([0x07, 0x14, 0x3b, 0xb1, 0x13, 0x3b, 0xb1, 0xc3, 0xbf])) == -2/13
    end
    @testset "Read strings" begin
        @test OASIS.read_string(IOBuffer([0x03, 0x61, 0x62, 0x63, 0x64])) == "abc"
        @test OASIS.read_string(IOBuffer([0x00, 0xff])) == ""
    end
    @testset "Read 2-deltas" begin
        @test OASIS.read_2_delta(IOBuffer([0x98, 0x2a])) == Point2i(1350, 0)
        @test OASIS.read_2_delta(IOBuffer([0x9b, 0x2a])) == Point2i(0, -1350)
    end
    @testset "Read 3-deltas" begin
        @test OASIS.read_3_delta(IOBuffer([0xcd, 0x01])) == Point2i(-25, 25)
        @test OASIS.read_3_delta(IOBuffer([0xd7, 0x07])) == Point2i(122, -122)
    end
    @testset "Read g-deltas" begin
        @test OASIS.read_g_delta(IOBuffer([0xe9, 0x03, 0x7a])) == Point2i(122, 61)
        @test OASIS.read_g_delta(IOBuffer([0xec, 0x05])) == Point2i(-46, -46)
        @test OASIS.read_g_delta(IOBuffer([0xbb, 0x01, 0xb7, 0x0f])) == Point2i(-46, -987)
    end
    @testset "Read point lists" begin
        @test OASIS.read_point_list(IOBuffer([0x00, 0x04, 0x0c, 0x08, 0x11, 0x05])) ==
            Point2i[(6, 0), (0, 4), (-8, 0), (0, -2)]
        @test OASIS.read_point_list(IOBuffer([0x01, 0x04, 0x11, 0x04, 0x04, 0x04])) ==
            Point2i[(0, -8), (2, 0), (0, 2), (2, 0)]
        @test OASIS.read_point_list(IOBuffer([0x02, 0x05, 0x20, 0x19, 0x12, 0x0b, 0x12])) ==
            Point2i[(8, 0), (0, 6), (-4, 0), (0, -2), (-4, 0)]
        @test OASIS.read_point_list(IOBuffer([0x03, 0x04, 0x15, 0x21, 0x30, 0x13])) ==
            Point2i[(-2, 2), (0, 4), (6, 0), (0, -2)]
        @test OASIS.read_point_list(IOBuffer([0x04, 0x02, 0x44, 0x09, 0x0d])) ==
            Point2i[(-4, 0), (2, -6)]
        @test OASIS.read_point_list(IOBuffer([
            0x05, 0x09, 0x01, 0x03, 0x29,
            0x00, 0x01, 0x04, 0x01, 0x03,
            0x01, 0x03, 0x2b, 0x04, 0x2b,
            0x00, 0x01, 0x03, 0x01, 0x03
        ])) == Point2i[
            (0, -1), (10, -1), (10, 1), (10, 0), (10, -1),
            (0, 1), (-10, 1), (-10, 0), (-10, -1)
        ]
    end
    @testset "Read repetitions" begin
        @test OASIS.read_repetition(IOBuffer([0x01, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 130, 129, (1, 0), (0, 1))
        @test OASIS.read_repetition(IOBuffer([0x02, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 130, 1, (127, 0), (1, 1))
        @test OASIS.read_repetition(IOBuffer([0x03, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 1, 130, (1, 1), (0, 127))
        @test OASIS.read_repetition(IOBuffer([0x04, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (127, 0), (128, 0), (255, 0)]
        @test OASIS.read_repetition(IOBuffer([0x05, 0x02, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (254, 0), (256, 0), (510, 0)]
        @test OASIS.read_repetition(IOBuffer([0x06, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (0, 127), (0, 128), (0, 255)]
        @test OASIS.read_repetition(IOBuffer([0x07, 0x02, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (0, 254), (0, 256), (0, 510)]
        @test OASIS.read_repetition(IOBuffer([0x08, 0x80, 0x01, 0x7f, 0xe9, 0x03, 0x7a, 0xa0, 0x01])) ==
            PointGridRange((0, 0), 130, 129, (122, 61), (10, 0))
        @test OASIS.read_repetition(IOBuffer([0x09, 0x01, 0xe9, 0x03, 0x7a])) ==
            PointGridRange((0, 0), 3, 1, (122, 61), (1, 1))
        @test OASIS.read_repetition(IOBuffer([0x0a, 0x01, 0xe9, 0x03, 0x7a, 0xe9, 0x03, 0x7a])) ==
            Point2i[(0, 0), (122, 61), (244, 122)]
        @test OASIS.read_repetition(IOBuffer([0x0b, 0x01, 0x02, 0xe9, 0x03, 0x7a, 0xe9, 0x03, 0x7a])) ==
            Point2i[(0, 0), (244, 122), (488, 244)]
    end
    @testset "Intervals" begin
        @test OASIS.read_interval(IOBuffer([0x00, 0x80, 0x01, 0x80, 0x02])) == OASIS.Interval(0, typemax(UInt64))
        @test OASIS.read_interval(IOBuffer([0x01, 0x80, 0x01, 0x80, 0x02])) == OASIS.Interval(0, 128)
        @test OASIS.read_interval(IOBuffer([0x02, 0x80, 0x01, 0x80, 0x02])) == OASIS.Interval(128, typemax(UInt64))
        @test OASIS.read_interval(IOBuffer([0x03, 0x80, 0x01, 0x80, 0x02])) == OASIS.Interval(128, 128)
        @test OASIS.read_interval(IOBuffer([0x04, 0x80, 0x01, 0x80, 0x02])) == OASIS.Interval(128, 256)
    end
end

@testset "Point grid range" begin
    p = PointGridRange((1, 1), 3, 2, (1, 1), (0, 2))
    @test length(p) == 6
    @test first(p) == Point2i(1, 1)
    @test last(p) == Point2i(3, 5)
    @test size(p) == (3, 2)
    @test_throws BoundsError p[0]
    @test p[1] == p[1, 1] == Point2i(1, 1)
    @test p[2] == p[2, 1] == Point2i(2, 2)
    @test p[3] == p[3, 1] == Point2i(3, 3)
    @test p[4] == p[1, 2] == Point2i(1, 3)
    @test_throws BoundsError p[7]
    @test_throws BoundsError p[4, 1]
    @test_throws BoundsError p[1, 3]
    @test_throws BoundsError p[0]
    @test collect(p) == [p[1], p[2], p[3], p[4], p[5], p[6]]
end

@testset "Parse OASIS files" begin
    filenames = [
        "polygon.oas" # Uncompressed file containing single polygon
    ]
    for filename in filenames
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
    end
end
