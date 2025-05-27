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
end