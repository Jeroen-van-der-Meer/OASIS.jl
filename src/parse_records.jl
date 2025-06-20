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
            skip_integer(io)
        end
    end
end

function parse_cellname_impl(io::IO)
    cellname = read_string(io)
    cellname_number = length(oas.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(oas.references.cellNames, reference)
end

function parse_cellname_ref(io::IO)
    cellname = read_string(io)
    cellname_number = rui(io)
    reference = NumericReference(cellname, cellname_number)
    push!(oas.references.cellNames, reference)
end

function parse_textstring_impl(io::IO)
    textstring = read_string(io)
    textstring_number = length(oas.references.textStrings)
    reference = NumericReference(textstring, textstring_number)
    push!(oas.references.textStrings, reference)
end

function parse_textstring_ref(io::IO)
    textstring = read_string(io)
    textstring_number = rui(io)
    reference = NumericReference(textstring, textstring_number)
    push!(oas.references.textStrings, reference)
end

function parse_propname_impl(io::IO)
    skip_string(io)
end

function parse_propname_ref(io::IO)
    skip_string(io)
    skip_integer(io)
end

function parse_propstring_impl(io::IO)
    skip_string(io)
end

function parse_propstring_ref(io::IO)
    skip_string(io)
    skip_integer(io)
end

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

function parse_cell(io::IO)
    while true
        # The reason we look ahead one byte is because we cannot tell in advance when the CELL
        # record ends. If it ends, this function will likely return to the main parser which
        # also needs to read a byte to find the next record.
        record_type = peek(io, UInt8)
        is_end_of_cell(record_type) ? break : skip(io, 1)
        RECORD_PARSER_PER_TYPE[record_type + 1](io)
    end

end

function parse_cell_ref(io::IO)
    # Whenever a cell is encountered, the following modal variables are reset.
    modals.xyAbsolute = true
    modals.placementX = 0
    modals.placementY = 0
    modals.geometryX = 0
    modals.geometryY = 0
    modals.textX = 0
    modals.textY = 0

    cellname_number = rui(io)
    global cell = Cell([], [], cellname_number)
    parse_cell(io)
    push!(oas.cells, cell)
end

function parse_cell_str(io::IO)
    cellname_string = read_string(io)
    cellname_number = cellname_to_cellname_number(cellname)
    global cell = Cell([], [], cellname_number)
    parse_cell(io)
    push!(oas.cells, cell)
end

function parse_xyabsolute(::IO)
    modals.xyAbsolute = true
end

function parse_xyrelative(::IO)
    modals.xyAbsolute = false
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
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        modals.placementCell = cellname_number
    else
        cellname_number = modals.placementCell
    end
    x, y = read_or_modal_xy(io, :placementX, :placementY, info_byte, 3)
    location = Point{2, Int64}(x, y)
    rotation = ((info_byte >> 1) & 0x03) * 90
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 5)
    placement = CellPlacement(cellname_number, location, rotation, 1.0, repetition)
    push!(cell.cells, placement)
end

function parse_placement_mag_angle(io::IO)
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
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        modals.placementCell = cellname_number
    else
        cellname_number = modals.placementCell
    end
    if bit_is_nonzero(info_byte, 6)
        magnification = read_real(io)
    else
        magnification = 1.0
    end
    if bit_is_nonzero(info_byte, 7)
        rotation = read_real(io)
    else
        rotation = 0.0
    end
    x, y = read_or_modal_xy(io, :placementX, :placementY, info_byte, 3)
    location = Point{2, Int64}(x, y)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 5)
    placement = CellPlacement(cellname_number, location, rotation, magnification, repetition)
    push!(cell.cells, placement)
end

