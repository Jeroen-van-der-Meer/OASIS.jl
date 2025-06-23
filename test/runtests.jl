using GeometryBasics
using OasisTools
import OasisTools: ParserState
using Test
import Suppressor

@testset "Read data" begin
    @testset "Read unsigned integers" begin
        @test OasisTools.rui(ParserState([0x00])) == 0
        @test OasisTools.rui(ParserState([0x7f])) == 127
        @test OasisTools.rui(ParserState([0x80, 0x01])) == 128
        @test OasisTools.rui(ParserState([0xff, 0x7f])) == 16383
        @test OasisTools.rui(ParserState([0x80, 0x80, 0x01])) == 16384
    end
    @testset "Read signed integers" begin
        @test OasisTools.read_signed_integer(ParserState([0x00])) == 0
        @test OasisTools.read_signed_integer(ParserState([0x02])) == 1
        @test OasisTools.read_signed_integer(ParserState([0x03])) == -1
        @test OasisTools.read_signed_integer(ParserState([0x7e])) == 63
        @test OasisTools.read_signed_integer(ParserState([0x81, 0x01])) == -64
        @test OasisTools.read_signed_integer(ParserState([0xfe, 0x7f])) == 8191
        @test OasisTools.read_signed_integer(ParserState([0x81, 0x80, 0x01])) == -8192
    end
    @testset "Read reals" begin
        @test OasisTools.read_real(ParserState([0x00, 0x00])) == 0.0
        @test OasisTools.read_real(ParserState([0x00, 0x01])) == 1.0
        @test OasisTools.read_real(ParserState([0x03, 0x02])) == -0.5
        @test OasisTools.read_real(ParserState([0x04, 0x05, 0x10])) == 0.3125
        @test OasisTools.read_real(ParserState([0x02, 0x03])) == 1/3
        @test OasisTools.read_real(ParserState([0x05, 0x02, 0x0d])) == -2/13
        # In line below, LHS outputs Float64. Conversion to Float32 needed due to inherently
        # limited precision.
        @test OasisTools.read_real(ParserState([0x06, 0xd9, 0x89, 0x1d, 0xbe])) == Float32(-2/13)
        @test OasisTools.read_real(ParserState([0x07, 0x14, 0x3b, 0xb1, 0x13, 0x3b, 0xb1, 0xc3, 0xbf])) == -2/13
    end
    @testset "Read strings" begin
        @test OasisTools.read_string(ParserState([0x03, 0x61, 0x62, 0x63, 0x64])) == "abc"
        @test OasisTools.read_string(ParserState([0x00, 0xff])) == ""
    end
    @testset "Read 2-deltas" begin
        @test OasisTools.read_2_delta(ParserState([0x98, 0x2a])) == Point2i(1350, 0)
        @test OasisTools.read_2_delta(ParserState([0x9b, 0x2a])) == Point2i(0, -1350)
    end
    @testset "Read 3-deltas" begin
        @test OasisTools.read_3_delta(ParserState([0xcd, 0x01])) == Point2i(-25, 25)
        @test OasisTools.read_3_delta(ParserState([0xd7, 0x07])) == Point2i(122, -122)
    end
    @testset "Read g-deltas" begin
        @test OasisTools.read_g_delta(ParserState([0xe9, 0x03, 0x7a])) == Point2i(122, 61)
        @test OasisTools.read_g_delta(ParserState([0xec, 0x05])) == Point2i(-46, -46)
        @test OasisTools.read_g_delta(ParserState([0xbb, 0x01, 0xb7, 0x0f])) == Point2i(-46, -987)
    end
    @testset "Read point lists" begin
        @test OasisTools.read_point_list(ParserState([0x00, 0x04, 0x0c, 0x08, 0x11, 0x05])) ==
            Point2i[(0, 0), (6, 0), (0, 4), (-8, 0), (0, -2)]
        @test OasisTools.read_point_list(ParserState([0x01, 0x04, 0x11, 0x04, 0x04, 0x04])) ==
            Point2i[(0, 0), (0, -8), (2, 0), (0, 2), (2, 0)]
        @test OasisTools.read_point_list(ParserState([0x02, 0x05, 0x20, 0x19, 0x12, 0x0b, 0x12])) ==
            Point2i[(0, 0), (8, 0), (0, 6), (-4, 0), (0, -2), (-4, 0)]
        @test OasisTools.read_point_list(ParserState([0x03, 0x04, 0x15, 0x21, 0x30, 0x13])) ==
            Point2i[(0, 0), (-2, 2), (0, 4), (6, 0), (0, -2)]
        @test OasisTools.read_point_list(ParserState([0x04, 0x02, 0x44, 0x09, 0x0d])) ==
            Point2i[(0, 0), (-4, 0), (2, -6)]
        @test OasisTools.read_point_list(ParserState([
            0x05, 0x09, 0x01, 0x03, 0x29,
            0x00, 0x01, 0x04, 0x01, 0x03,
            0x01, 0x03, 0x2b, 0x04, 0x2b,
            0x00, 0x01, 0x03, 0x01, 0x03
        ])) == Point2i[
            (0, 0), (0, -1), (10, -1), (10, 1), (10, 0),
            (10, -1), (0, 1), (-10, 1), (-10, 0), (-10, -1)
        ]
    end
    @testset "Read repetitions" begin
        @test OasisTools.read_repetition(ParserState([0x00])) == 
            Point2i[] # Init value of modal variable
        @test OasisTools.read_repetition(ParserState([0x01, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 130, 129, (1, 0), (0, 1))
        @test OasisTools.read_repetition(ParserState([0x02, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 130, 1, (127, 0), (1, 1))
        @test OasisTools.read_repetition(ParserState([0x03, 0x80, 0x01, 0x7f, 0x01, 0x01])) ==
            PointGridRange((0, 0), 1, 130, (1, 1), (0, 127))
        @test OasisTools.read_repetition(ParserState([0x04, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (127, 0), (128, 0), (255, 0)]
        @test OasisTools.read_repetition(ParserState([0x05, 0x02, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (254, 0), (256, 0), (510, 0)]
        @test OasisTools.read_repetition(ParserState([0x06, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (0, 127), (0, 128), (0, 255)]
        @test OasisTools.read_repetition(ParserState([0x07, 0x02, 0x02, 0x7f, 0x01, 0x7f, 0x01])) ==
            Point2i[(0, 0), (0, 254), (0, 256), (0, 510)]
        @test OasisTools.read_repetition(ParserState([0x08, 0x80, 0x01, 0x7f, 0xe9, 0x03, 0x7a, 0xa0, 0x01])) ==
            PointGridRange((0, 0), 130, 129, (122, 61), (10, 0))
        @test OasisTools.read_repetition(ParserState([0x09, 0x01, 0xe9, 0x03, 0x7a])) ==
            PointGridRange((0, 0), 3, 1, (122, 61), (1, 1))
        @test OasisTools.read_repetition(ParserState([0x0a, 0x01, 0xe9, 0x03, 0x7a, 0xe9, 0x03, 0x7a])) ==
            Point2i[(0, 0), (122, 61), (244, 122)]
        @test OasisTools.read_repetition(ParserState([0x0b, 0x01, 0x02, 0xe9, 0x03, 0x7a, 0xe9, 0x03, 0x7a])) ==
            Point2i[(0, 0), (244, 122), (488, 244)]
    end
    @testset "Intervals" begin
        @test OasisTools.read_interval(ParserState([0x00, 0x80, 0x01, 0x80, 0x02])) == OasisTools.Interval(0, typemax(UInt64))
        @test OasisTools.read_interval(ParserState([0x01, 0x80, 0x01, 0x80, 0x02])) == OasisTools.Interval(0, 128)
        @test OasisTools.read_interval(ParserState([0x02, 0x80, 0x01, 0x80, 0x02])) == OasisTools.Interval(128, typemax(UInt64))
        @test OasisTools.read_interval(ParserState([0x03, 0x80, 0x01, 0x80, 0x02])) == OasisTools.Interval(128, 128)
        @test OasisTools.read_interval(ParserState([0x04, 0x80, 0x01, 0x80, 0x02])) == OasisTools.Interval(128, 256)
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
    @testset "Polygon" begin
        # Contains: Polygon with four vertices.
        filename = "polygon.oas" # 130.900 μs (86 allocations: 4.84 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        ncell = length(oas.cells)
        @test ncell == 1
        top_cell = oas.cells[1]
        cellname = OasisTools.find_reference(top_cell.nameNumber, oas.references.cellNames)
        @test cellname == "TOP"
        subcells = top_cell.cells
        @test isempty(subcells)
        shapes = top_cell.shapes
        @test length(shapes) == 1
        polygon = top_cell.shapes[1].shape
        @test polygon isa Polygon
        @test polygon.exterior == [
            Point{2, Int64}(-1000, -1000), Point{2, Int64}(-1000, 0),
            Point{2, Int64}(0, 1000), Point{2, Int64}(0, 0)
        ]
    end
    @testset "Boxes" begin
        # Contains: Two layers, cell placement with repetition, rectangles.
        filename = "boxes.oas" # 146.900 μs (146 allocations: 149.76 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        ncell = length(oas.cells)
        @test ncell == 2
        bottom_cell = oas.cells[1]
        cellname = OasisTools.find_reference(bottom_cell.nameNumber, oas.references.cellNames)
        @test cellname == "BOTTOM"
        @test length(oas.cells[1].shapes) == 1
        rectangle = oas.cells[1].shapes[1]
        layer_number = rectangle.layerNumber
        datatype_number = rectangle.datatypeNumber
        layername = OasisTools.find_reference(layer_number, datatype_number, oas.references.layerNames)
        @test layername == "TOP"
        rectangle_shape = rectangle.shape
        @test rectangle_shape isa HyperRectangle{2, Int64}
        @test rectangle_shape == HyperRectangle{2, Int64}(
            Point{2, Int64}(-190, 2870),
            Point{2, Int64}(-180, 2880)
        )
        top_cell = oas.cells[2]
        cellname = OasisTools.find_reference(top_cell.nameNumber, oas.references.cellNames)
        @test cellname == "TOP"
        placements = top_cell.cells
        @test length(placements) == 2
        # There are two placements in the top cell rather than one. Underneath the 6x5 grid of
        # rectangles, there's another rectangle.
        bottom_cell_placement = placements[1]
        @test bottom_cell_placement.location == Point{2, Int64}(-520, 2200)
        # FIXME: Check the placement is correct, esp. the rotation
        @test bottom_cell_placement.rotation == 180
        @test bottom_cell_placement.repetition == PointGridRange((0, 0), 6, 5, (0, 30), (50, -30))
    end
    @testset "Circle" begin
        # Contains: Circle (which klayout doesn't save as a circle), text.
        filename = "circle.oas" # 156.600 μs (169 allocations: 223.48 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        ncell = length(oas.cells)
        @test ncell == 2
        circle_cell = oas.cells[1]
        circle = circle_cell.shapes[1]
        @test circle isa Shape{Polygon{2, Int64}}
        text_cell = oas.cells[2]
        text = text_cell.shapes[1]
        text_string = OasisTools.find_reference(text.shape.textNumber, oas.references.textStrings)
        @test text_string == "This is not a circle"
    end
    @testset "Paths" begin
        # Contains: Some paths. It includes one with rounded ends. Weirdly enough, klayout
        # chooses to save these ends as CIRCLE records, unlike actual circles.
        filename = "paths.oas" # 143.800 μs (120 allocations: 77.43 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        ncell = length(oas.cells)
        @test ncell == 1
        top_cell = oas.cells[1]
        nplacement = length(top_cell.cells)
        @test nplacement == 0
        shapes = [s.shape for s in top_cell.shapes]
        @test length(shapes) == 6 # Four paths and two circles for the rounded path
        path_1 = shapes[1]
        @test path_1.points == Point{2, Int64}[(-508, 268), (-253, 22), (-342, 190), (-157, 176)]
        @test path_1.width == 100
        path_2 = shapes[2]
        @test path_2.points == Point{2, Int64}[(-263, 431), (-116, 420), (-228, 315), (-182, 482)]
        @test path_2.width == 50
        # Third path is a rounded path which klayout saves using CIRCLE records at both ends.
        path_3 = shapes[3]
        @test path_3.points == Point{2, Int64}[(-343, 273), (-386, 294), (-351, 303)]
        @test path_3.width == 10
        start_circle = shapes[4]
        @test start_circle.center == Point{2, Int64}(-343, 273)
        @test start_circle.r == 5
        end_circle = shapes[5]
        @test end_circle.center == Point{2, Int64}(-351, 303)
        @test end_circle.r == 5
        # Fourth path is subject to change; due to the nonzero starting offset, its starting
        # point is actually a fraction of the database unit. As it stands, a rounding takes
        # place.
        path_4 = shapes[6]
        @test path_4.points == Point{2, Int64}[(-257, 236), (-255, 238), (-254, 237)]
        @test path_4.width == 2
    end
    @testset "Nested" begin
        # Contains: A bunch of cells with random shapes nested in each other with varying
        # rotations and magnifications.
        filename = "nested.oas" # 161.300 μs (232 allocations: 225.47 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        s = Suppressor.@capture_out show_cells(oas)
        @test s == """
TOP
├─ BOTTOM2 (3×)
│  └─ ROCKBOTTOM
├─ MIDDLE2
│  └─ BOTTOM (2×)
└─ MIDDLE
   ├─ BOTTOM2 (2×)
   │  └─ ROCKBOTTOM
   └─ BOTTOM"""
        s = Suppressor.@capture_out Base.show(oas)
        @test s == """
OASIS file v1.0 with the following cells: 
TOP
├─ BOTTOM2 (3×)
│  └─ ROCKBOTTOM
├─ MIDDLE2
│  └─ BOTTOM (2×)
└─ MIDDLE
   ├─ BOTTOM2 (2×)
   │  └─ ⋯
   └─ BOTTOM"""
    end
end
