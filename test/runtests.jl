using Oasis
using Test

@testset "Read integers" begin
    @testset "Read unsigned integers" begin
        @test Oasis.read_unsigned_integer([0x00]) == 0
        @test Oasis.read_unsigned_integer([0x7f]) == 127
        @test Oasis.read_unsigned_integer([0x80, 0x01]) == 128
        @test Oasis.read_unsigned_integer([0xff, 0x7f]) == 16383
        @test Oasis.read_unsigned_integer([0x80, 0x80, 0x01]) == 16384
    end
    @testset "Read signed integers" begin
        @test Oasis.read_signed_integer([0x00]) == 0
        @test Oasis.read_signed_integer([0x02]) == 1
        @test Oasis.read_signed_integer([0x03]) == -1
        @test Oasis.read_signed_integer([0x7e]) == 63
        @test Oasis.read_signed_integer([0x81, 0x01]) == -64
        @test Oasis.read_signed_integer([0xfe, 0x7f]) == 8191
        @test Oasis.read_signed_integer([0x81, 0x80, 0x01]) == -8192
    end
end