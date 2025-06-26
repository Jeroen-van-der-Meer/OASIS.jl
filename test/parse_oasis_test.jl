@testset "Parse OASIS files" begin
    @testset "Polygon" begin
        # Contains: Polygon with four vertices.
        filename = "polygon.oas" # 130.900 μs (86 allocations: 4.84 KiB)
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        ncell = length(oas.cells)
        @test ncell == 1
        top_cell = oas.cells[0]
        cellname = OasisTools.find_reference(0, oas.references.cellNames)
        @test cellname == "TOP"
        subcells = top_cell.placements
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
        bottom_cell_number = cell_number(oas, "BOTTOM")
        bottom_cell = oas.cells[bottom_cell_number]
        cellname = OasisTools.find_reference(bottom_cell_number, oas.references.cellNames)
        @test cellname == "BOTTOM"
        @test length(bottom_cell.shapes) == 1
        rectangle = bottom_cell.shapes[1]
        layer_number = rectangle.layerNumber
        datatype_number = rectangle.datatypeNumber
        layername = OasisTools.find_reference(layer_number, datatype_number, oas.references.layerNames)
        @test layername == "TOP"
        rectangle_shape = rectangle.shape
        @test rectangle_shape isa Rect{2, Int64}
        @test rectangle_shape == Rect{2, Int64}(
            Point{2, Int64}(-190, 2870),
            Point{2, Int64}(10, 10)
        )
        top_cell_number = cell_number(oas, "TOP")
        @test top_cell_number == 0
        top_cell = oas.cells[top_cell_number]
        cellname = OasisTools.find_reference(top_cell_number, oas.references.cellNames)
        @test cellname == "TOP"
        top_shape = shapes(oas["TOP"])[1]
        @test top_shape isa Shape{Rect{2, Int64}}
        s = Suppressor.@capture_out Base.show(top_shape)
        # Note that the coordinates do not account for the repetition.
        @test s == "Rectangle in layer (1/1) at (-160, -710) (4×)"
        p = placements(top_cell)
        @test length(p) == 2
        # There are two placements in the top cell rather than one. Underneath the 6x5 grid of
        # rectangles, there's another rectangle.
        bottom_cell_placement = p[1]
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
        circle_cell = oas["CIRCLE\$1"]
        circle = circle_cell.shapes[1]
        @test circle isa Shape{Polygon{2, Int64}}
        text_cell = oas["TOP"]
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
        top_cell = oas["TOP"]
        nplacement = length(top_cell.placements)
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
├─ BOTTOM2 (4×)
│  └─ ROCKBOTTOM
├─ MIDDLE2
│  └─ BOTTOM (5×)
└─ MIDDLE (3×)
   ├─ BOTTOM2 (4×)
   │  └─ ROCKBOTTOM
   └─ BOTTOM (2×)"""
        s = Suppressor.@capture_out Base.show(oas)
        @test s == """