function parse_text(io::IO)
    info_byte = read(io, UInt8)
    text_explicit = bit_is_nonzero(info_byte, 2)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 3)
        if text_as_ref
            text_number = rui(io)
        else
            text = read_string(io)
            text_number = cellname_to_cellname_number(text)
            # If a string is used to denote the cellname, find the corresponding reference. If
            # no such reference exists (yet?), create a random one ourselves.
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        modals.textString = text_number
    else
        text_number = modals.textString
    end
    textlayer_number = read_or_modal(io, rui, :textlayer, info_byte, 8)
    texttype_number = read_or_modal(io, rui, :texttype, info_byte, 7)
    x, y = read_or_modal_xy(io, :textX, :textY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    text = Text(text_number, Point{2, Int64}(x, y), repetition)
    shape = Shape(text, textlayer_number, texttype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_rectangle(io::IO)
    info_byte = read(io, UInt8)
    is_square = bit_is_nonzero(info_byte, 1)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    width = signed(read_or_modal(io, rui, :geometryW, info_byte, 2))
    if is_square
        # If rectangle is a square, the height is necessarily not logged, and the modal
        # geometryH is set to the width.
        height = width
        modals.geometryH = width
    else
        height = signed(read_or_modal(io, rui, :geometryH, info_byte, 3))
    end
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
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
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    pushfirst!(point_list, Point{2, Int64}(0, 0))
    cumsum!(point_list, point_list)
    point_list .+= Point{2, Int64}(x, y)
    polygon = Polygon(point_list)
    shape = Shape(polygon, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_path(io::IO)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    halfwidth = read_or_modal(io, rui, :pathHalfwidth, info_byte, 2)
    extension_scheme_present = bit_is_nonzero(info_byte, 1)
    if extension_scheme_present
        extension_scheme = read(io, UInt8)
        SS_bits = (extension_scheme >> 2) & 0x03
        if SS_bits == 0x00
            start_extension = modals.pathStartExtension
            modals.pathStartExtension = start_extension
        elseif SS_bits == 0x01
            start_extension = 0
            modals.pathStartExtension = start_extension
        elseif SS_bits == 0x02
            start_extension = halfwidth
            modals.pathStartExtension = start_extension
        else
            start_extension = read_signed_integer(io)
        end
        EE_bits = extension_scheme & 0x03
        if EE_bits == 0x00
            end_extension = modals.pathEndExtension
            modals.pathEndExtension = end_extension
        elseif EE_bits == 0x01
            end_extension = 0
            modals.pathEndExtension = end_extension
        elseif EE_bits == 0x02
            end_extension = halfwidth
            modals.pathEndExtension = end_extension
        else
            end_extension = read_signed_integer(io)
        end
    else
        start_extension = modals.pathStartExtension
        end_extension = modals.pathEndExtension
    end
    point_list = read_or_modal(io, read_point_list, :pathPointList, info_byte, 3)
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    # Adjust point list based on start and end extension so that we don't have to log these
    # parameters. The unfortunate downside is that there's no guarantee that the resulting point
    # list will properly snap within the specified grid, and as such rounding errors may occur.
    # That said, I cannot imagine this setting is used often in practice.
    if !iszero(start_extension)
        first_delta = first(point_list)
        first_delta_normalized = first_delta ./ sqrt(first_delta[1]^2 + first_delta[2]^2)
        adjustment_for_start = first_delta_normalized * start_extension
        adjustment_for_start_rounded = round.(Int64, adjustment_for_start)
        point_list[1] += adjustment_for_start_rounded
        x -= adjustment_for_start_rounded[1]
        y -= adjustment_for_start_rounded[2]
    end
    if !iszero(end_extension)
        last_delta = last(point_list)
        last_delta_normalized = last_delta ./ sqrt(last_delta[1]^2 + last_delta[2]^2)
        adjustment_for_end = last_delta_normalized * end_extension
        adjustment_for_end_rounded = round.(Int64, adjustment_for_end)
        point_list[end] += adjustment_for_end_rounded
    end
    pushfirst!(point_list, Point{2, Int64}(0, 0))
    cumsum!(point_list, point_list)
    point_list .+= Point{2, Int64}(x, y)
    path = Path(point_list, 2 * signed(halfwidth))
    shape = Shape(path, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_trapezoid(io::IO, delta_a_explicit::Bool, delta_b_explicit::Bool)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    width = read_or_modal(io, rui, :geometryW, info_byte, 2)
    height = read_or_modal(io, rui, :geometryH, info_byte, 3)
    if delta_a_explicit
        # The spec indicates that delta-a and delta-b are 1-deltas. These are merely signed
        # integers with an implied direction. We choose to incorporate the directionality when
        # assembling the vertices.
        delta_a = read_signed_integer(io)
    else
        delta_a = 0
    end
    if delta_b_explicit
        delta_b = read_signed_integer(io)
    else
        delta_b = 0
    end
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    if bit_is_nonzero(info_byte, 1) # Vertical orientation
        vertices = [
            Point{2, Int64}(0, 0),
            Point{2, Int64}(width, delta_a),
            Point{2, Int64}(width, height - delta_b),
            Point{2, Int64}(0, h)
        ]
    else # Horizontal orientation
        vertices = [
            Point{2, Int64}(0, h),
            Point{2, Int64}(delta_a, 0),
            Point{2, Int64}(width - delta_b, 0),
            Point{2, Int64}(width, height)
        ]
    end
    vertices .+= Point{2, Int64}(x, y)
    trapezoid = Polygon(vertices)
    shape = Shape(trapezoid, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_trapezoid_ab(io::IO)
    parse_trapezoid(io, true, true)
end

function parse_trapezoid_a(io::IO)
    parse_trapezoid(io, true, false)
end

function parse_trapezoid_b(io::IO)
    parse_trapezoid(io, false, true)
end

ctrapezoid_vertices_0(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(w - h, h),  Point{2, Int64}(0, h)]
ctrapezoid_vertices_1(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w - h, 0),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h)]
ctrapezoid_vertices_2(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(0, w),
    Point{2, Int64}(w, h),      Point{2, Int64}(h, h)]
ctrapezoid_vertices_3(w::UInt64, h::UInt64) = [
    Point{2, Int64}(h, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h)]
ctrapezoid_vertices_4(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(w - h, h),  Point{2, Int64}(h, h)]
ctrapezoid_vertices_5(w::UInt64, h::UInt64) = [
    Point{2, Int64}(h, 0),      Point{2, Int64}(w - h, 0),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h)]
ctrapezoid_vertices_6(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w - h, 0),
    Point{2, Int64}(w, h),      Point{2, Int64}(h, h)]
ctrapezoid_vertices_7(w::UInt64, h::UInt64) = [
    Point{2, Int64}(h, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(w - h, h),  Point{2, Int64}(0, h)]
ctrapezoid_vertices_8(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(0, w),
    Point{2, Int64}(w, h - w),  Point{2, Int64}(0, h)]
ctrapezoid_vertices_9(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(0, w),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h - w)]
ctrapezoid_vertices_10(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h)]
ctrapezoid_vertices_11(w::UInt64, h::UInt64) = [
    Point{2, Int64}(w, 0),      Point{2, Int64}(w, h),
    Point{2, Int64}(0, h),      Point{2, Int64}(0, h - w)]
