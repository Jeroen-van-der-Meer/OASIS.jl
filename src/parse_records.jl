skip_record(state) = return

function parse_start(state)
    version = VersionNumber(read_string(state))
    state.oas.metadata.version = version
    unit = read_real(state)
    state.oas.metadata.unit = 1e6 / unit
    offset_flag = rui(state)
    if iszero(offset_flag)
        # We ignore the 12 integers corresponding to the table offset structure.
        for _ in 1:12
            skip_integer(state)
        end
    end
end

function parse_cellname_impl(state)
    cellname = read_string(state)
    cellname_number = length(state.oas.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(state.oas.references.cellNames, reference)
end

function parse_cellname_ref(state)
    cellname = read_string(state)
    cellname_number = rui(state)
    reference = NumericReference(cellname, cellname_number)
    push!(state.oas.references.cellNames, reference)
end

function parse_textstring_impl(state)
    textstring = read_string(state)
    textstring_number = length(state.oas.references.textStrings)
    reference = NumericReference(textstring, textstring_number)
    push!(state.oas.references.textStrings, reference)
end

function parse_textstring_ref(state)
    textstring = read_string(state)
    textstring_number = rui(state)
    reference = NumericReference(textstring, textstring_number)
    push!(state.oas.references.textStrings, reference)
end

function parse_propname_impl(state)
    skip_string(state)
end

function parse_propname_ref(state)
    skip_string(state)
    skip_integer(state)
end

function parse_propstring_impl(state)
    skip_string(state)
end

function parse_propstring_ref(state)
    skip_string(state)
    skip_integer(state)
end

function parse_layername(state)
    layername = read_string(state)
    layer_interval = read_interval(state)
    datatype_interval = read_interval(state)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(state.oas.references.layerNames, layer_reference)
end

function parse_textlayername(state)
    layername = read_string(state)
    layer_interval = read_interval(state)
    datatype_interval = read_interval(state)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(state.oas.references.textLayerNames, layer_reference)
end

function is_end_of_cell(next_record::UInt8)
    # The end of a cell is implied when the upcoming record is any of the following:
    # END, CELLNAME, TEXTSTRING, PROPNAME, PROPSTRING, LAYERNAME, CELL, XNAME
    return (0x02 <= next_record <= 0x0e) || (next_record == 0x1e) || (next_record == 0x1f)
end

function parse_cell(state)
    # Whenever a cell is encountered, the following modal variables are reset.
    state.mod.xyAbsolute = true
    state.mod.placementX = 0
    state.mod.placementY = 0
    state.mod.geometryX = 0
    state.mod.geometryY = 0
    state.mod.textX = 0
    state.mod.textY = 0

    while true
        # The reason we look ahead one byte is because we cannot tell in advance when the CELL
        # record ends. If it ends, this function will likely return to the main parser which
        # also needs to read a byte to find the next record.
        @inbounds record_type = state.buf[state.pos]
        is_end_of_cell(record_type) ? break : state.pos += 1
        parse_record(record_type, state)
    end
end

function parse_cell_ref(state)
    cellname_number = rui(state)
    cell = Cell([], [], cellname_number)
    state.currentCell = cell

    parse_cell(state)
    push!(state.oas.cells, state.currentCell)
end

function parse_cell_str(state)
    cellname_string = read_string(state)
    cellname_number = cellname_to_cellname_number(state, cellname_string)
    cell = Cell([], [], cellname_number)
    state.currentCell = cell

    parse_cell(state)
    push!(state.oas.cells, state.currentCell)
end

function parse_xyabsolute(state)
    state.mod.xyAbsolute = true
end

function parse_xyrelative(state)
    state.mod.xyAbsolute = false
end

function parse_placement(state)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = cellname_to_cellname_number(state, cellname)
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.placementCell = cellname_number
    else
        cellname_number = state.mod.placementCell
    end
    x, y = read_or_modal_xy(state, Val(:placementX), Val(:placementY), info_byte, 3)
    location = Point{2, Int64}(x, y)
    rotation = ((info_byte >> 1) & 0x03) * 90
    repetition = read_repetition(state, info_byte, 5)
    placement = CellPlacement(cellname_number, location, rotation, 1.0, repetition)
    push!(state.currentCell.cells, placement)
end

function parse_placement_mag_angle(state)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = cellname_to_cellname_number(state, cellname)
            # If a string is used to denote the cellname, find the corresponding reference. If
            # no such reference exists (yet?), create a random one ourselves.
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.placementCell = cellname_number
    else
        cellname_number = state.mod.placementCell
    end
    if bit_is_nonzero(info_byte, 6)
        magnification = read_real(state)
    else
        magnification = 1.0
    end
    if bit_is_nonzero(info_byte, 7)
        rotation = read_real(state)
    else
        rotation = 0.0
    end
    x, y = read_or_modal_xy(state, Val(:placementX), Val(:placementY), info_byte, 3)
    location = Point{2, Int64}(x, y)
    repetition = read_repetition(state, info_byte, 5)
    placement = CellPlacement(cellname_number, location, rotation, magnification, repetition)
    push!(state.currentCell.cells, placement)
end

function parse_text(state)
    info_byte = read_byte(state)
    text_explicit = bit_is_nonzero(info_byte, 2)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 3)
        if text_as_ref
            text_number = rui(state)
        else
            text = read_string(state)
            text_number = cellname_to_cellname_number(state, text)
            # If a string is used to denote the cellname, find the corresponding reference. If
            # no such reference exists (yet?), create a random one ourselves.
        end
        # Update the modal variable. We choose to always save the reference number instead of
        # the string.
        state.mod.textString = text_number
    else
        text_number = state.mod.textString
    end
    textlayer_number = read_or_modal(state, rui, Val(:textlayer), info_byte, 8)
    texttype_number = read_or_modal(state, rui, Val(:texttype), info_byte, 7)
    x, y = read_or_modal_xy(state, Val(:textX), Val(:textY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    text = Text(text_number, Point{2, Int64}(x, y), repetition)
    shape = Shape(text, textlayer_number, texttype_number, repetition)
    push!(state.currentCell.shapes, shape)
end

function parse_rectangle(state)
    info_byte = read_byte(state)
    is_square = bit_is_nonzero(info_byte, 1)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    width = signed(read_or_modal(state, rui, Val(:geometryW), info_byte, 2))
    if is_square
        # If rectangle is a square, the height is necessarily not logged, and the modal
        # geometryH is set to the width.
        height = width
        state.mod.geometryH = width
    else
        height = signed(read_or_modal(state, rui, Val(:geometryH), info_byte, 3))
    end
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    lower_left_corner = Point{2, Int64}(x, y)
    upper_right_corner = Point{2, Int64}(x + width, y + height)
    rectangle = HyperRectangle{2, Int64}(lower_left_corner, upper_right_corner)
    shape = Shape(rectangle, layer_number, datatype_number, repetition)
    push!(state.currentCell.shapes, shape)
end

function parse_polygon(state)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    point_list = read_or_modal(state, read_point_list, Val(:polygonPointList), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    cumsum!(point_list, point_list)
    point_list .+= Point{2, Int64}(x, y)
    polygon = Polygon(point_list)
    shape = Shape(polygon, layer_number, datatype_number, repetition)
    push!(state.currentCell.shapes, shape)
end

function parse_path(state)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    halfwidth = read_or_modal(state, rui, Val(:pathHalfwidth), info_byte, 2)
    extension_scheme_present = bit_is_nonzero(info_byte, 1)
    if extension_scheme_present
        extension_scheme = read_byte(state)
        SS_bits = (extension_scheme >> 2) & 0x03
        if SS_bits == 0x00
            start_extension = state.mod.pathStartExtension
            state.mod.pathStartExtension = start_extension
        elseif SS_bits == 0x01
            start_extension = 0
            state.mod.pathStartExtension = start_extension
        elseif SS_bits == 0x02
            start_extension = halfwidth
            state.mod.pathStartExtension = start_extension
        else
            start_extension = read_signed_integer(state)
        end
        EE_bits = extension_scheme & 0x03
        if EE_bits == 0x00
            end_extension = state.mod.pathEndExtension
            state.mod.pathEndExtension = end_extension
        elseif EE_bits == 0x01
            end_extension = 0
            state.mod.pathEndExtension = end_extension
        elseif EE_bits == 0x02
            end_extension = halfwidth
            state.mod.pathEndExtension = end_extension
        else
            end_extension = read_signed_integer(state)
        end
    else
        start_extension = state.mod.pathStartExtension
        end_extension = state.mod.pathEndExtension
    end
    point_list = read_or_modal(state, read_point_list, Val(:pathPointList), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    # Adjust point list based on start and end extension so that we don't have to log these
    # parameters. The unfortunate downside is that there's no guarantee that the resulting point
    # list will properly snap within the specified grid, and as such rounding errors may occur.
    # That said, I cannot imagine this setting is used often in practice.
    if !iszero(start_extension)
        first_delta = point_list[2]
        first_delta_normalized = first_delta ./ sqrt(first_delta[1]^2 + first_delta[2]^2)
        adjustment_for_start = first_delta_normalized * start_extension
        adjustment_for_start_rounded = round.(Int64, adjustment_for_start)
        point_list[2] += adjustment_for_start_rounded
        x -= adjustment_for_start_rounded[1]
        y -= adjustment_for_start_rounded[2]
    end
    if !iszero(end_extension)
        last_delta = point_list[end]
        last_delta_normalized = last_delta ./ sqrt(last_delta[1]^2 + last_delta[2]^2)
        adjustment_for_end = last_delta_normalized * end_extension
        adjustment_for_end_rounded = round.(Int64, adjustment_for_end)
        point_list[end] += adjustment_for_end_rounded
    end
    cumsum!(point_list, point_list)
    point_list .+= Point{2, Int64}(x, y)
    path = Path(point_list, 2 * signed(halfwidth))
    shape = Shape(path, layer_number, datatype_number, repetition)
    push!(state.currentCell.shapes, shape)
end

function parse_trapezoid(state, delta_a_explicit::Bool, delta_b_explicit::Bool)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    width = read_or_modal(state, rui, Val(:geometryW), info_byte, 2)
    height = read_or_modal(state, rui, Val(:geometryH), info_byte, 3)
    if delta_a_explicit
        # The spec indicates that delta-a and delta-b are 1-deltas. These are merely signed
        # integers with an implied direction. We choose to incorporate the directionality when
        # assembling the vertices.
        delta_a = read_signed_integer(state)
    else
        delta_a = 0
    end
    if delta_b_explicit
        delta_b = read_signed_integer(state)
    else
        delta_b = 0
    end
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

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
    push!(state.currentCell.shapes, shape)
end

function parse_trapezoid_ab(state)
    parse_trapezoid(state, true, true)
end

function parse_trapezoid_a(state)
    parse_trapezoid(state, true, false)
end

function parse_trapezoid_b(state)
    parse_trapezoid(state, false, true)
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

function ctrapezoid_vertices(w::UInt64, h::UInt64, ctrapezoid_type::UInt64)
    if ctrapezoid_type == 0x00000000
        return ctrapezoid_vertices_0(w, h)
    elseif ctrapezoid_type == 0x00000001
        return ctrapezoid_vertices_1(w, h)
    elseif ctrapezoid_type == 0x00000002
        return ctrapezoid_vertices_2(w, h)
    elseif ctrapezoid_type == 0x00000003
        return ctrapezoid_vertices_3(w, h)
    elseif ctrapezoid_type == 0x00000004
        return ctrapezoid_vertices_4(w, h)
    elseif ctrapezoid_type == 0x00000005
        return ctrapezoid_vertices_5(w, h)
    elseif ctrapezoid_type == 0x00000006
        return ctrapezoid_vertices_6(w, h)
    elseif ctrapezoid_type == 0x00000007
        return ctrapezoid_vertices_7(w, h)
    elseif ctrapezoid_type == 0x00000008
        return ctrapezoid_vertices_8(w, h)
    elseif ctrapezoid_type == 0x00000009
        return ctrapezoid_vertices_9(w, h)
    elseif ctrapezoid_type == 0x0000000a
        return ctrapezoid_vertices_10(w, h)
    elseif ctrapezoid_type == 0x0000000b
        return ctrapezoid_vertices_11(w, h)
    elseif ctrapezoid_type == 0x0000000c
        return ctrapezoid_vertices_12(w, h)
    elseif ctrapezoid_type == 0x0000000d
        return ctrapezoid_vertices_13(w, h)
    elseif ctrapezoid_type == 0x0000000e
        return ctrapezoid_vertices_14(w, h)
    elseif ctrapezoid_type == 0x0000000f
        return ctrapezoid_vertices_15(w, h)
    elseif ctrapezoid_type == 0x00000010
        return ctrapezoid_vertices_16(w, h)
    elseif ctrapezoid_type == 0x00000011
        return ctrapezoid_vertices_17(w, h)
    elseif ctrapezoid_type == 0x00000012
        return ctrapezoid_vertices_18(w, h)
    elseif ctrapezoid_type == 0x00000013
        return ctrapezoid_vertices_19(w, h)
    elseif ctrapezoid_type == 0x00000014
        return ctrapezoid_vertices_20(w, h)
    elseif ctrapezoid_type == 0x00000015
        return ctrapezoid_vertices_21(w, h)
    elseif ctrapezoid_type == 0x00000016
        return ctrapezoid_vertices_22(w, h)
    elseif ctrapezoid_type == 0x00000017
        return ctrapezoid_vertices_23(w, h)
    elseif ctrapezoid_type == 0x00000018
        return ctrapezoid_vertices_24(w, h)
    elseif ctrapezoid_type == 0x00000019
        return ctrapezoid_vertices_25(w, h)
    end
end

function parse_ctrapezoid(state)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    ctrapezoid_type = read_or_modal(state, rui, Val(:ctrapezoidType), info_byte, 1)
    width = read_or_modal(state, rui, Val(:geometryW), info_byte, 2)
    height = read_or_modal(state, rui, Val(:geometryH), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    vertices = ctrapezoid_vertices(width, height, ctrapezoid_type)
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
    push!(state.currentCell.shapes, shape)
end

function parse_circle(state)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    radius = read_or_modal(state, rui, Val(:circleRadius), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    center = Point{2, Int64}(x, y)
    circle = HyperSphere{2, Int64}(center, radius)
    shape = Shape(circle, layer_number, datatype_number, repetition)
    push!(state.currentCell.shapes, shape)
end

function parse_property(state)
    # We ignore properties. The code here is only meant to figure out how many bytes to skip.
    info_byte = read_byte(state)
    propname_explicit = bit_is_nonzero(info_byte, 6)
    if propname_explicit
        propname_as_reference = bit_is_nonzero(info_byte, 7)
        if propname_as_reference
            skip_integer(state)
        else
            skip_string(state)
        end
    end
    value_list_implicit = bit_is_nonzero(info_byte, 5)
    if !value_list_implicit
        number_of_values = info_byte >> 4
        if number_of_values == 0x0f
            number_of_values = rui(state)
        end
        for _ in 1:number_of_values
            skip_property_value(state)
        end
    end
end

function parse_cblock(state)
    comp_type = rui(state)
    @assert comp_type == 0x00 "Unknown compression type encountered"
    uncomp_byte_count = rui(state)
    comp_byte_count = rui(state)
    
    comp_bytes = read_bytes(state, comp_byte_count)
    z = DeflateDecompressorStream(IOBuffer(comp_bytes))
    buf_decompress = Vector{UInt8}(undef, uncomp_byte_count)
    read!(z, buf_decompress)
    close(z)

    state_decomp = ParserState(state.oas, state.currentCell, buf_decompress, 1, state.mod)

    while state_decomp.pos <= uncomp_byte_count
        record_type = read_byte(state_decomp)
        parse_record(record_type, state_decomp)
    end
end

function parse_record(record_type::UInt8, state)
    # Very common:
    if record_type == 17 # PLACEMENT
        parse_placement(state)
    elseif record_type == 20 # RECTANGLE
        parse_rectangle(state)
    elseif record_type == 21 # POLYGON
        parse_polygon(state)
    elseif record_type == 4 # CELLNAME
        parse_cellname_ref(state)
    elseif record_type == 13 # CELL
        parse_cell_ref(state)
    # Common:
    elseif record_type == 11 # LAYERNAME
        parse_layername(state)
    elseif record_type == 12 # LAYERNAME
        parse_textlayername(state)
    elseif record_type == 18 # PLACEMENT
        parse_placement_mag_angle(state)
    elseif record_type == 22 # PATH
        parse_path(state)
    elseif record_type == 34 # CBLOCK
        parse_cblock(state)
    # Not so common:
    elseif record_type == 3 # CELLNAME
        parse_cellname_impl(state)
    elseif record_type == 5 # TEXTSTRING
        parse_textstring_impl(state)
    elseif record_type == 6 # TEXTSTRING
        parse_textstring_ref(state)
    elseif record_type == 7 # PROPNAME
        parse_propname_impl(state)
    elseif record_type == 8 # PROPNAME
        parse_propname_ref(state)
    elseif record_type == 9 # PROPSTRING
        parse_propstring_impl(state)
    elseif record_type == 10 # PROPSTRING
        parse_propstring_ref(state)
    elseif record_type == 14 # CELL
        parse_cell_str(state)
    elseif record_type == 15 # XYABSOLUTE
        parse_xyabsolute(state)
    elseif record_type == 16 # XYRELATIVE
        parse_xyrelative(state)
    elseif record_type == 19 # TEXT
        parse_text(state)
    elseif record_type == 23 # TRAPEZOID
        parse_trapezoid(state, true, true)
    elseif record_type == 24 # TRAPEZOID
        parse_trapezoid(state, true, false)
    elseif record_type == 25 # TRAPEZOID
        parse_trapezoid(state, false, true)
    elseif record_type == 26 # CTRAPEZOID
        parse_ctrapezoid(state)
    elseif record_type == 27 # CIRCLE
        parse_circle(state)
    elseif record_type == 28 # PROPERTY
        parse_property(state)
    elseif record_type == 29 # PROPERTY
        skip_record(state)
    # Very uncommon:
    elseif record_type == 0 # PAD
        skip_record(state)
    elseif record_type == 1 # START
        parse_start(state)
    elseif record_type == 2 # END
        skip_record(state)
    elseif record_type == 30
        @error "Not implemented"
    elseif record_type == 31
        @error "Not implemented"
    elseif record_type == 32
        @error "Not implemented"
    elseif record_type == 33
        @error "Not implemented"
    end
end