OASIS file v1.0 with the following cells:
TOP
├─ BOTTOM2 (4×)
│  └─ ROCKBOTTOM
├─ MIDDLE2
│  └─ BOTTOM (5×)
└─ MIDDLE (3×)
   ├─ BOTTOM2 (4×)
   │  └─ ⋯
   └─ BOTTOM (2×)"""
        s = Suppressor.@capture_out Base.show(oas["ROCKBOTTOM"].shapes[1])
        @test s == "Polygon in layer (1/0) at (1, 0)"
        s = Suppressor.@capture_out Base.show(oas["BOTTOM2"].placements[1])
        @test s == "Placement of cell 6 at (1, 0)"
        s = Suppressor.@capture_out Base.show(oas["MIDDLE2"].placements[1])
        @test s == "Placement of cell 3 at (-5, -3) (2×)"
        bottom = oas["BOTTOM"]
        @test length(bottom.shapes) == 1
        bottom2 = oas["BOTTOM2"]
        @test length(bottom2.placements) == 1
        @test length(bottom2.shapes) == 1
        placement = bottom2.placements[1]
        @test placement.rotation == 90
        @test placement.magnification == 0.5
        @test placement.location == Point{2, Int64}(1, 0)
        shape = bottom2.shapes[1].shape
        @test shape == Rect{2, Int64}([0, 0], [1, 1])
        middle2 = oas["MIDDLE2"]
        @test length(middle2.placements) == 2
        placement1 = middle2.placements[1]
        @test placement1.location == Point{2, Int64}(-5, -3)
        @test placement1.magnification == 1
        @test placement1.rotation == 0
        @test placement1.repetition == Point{2, Int64}[(0, 0), (2, 0)]
        placement2 = middle2.placements[2]
        @test placement2.location == Point{2, Int64}(-3, -1)
        @test placement2.magnification == 2
        @test placement2.rotation == 180
        @test placement2.repetition == Point{2, Int64}[(0, 0), (2, 0), (4, 0)]
    end
    @testset "Trapezoids" begin
        # Contains: Trapezoids and ctrapezoids. Made with LayoutEditor because klayout doesn't
        # use TRAPEZOID and CTRAPEZOID records.
        # Some interesting quirks specific to LayoutEditor's way of saving files:
        #  - It does not seem to use references for strings (at least not when used only once).
        #  - It contains the following stingy message, which they actually insert into the layout:
        #    "Generated with the LayoutEditor (This message will NOT be added by any commercial
        #     version of the LayoutEditor.)"
        #    Surely they know you can just manually delete the text record from the file...?
        filename = "trapezoids.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        cell = oas["noname"] # This is what LayoutEditor calls your cell if you don't name it.
        @test length(cell.shapes) == 7 # Six polygons and the free-version disclaimer.
        @test cell.shapes[1] isa Shape{OasisTools.Text}
        polygon1 = cell.shapes[2]
        @test polygon1.shape.exterior == [
            Point{2, Int64}(28810, -17702), Point{2, Int64}(28813, -17703),
            Point{2, Int64}(28813, -17698), Point{2, Int64}(28810, -17696)
        ]
        polygon2 = cell.shapes[3]
        @test polygon2.shape.exterior == [
            Point{2, Int64}(28796, -17701), Point{2, Int64}(28796, -17705),
            Point{2, Int64}(28800, -17705), Point{2, Int64}(28803, -17701)
        ]
        polygon3 = cell.shapes[4]
        @test polygon3.shape.exterior == [
            Point{2, Int64}(28805, -17705), Point{2, Int64}(28807, -17703),
            Point{2, Int64}(28807, -17698), Point{2, Int64}(28805, -17700)
        ]
        polygon4 = cell.shapes[5]
        @test polygon4.shape.exterior == [
            Point{2, Int64}(28800, -17707), Point{2, Int64}(28799, -17710),
            Point{2, Int64}(28806, -17710), Point{2, Int64}(28805, -17707)
        ]
        polygon5 = cell.shapes[6]
        @test polygon5.shape.exterior == [
            Point{2, Int64}(28809, -17704), Point{2, Int64}(28810, -17706),
            Point{2, Int64}(28814, -17706), Point{2, Int64}(28813, -17704)
        ]
        polygon6 = cell.shapes[7]
        @test polygon6.shape.exterior == [
            Point{2, Int64}(28794, -17696), Point{2, Int64}(28797, -17699),
            Point{2, Int64}(28801, -17699), Point{2, Int64}(28802, -17696)
        ]
    end
    @testset "Two top cells" begin
        # Contains: A file containing two cells that aren't contained in each other.
        filename = "topcells.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        s = Suppressor.@capture_out Base.show(oas)
        @test s == """
OASIS file v1.0 with the following cells:
TOP
OTHERTOP"""
        s = Suppressor.@capture_out show_cells(oas, "TOP")
        @test s == "TOP"
    end
    @testset "Flipped" begin
        # Contains: A cell placement which is flipped around the x-axis.
        filename = "flipped.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath)
        @test oas isa Oasis
        cell = oas["TOP"]
        placement1 = placements(cell)[1]
        @test placement1.rotation == 10
        @test placement1.flipped == false
        placement2 = placements(cell)[2]
        @test placement2.rotation == 10
        @test placement2.flipped == true
    end
end

@testset "Lazy OASIS files" begin
    @testset "Polygon" begin
        filename = "polygon.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
        @test cells(oas) isa Dict{UInt64, LazyCell}
        cell = oas["TOP"]
        @test cell isa LazyCell
        @test cell.byte == 160
        @test cell.placements == Dict{UInt64, Int64}()
    end
    @testset "Boxes" begin
        filename = "boxes.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
        s = Suppressor.@capture_out Base.show(oas)
        @test s == """
Lazy OASIS file v1.0 with the following cells:
TOP
└─ BOTTOM (31×)"""
        top_cell = oas["TOP"]
        @test top_cell.byte == 161
        bottom_cell = oas["BOTTOM"]
        @test bottom_cell.byte == 150
    end
    @testset "Circle" begin
        filename = "circle.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
    end
    @testset "Paths" begin
        filename = "paths.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
    end
    @testset "Nested" begin
        filename = "nested.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
    end
    @testset "Trapezoids" begin
        filename = "trapezoids.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
    end
    @testset "Two top cells" begin
        filename = "topcells.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
        s = Suppressor.@capture_out Base.show(oas)
        @test s == """
Lazy OASIS file v1.0 with the following cells:
TOP
OTHERTOP"""
        @test oas["TOP"] isa LazyCell
        @test oas["OTHERTOP"] isa LazyCell
    end
    @testset "Flipped" begin
        filename = "flipped.oas"
        filepath = joinpath(@__DIR__, "testdata", filename)
        oas = oasisread(filepath; lazy = true)
        @test oas isa LazyOasis
    end
end
