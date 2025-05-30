skip_record(::IO) = return

function parse_start(io::IO)
    version = VersionNumber(read_string(io))
    oas.metadata.version = version
    unit = read_real(io)
    oas.metadata.unit = 1e6 / unit
    offset_flag = rui(io)
    if iszero(offset_flag)
        # We ignore the 12 integers corresponding to the table offset structure.
        for _ in 1:12
            rui(io)
        end
    end
end

function parse_cellname_impl(io::IO)
    cellname = read_string(io)
    cellname_number = length(oas.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(oas.references.cellNames, reference)
end

parse_propname_impl(io::IO) = read_string(io)

parse_propstring_impl(io::IO) = read_string(io)

function parse_layername(io::IO)
    layername = read_string(io)
    layer_interval = read_interval(io)
    datatype_interval = read_interval(io)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(oas.references.layerNames, layer_reference)
end

function parse_textlayername(io::IO)
    layername = read_string(io)
    layer_interval = read_interval(io)
    datatype_interval = read_interval(io)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(oas.references.textLayerNames, layer_reference)
end

function is_end_of_cell(next_record::UInt8)
    # The end of a cell is implied when the upcoming record is any of the following:
    # END, CELLNAME, TEXTSTRING, PROPNAME, PROPSTRING, LAYERNAME, CELL, XNAME
    return (0x02 <= next_record <= 0x0e) || (next_record == 0x1e) || (next_record == 0x1f)
end
function parse_cell_ref(io::IO)
    # The reason we look ahead one byte is because we cannot tell in advance when the CELL
    # record ends. If it ends, this function will likely return to the main parser which also
    # needs to read a byte to find the next record.
    cellname_number = rui(io)
    global cell = Cell([], [], cellname_number)
    while true
        record_type = peek(io, UInt8)
        is_end_of_cell(record_type) ? break : read(io, UInt8)
        RECORD_PARSER_PER_TYPE[record_type + 1](io)
    end
    push!(oas.cells, cell)
end

function parse_xyabsolute(::IO)
    modals.xyAbsolute = true
end

function parse_xyrelative(::IO)
    modals.xyAbsolute = false
end

# PLACEMENT records can either use CELLNAME references or strings to refer to what cell is being
# placed. For consistency, we wish to always log a reference number. However, there is no
# guarantee that such reference exists, so we'll have to manually create it.
function cellname_to_cellname_number(cellname::String)
    cellname_number = find_reference(number, oas.references.cellNames)
    if isnothing(cellname_number)
        cellname_number = rand(UInt64)
        push!(oas.references.cellNames, NumericReference(cellname, cellname_number))
    end
end

function parse_placement(io::IO)
    info_byte = read(io, UInt8)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(io)
        else
            cellname = read_string(io)
            cellname_number = cellname_to_cellname_number(cellname)
            # If a string is used to denote the cellname, find the corresponding reference. If
            # no such reference exists (yet?), create a random one ourselves.
        end
    else
        cellname = modals.placementCell
        if cellname isa String
            cellname_number = cellname_to_cellname_number(cellname)
        else
            cellname_number = cellname
        end
    end
    x = read_or_modal(io, read_signed_integer, :placementX, info_byte, 3)
    y = read_or_modal(io, read_signed_integer, :placementY, info_byte, 4)
    location = Point{2, Int64}(x, y)
    rotation = ((info_byte >> 1) & 0x03) * 90
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 5)
    placement = CellPlacement(cellname_number, location, rotation, 1.0, repetition)
    push!(cell.cells, placement)
end

