using Oasis
using Test

@testset "Read data" begin
    @testset "Read unsigned integers" begin
        @test Oasis.read_unsigned_integer(IOBuffer([0x00])) == 0
        @test Oasis.read_unsigned_integer(IOBuffer([0x7f])) == 127
        @test Oasis.read_unsigned_integer(IOBuffer([0x80, 0x01])) == 128
        @test Oasis.read_unsigned_integer(IOBuffer([0xff, 0x7f])) == 16383
        @test Oasis.read_unsigned_integer(IOBuffer([0x80, 0x80, 0x01])) == 16384
    end
    @testset "Read signed integers" begin
        @test Oasis.read_signed_integer(IOBuffer([0x00])) == 0
        @test Oasis.read_signed_integer(IOBuffer([0x02])) == 1
        @test Oasis.read_signed_integer(IOBuffer([0x03])) == -1
        @test Oasis.read_signed_integer(IOBuffer([0x7e])) == 63
        @test Oasis.read_signed_integer(IOBuffer([0x81, 0x01])) == -64
        @test Oasis.read_signed_integer(IOBuffer([0xfe, 0x7f])) == 8191
        @test Oasis.read_signed_integer(IOBuffer([0x81, 0x80, 0x01])) == -8192
    end
    @testset "Read reals" begin
        @test Oasis.read_real(IOBuffer([0x00, 0x00])) == 0.0
        @test Oasis.read_real(IOBuffer([0x00, 0x01])) == 1.0
        @test Oasis.read_real(IOBuffer([0x03, 0x02])) == -0.5
        @test Oasis.read_real(IOBuffer([0x04, 0x05, 0x10])) == 0.3125
        @test Oasis.read_real(IOBuffer([0x02, 0x03])) == 1/3
        @test Oasis.read_real(IOBuffer([0x05, 0x02, 0x0d])) == -2/13
        # In line below, LHS outputs Float64. Conversion to Float32 needed due to inherently
        # limited precision.
        @test Oasis.read_real(IOBuffer([0x06, 0xd9, 0x89, 0x1d, 0xbe])) == Float32(-2/13)
        @test Oasis.read_real(IOBuffer([0x07, 0x14, 0x3b, 0xb1, 0x13, 0x3b, 0xb1, 0xc3, 0xbf])) == -2/13
    end
    @testset "Read strings" begin
        @test Oasis.read_string(IOBuffer([0x03, 0x61, 0x62, 0x63, 0x64])) == "abc"
        @test Oasis.read_string(IOBuffer([0x00, 0xff])) == ""
    end
    @testset "Read 2-deltas" begin
        @test Oasis.read_2_delta(IOBuffer([0x98, 0x2a])) == (1350, 0)
        @test Oasis.read_2_delta(IOBuffer([0x9b, 0x2a])) == (0, -1350)
    end
    @testset "Read 3-deltas" begin
        @test Oasis.read_3_delta(IOBuffer([0xcd, 0x01])) == (-25, 25)
        @test Oasis.read_3_delta(IOBuffer([0xd7, 0x07])) == (122, -122)
    end
    @testset "Read g-deltas" begin
        @test Oasis.read_g_delta(IOBuffer([0xe9, 0x03, 0x7a])) == (122, 61)
        @test Oasis.read_g_delta(IOBuffer([0xec, 0x05])) == (-46, -46)
        @test Oasis.read_g_delta(IOBuffer([0xbb, 0x01, 0xb7, 0x0f])) == (-46, -987)
    end
    @testset "Read point lists" begin
        @test Oasis.read_point_list(IOBuffer([0x00, 0x04, 0x0c, 0x08, 0x11, 0x05])) ==
            [(6, 0), (0, 4), (-8, 0), (0, -2)]
        @test Oasis.read_point_list(IOBuffer([0x01, 0x04, 0x11, 0x04, 0x04, 0x04])) ==
            [(0, -8), (2, 0), (0, 2), (2, 0)]
        @test Oasis.read_point_list(IOBuffer([0x02, 0x05, 0x20, 0x19, 0x12, 0x0b, 0x12])) ==
            [(8, 0), (0, 6), (-4, 0), (0, -2), (-4, 0)]
        @test Oasis.read_point_list(IOBuffer([0x03, 0x04, 0x15, 0x21, 0x30, 0x13])) ==
            [(-2, 2), (0, 4), (6, 0), (0, -2)]
    end
end