ctrapezoid_vertices_12(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(w, h - w),  Point{2, Int64}(0, h)]
ctrapezoid_vertices_13(w::UInt64, h::UInt64) = [
    Point{2, Int64}(w, 0),      Point{2, Int64}(w, h),
    Point{2, Int64}(0, h - w),  Point{2, Int64}(0, w)]
ctrapezoid_vertices_14(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(w, h),      Point{2, Int64}(0, h - w)]
ctrapezoid_vertices_15(w::UInt64, h::UInt64) = [
    Point{2, Int64}(w, 0),      Point{2, Int64}(w, h - w),
    Point{2, Int64}(0, h),      Point{2, Int64}(0, w)]
ctrapezoid_vertices_16(w::UInt64, ::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(0, w)]
ctrapezoid_vertices_17(w::UInt64, ::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(0, w)]
ctrapezoid_vertices_18(w::UInt64, ::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, 0),
    Point{2, Int64}(w, w)]
ctrapezoid_vertices_19(w::UInt64, ::UInt64) = [
    Point{2, Int64}(w, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(0, w)]
ctrapezoid_vertices_20(::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(2h, 0),
    Point{2, Int64}(h, h)]
ctrapezoid_vertices_21(::UInt64, h::UInt64) = [
    Point{2, Int64}(h, 0),      Point{2, Int64}(2h, h),
    Point{2, Int64}(0, h)]
ctrapezoid_vertices_22(w::UInt64, ::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w),
    Point{2, Int64}(0, 2w)]
ctrapezoid_vertices_23(w::UInt64, ::UInt64) = [
    Point{2, Int64}(w, 0),      Point{2, Int64}(w, 2w),
    Point{2, Int64}(0, w)]
ctrapezoid_vertices_24(w::UInt64, h::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, h)]
ctrapezoid_vertices_25(w::UInt64, ::UInt64) = [
    Point{2, Int64}(0, 0),      Point{2, Int64}(w, w)]