function parse_rectangle(io::IO)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    width = read_or_modal(io, read_signed_integer, :geometryW, info_byte, 2)
    height = read_or_modal(io, read_signed_integer, :geometryH, info_byte, 3)
    x = read_or_modal(io, read_signed_integer, :geometryX, info_byte, 4)
    y = read_or_modal(io, read_signed_integer, :geometryY, info_byte, 5)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    lower_left_corner = Point{2, Int64}(x, y)
    upper_right_corner = Point{2, Int64}(x + width, y + height)
    rectangle = HyperRectangle{2, Int64}(lower_left_corner, upper_right_corner)
    shape = Shape(rectangle, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_polygon(io::IO)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    point_list = read_or_modal(io, read_point_list, :polygonPointList, info_byte, 3)
    x = read_or_modal(io, read_signed_integer, :geometryX, info_byte, 4)
    y = read_or_modal(io, read_signed_integer, :geometryY, info_byte, 5)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    point_list .+= Point{2, Int64}(x, y)
    polygon = Polygon(point_list)
    shape = Shape(polygon, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_property(io::IO)
    # We ignore properties. The code here is only meant to figure out how many bytes to skip.
    info_byte = read(io, UInt8)
    propname_explicit = bit_is_nonzero(info_byte, 6)
    if propname_explicit
        propname_as_reference = bit_is_nonzero(info_byte, 7)
        if propname_as_reference
            rui(io)
        else
            read_string(io)
        end
    end
    value_list_implicit = bit_is_nonzero(info_byte, 5)
    if !value_list_implicit
        number_of_values = info_byte >> 4
        if number_of_values == 0x0f
            number_of_values = rui(io)
        end
        for _ in 1:number_of_values
            read_property_value(io)
        end
    end
end

function parse_cblock(io::IO)
    comp_type = rui(io)
    @assert comp_type == 0x00 "Unknown compression type encountered"
    uncomp_byte_count = rui(io)
    comp_byte_count = rui(io)
    
    cblock_buffer = IOBuffer(read(io, comp_byte_count))
    io_decompress = DeflateDecompressorStream(cblock_buffer)

    while !eof(io_decompress)
        record_type = read(io_decompress, UInt8)
        RECORD_PARSER_PER_TYPE[record_type + 1](io_decompress)
    end
    close(io_decompress)
end

const RECORD_PARSER_PER_TYPE = (
    skip_record, # PAD (0)
    parse_start, # START (1)
    skip_record, # END (2)
    parse_cellname_impl, # CELLNAME (3)
    skip_record, #parse_cellname_ref, # CELLNAME (4)
    skip_record, #parse_textstring_impl, # TEXTSTRING (5)
    skip_record, #parse_textstring_ref, # TEXTSTRING (6) 
    parse_propname_impl, # PROPNAME (7)
    skip_record, #parse_propname_ref, # PROPNAME (8)
    parse_propstring_impl, # PROPSTRING (9)
    skip_record, #parse_propstring_ref, # PROPSTRING (10)
    parse_layername, # LAYERNAME (11)
    parse_textlayername, # LAYERNAME (12)
    parse_cell_ref, # CELL (13)
    skip_record, #parse_cell_str, # CELL (14)
    parse_xyabsolute, # XYABSOLUTE (15)
    parse_xyrelative, # XYRELATIVE (16)
    parse_placement, # PLACEMENT (17)
    skip_record, #parse_placement_mag_angle, # PLACEMENT (18)
    skip_record, #parse_text, # TEXT (19)
    parse_rectangle, #parse_rectangle, # RECTANGLE (20)
    parse_polygon, # POLYGON (21)
    skip_record, #parse_path, # PATH (22)
    skip_record, #parse_trapezoid_ab, # TRAPEZOID (23)
    skip_record, #parse_trapezoid_a, # TRAPEZOID (24)
    skip_record, #parse_trapezoid_b, # TRAPEZOID (25)
    skip_record, #parse_ctrapezoid, # CTRAPEZOID (26)
    skip_record, #parse_circle, # CIRCLE (27)
    parse_property, # PROPERTY (28)
    skip_record, #parse_modal_property, # PROPERTY (29)
    skip_record, #parse_xname_impl, # XNAME (30)
    skip_record, #parse_xname_ref, # XNAME (31)
    skip_record, #parse_xelement, # XELEMENT (32)
    skip_record, #parse_xgeometry, # XGEOMETRY (33)
    parse_cblock # CBLOCK (34)
)
