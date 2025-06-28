function read_and_reset(state, nbytes::Integer)
    l = state.buf[1:nbytes]
    state.pos = 1
    return l
end

@testset "Write data" begin
    @testset "Write bytes" begin
        state = OasisTools.WriterState("temp", 16)
        bytes = rand(UInt8, 16)
        OasisTools.write_bytes(state, bytes)
        @test state.pos == 1
        bytes = rand(UInt8, 17)
        OasisTools.write_bytes(state, bytes)
        @test state.pos == 2
        bytes = rand(UInt8, 174)
        OasisTools.write_bytes(state, bytes)
        @test state.pos == 16
    end
    @testset "Write unsigned integers" begin
        state = OasisTools.WriterState("temp", 1024 * 1024)
        OasisTools.wui(state, 0)
        @test read_and_reset(state, 1) == [0x00]
        OasisTools.wui(state, 127)
        @test read_and_reset(state, 1) == [0x7f]
        OasisTools.wui(state, 128)
        @test read_and_reset(state, 2) == [0x80, 0x01]
        OasisTools.wui(state, 16383)
        @test read_and_reset(state, 2) == [0xff, 0x7f]
        OasisTools.wui(state, 16384)
        @test read_and_reset(state, 3) == [0x80, 0x80, 0x01]
    end
    @testset "Write signed integers" begin
        state = OasisTools.WriterState("temp", 1024 * 1024)
        OasisTools.write_signed_integer(state, 0)
        @test read_and_reset(state, 1) == [0x00]
        OasisTools.write_signed_integer(state, 1)
        @test read_and_reset(state, 1) == [0x02]
        OasisTools.write_signed_integer(state, -1)
        @test read_and_reset(state, 1) == [0x03]
        OasisTools.write_signed_integer(state, 63)
        @test read_and_reset(state, 1) == [0x7e]
        OasisTools.write_signed_integer(state, -64)
        @test read_and_reset(state, 2) == [0x81, 0x01]
        OasisTools.write_signed_integer(state, 8191)
        @test read_and_reset(state, 2) == [0xfe, 0x7f]
        OasisTools.write_signed_integer(state, -8192)
        @test read_and_reset(state, 3) == [0x81, 0x80, 0x01]
    end
    @testset "Write reals" begin
        state = OasisTools.WriterState("temp", 1024 * 1024)
        OasisTools.write_real(state, 0.0)
        @test read_and_reset(state, 2) == [0x00, 0x00]
        OasisTools.write_real(state, 1.0)
        @test read_and_reset(state, 2) == [0x00, 0x01]
        OasisTools.write_real(state, -1.0)
        @test read_and_reset(state, 2) == [0x01, 0x01]
        OasisTools.write_real(state, -2/13)
        @test read_and_reset(state, 9) == [0x07, 0x14, 0x3b, 0xb1, 0x13, 0x3b, 0xb1, 0xc3, 0xbf]
    end
    @testset "Write string" begin
        state = OasisTools.WriterState("temp", 1024 * 1024)
        OasisTools.write_string(state, "abc")
        @test read_and_reset(state, 4) == [0x03, 0x61, 0x62, 0x63]
        OasisTools.write_string(state, "")
        @test read_and_reset(state, 1) == [0x00]
        @test_warn "Non-printable ASCII characters detected. Other software may not be able to read your output file." OasisTools.write_string(state, "↑")
    end
end