const CTRAPEZOID_VERTICES_PER_TYPE = (
    ctrapezoid_vertices_0,
    ctrapezoid_vertices_1,
    ctrapezoid_vertices_2,
    ctrapezoid_vertices_3,
    ctrapezoid_vertices_4,
    ctrapezoid_vertices_5,
    ctrapezoid_vertices_6,
    ctrapezoid_vertices_7,
    ctrapezoid_vertices_8,
    ctrapezoid_vertices_9,
    ctrapezoid_vertices_10,
    ctrapezoid_vertices_11,
    ctrapezoid_vertices_12,
    ctrapezoid_vertices_13,
    ctrapezoid_vertices_14,
    ctrapezoid_vertices_15,
    ctrapezoid_vertices_16,
    ctrapezoid_vertices_17,
    ctrapezoid_vertices_18,
    ctrapezoid_vertices_19,
    ctrapezoid_vertices_20,
    ctrapezoid_vertices_21,
    ctrapezoid_vertices_22,
    ctrapezoid_vertices_23,
    ctrapezoid_vertices_24,
    ctrapezoid_vertices_25,
)

function parse_ctrapezoid(io::IO)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    ctrapezoid_type = read_or_modal(io, rui, :ctrapezoidType, info_byte, 1)
    width = read_or_modal(io, rui, :geometryW, info_byte, 2)
    height = read_or_modal(io, rui, :geometryH, info_byte, 3)
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    vertices = CTRAPEZOID_VERTICES_PER_TYPE[ctrapezoid_type + 1](width, height)
    vertices .+= Point{2, Int64}(x, y)
    if ctrapezoid_type <= 0x0f
        ctrapezoid = Polygon(vertices)
    elseif ctrapezoid_type <= 0x17
        ctrapezoid = Triangle{2, Int64}(vertices...)
    else
        ctrapezoid = HyperRectangle{2, Int64}(vertices...)
    end
    shape = Shape(ctrapezoid, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_circle(io::IO)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, rui, :datatype, info_byte, 7)
    radius = read_or_modal(io, rui, :circleRadius, info_byte, 3)
    x, y = read_or_modal_xy(io, :geometryX, :geometryY, info_byte, 4)
    repetition = read_or_nothing(io, read_repetition, :repetition, info_byte, 6)

    center = Point{2, Int64}(x, y)
    circle = HyperSphere{2, Int64}(center, radius)
    shape = Shape(circle, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_property(io::IO)
    # We ignore properties. The code here is only meant to figure out how many bytes to skip.
    info_byte = read(io, UInt8)
    propname_explicit = bit_is_nonzero(info_byte, 6)
    if propname_explicit
        propname_as_reference = bit_is_nonzero(info_byte, 7)
        if propname_as_reference
            skip_integer(io)
        else
            skip_string(io)
        end
    end
    value_list_implicit = bit_is_nonzero(info_byte, 5)
    if !value_list_implicit
        number_of_values = info_byte >> 4
        if number_of_values == 0x0f
            number_of_values = rui(io)
        end
        for _ in 1:number_of_values
            skip_property_value(io)
        end
    end
end

function parse_cblock(io::IO)
    comp_type = rui(io)
    @assert comp_type == 0x00 "Unknown compression type encountered"
    skip_integer(io) # uncomp_byte_count
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
    parse_cellname_ref, # CELLNAME (4)
    parse_textstring_impl, # TEXTSTRING (5)
    parse_textstring_ref, # TEXTSTRING (6) 
    parse_propname_impl, # PROPNAME (7)
    parse_propname_ref, # PROPNAME (8)
    parse_propstring_impl, # PROPSTRING (9)
    parse_propstring_ref, # PROPSTRING (10)
    parse_layername, # LAYERNAME (11)
    parse_textlayername, # LAYERNAME (12)
    parse_cell_ref, # CELL (13)
    parse_cell_str, # CELL (14)
    parse_xyabsolute, # XYABSOLUTE (15)
    parse_xyrelative, # XYRELATIVE (16)
    parse_placement, # PLACEMENT (17)
    parse_placement_mag_angle, # PLACEMENT (18)
    parse_text, # TEXT (19)
    parse_rectangle, # RECTANGLE (20)
    parse_polygon, # POLYGON (21)
    parse_path, # PATH (22)
    parse_trapezoid_ab, # TRAPEZOID (23)
    parse_trapezoid_a, # TRAPEZOID (24)
    parse_trapezoid_b, # TRAPEZOID (25)
    parse_ctrapezoid, # CTRAPEZOID (26)
    parse_circle, # CIRCLE (27)
    parse_property, # PROPERTY (28)
    skip_record, # PROPERTY (29)
    skip_record, #parse_xname_impl, # XNAME (30)
    skip_record, #parse_xname_ref, # XNAME (31)
    skip_record, #parse_xelement, # XELEMENT (32)
    skip_record, #parse_xgeometry, # XGEOMETRY (33)
    parse_cblock # CBLOCK (34)
)
