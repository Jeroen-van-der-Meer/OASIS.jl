function read_start(state::ParserState)
    version = VersionNumber(read_string(state))
    if version !== v"1.0.0"
        @warn "Unknown file version detected. Attempting to read anyway."
    end
    state.oas.metadata.version = version
    unit = read_real(state) # Convention: Grid steps per micron.
    state.oas.metadata.unit = 1e6 / unit
    offset_flag = rui(state)
    if iszero(offset_flag)
        # We ignore the 12 integers corresponding to the table offset structure.
        for _ in 1:12
            skip_integer(state)
        end
    end
end

function read_cellname_impl(state::ParserState)
    cellname = read_string(state)
    cellname_number = length(state.oas.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(state.oas.references.cellNames, reference)
end

function read_cellname_ref(state::ParserState)
    cellname = read_string(state)
    cellname_number = rui(state)
    reference = NumericReference(cellname, cellname_number)
    push!(state.oas.references.cellNames, reference)
end

function read_textstring_impl(state::ParserState)
    textstring = read_string(state)
    textstring_number = length(state.oas.references.textStrings)
    reference = NumericReference(textstring, textstring_number)
    push!(state.oas.references.textStrings, reference)
end

function read_textstring_ref(state::ParserState)
    textstring = read_string(state)
    textstring_number = rui(state)
    reference = NumericReference(textstring, textstring_number)
    push!(state.oas.references.textStrings, reference)
end

function read_layername(state::ParserState)
    layername = read_string(state)
    layer_interval = read_interval(state)
    datatype_interval = read_interval(state)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(state.oas.references.layerNames, layer_reference)
end

function read_textlayername(state::ParserState)
    layername = read_string(state)
    layer_interval = read_interval(state)
    datatype_interval = read_interval(state)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(state.oas.references.textLayerNames, layer_reference)
end

function read_cell(state::ParserState, cellname_number::UInt64)
    # FIXME: Possible type instability problems.
    if state.lazy
        cell_state = LazyCellParserState(state)
        start_byte = cell_state.pos
    else
        cell_state = CellParserState(state)
    end
    while true
        current_pos = cell_state.pos
        record_type = read_byte(cell_state)
        if is_end_of_cell(cell_state, record_type)
            cell_state.pos = current_pos
            break
        else
            cell_state.pos = current_pos + 1
        end
        read_record(record_type, cell_state)
    end
    if state.lazy
        end_byte = cell_state.pos - 1
        cell = LazyCell(start_byte, end_byte, cell_state.placements)
    else
        cell = Cell(cell_state.shapes, cell_state.placements)
    end
    state.oas.cells[cellname_number] = cell
    state.pos = cell_state.pos
end

function read_cell_ref(state::ParserState)
    cellname_number = rui(state)
    read_cell(state, cellname_number)
end

function read_cell_str(state::ParserState)
    cellname_string = read_string(state)
    cellname_number = _find_or_make_reference(state.oas.references.cellNames, cellname_string)
    read_cell(state, cellname_number)
end

function read_xyabsolute(state::CellParserState)
    state.mod.xyAbsolute = true
end

function read_xyrelative(state::CellParserState)
    state.mod.xyAbsolute = false
end

function read_placement(state::CellParserState)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _find_or_make_reference(state.oas.references.cellNames, cellname)
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
    is_flipped = bit_is_nonzero(info_byte, 8)
    placement = CellPlacement(cellname_number, location, rotation, 1.0, is_flipped, repetition)
    push!(state.placements, placement)
end

function read_placement_mag_angle(state::CellParserState)
    info_byte = read_byte(state)
    cellname_explicit = bit_is_nonzero(info_byte, 1)
    if cellname_explicit
        cellname_as_ref = bit_is_nonzero(info_byte, 2)
        if cellname_as_ref
            cellname_number = rui(state)
        else
            cellname = read_string(state)
            cellname_number = _find_or_make_reference(state.oas.references.cellNames, cellname)
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
    is_flipped = bit_is_nonzero(info_byte, 8)
    placement = CellPlacement(cellname_number, location, rotation, magnification, is_flipped, repetition)
    push!(state.placements, placement)
end

function read_text(state::CellParserState)
    info_byte = read_byte(state)
    text_explicit = bit_is_nonzero(info_byte, 2)
    if text_explicit
        text_as_ref = bit_is_nonzero(info_byte, 3)
        if text_as_ref
            text_number = rui(state)
        else
            text = read_string(state)
            text_number = _find_or_make_reference(state.references.textStrings, text)
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
    push!(state.shapes, shape)
end

function read_rectangle(state::CellParserState)
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
    size = Point{2, Int64}(width, height)
    rectangle = Rect{2, Int64}(lower_left_corner, size)
    shape = Shape(rectangle, layer_number, datatype_number, repetition)
    push!(state.shapes, shape)
end

function read_polygon(state::CellParserState)
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
    push!(state.shapes, shape)
end

function read_path(state::CellParserState)
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
    push!(state.shapes, shape)
end

function read_trapezoid(state::CellParserState, delta_a_explicit::Bool, delta_b_explicit::Bool)
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
            Point{2, Int64}(0, max(delta_a, 0)),
            Point{2, Int64}(width, max(-delta_a, 0)),
            Point{2, Int64}(width, height + min(-delta_b, 0)),
            Point{2, Int64}(0, height + min(delta_b, 0))
        ]
    else # Horizontal orientation
        vertices = [
            Point{2, Int64}(max(delta_a, 0), height),
            Point{2, Int64}(max(-delta_a, 0), 0),
            Point{2, Int64}(width + min(-delta_b, 0), 0),
            Point{2, Int64}(width + min(delta_b, 0), height)
        ]
    end
    vertices .+= Point{2, Int64}(x, y)
    trapezoid = Polygon(vertices)
    shape = Shape(trapezoid, layer_number, datatype_number, repetition)
    push!(state.shapes, shape)
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
    ctrapezoid_type == 0x00000000 && return ctrapezoid_vertices_0(w, h)
    ctrapezoid_type == 0x00000001 && return ctrapezoid_vertices_1(w, h)
    ctrapezoid_type == 0x00000002 && return ctrapezoid_vertices_2(w, h)
    ctrapezoid_type == 0x00000003 && return ctrapezoid_vertices_3(w, h)
    ctrapezoid_type == 0x00000004 && return ctrapezoid_vertices_4(w, h)
    ctrapezoid_type == 0x00000005 && return ctrapezoid_vertices_5(w, h)
    ctrapezoid_type == 0x00000006 && return ctrapezoid_vertices_6(w, h)
    ctrapezoid_type == 0x00000007 && return ctrapezoid_vertices_7(w, h)
    ctrapezoid_type == 0x00000008 && return ctrapezoid_vertices_8(w, h)
    ctrapezoid_type == 0x00000009 && return ctrapezoid_vertices_9(w, h)
    ctrapezoid_type == 0x0000000a && return ctrapezoid_vertices_10(w, h)
    ctrapezoid_type == 0x0000000b && return ctrapezoid_vertices_11(w, h)
    ctrapezoid_type == 0x0000000c && return ctrapezoid_vertices_12(w, h)
    ctrapezoid_type == 0x0000000d && return ctrapezoid_vertices_13(w, h)
    ctrapezoid_type == 0x0000000e && return ctrapezoid_vertices_14(w, h)
    ctrapezoid_type == 0x0000000f && return ctrapezoid_vertices_15(w, h)
    ctrapezoid_type == 0x00000010 && return ctrapezoid_vertices_16(w, h)
    ctrapezoid_type == 0x00000011 && return ctrapezoid_vertices_17(w, h)
    ctrapezoid_type == 0x00000012 && return ctrapezoid_vertices_18(w, h)
    ctrapezoid_type == 0x00000013 && return ctrapezoid_vertices_19(w, h)
    ctrapezoid_type == 0x00000014 && return ctrapezoid_vertices_20(w, h)
    ctrapezoid_type == 0x00000015 && return ctrapezoid_vertices_21(w, h)
    ctrapezoid_type == 0x00000016 && return ctrapezoid_vertices_22(w, h)
    ctrapezoid_type == 0x00000017 && return ctrapezoid_vertices_23(w, h)
    ctrapezoid_type == 0x00000018 && return ctrapezoid_vertices_24(w, h)
    ctrapezoid_type == 0x00000019 && return ctrapezoid_vertices_25(w, h)
end

function read_ctrapezoid(state::CellParserState)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    ctrapezoid_type = read_or_modal(state, rui, Val(:ctrapezoidType), info_byte, 1)
    width = read_or_modal(state, rui, Val(:geometryW), info_byte, 2)
    height = read_or_modal(state, rui, Val(:geometryH), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    vertices = ctrapezoid_vertices(width, height, ctrapezoid_type)
    vertices .+= Point{2, Int64}(x, y)
    if ctrapezoid_type <= 0x0f
        ctrapezoid = Polygon(vertices)
    elseif ctrapezoid_type <= 0x17
        ctrapezoid = Triangle{2, Int64}(vertices...)
    else
        ctrapezoid = Rect{2, Int64}(vertices...)
    end
    shape = Shape(ctrapezoid, layer_number, datatype_number, repetition)
    push!(state.shapes, shape)
end

function read_circle(state::CellParserState)
    info_byte = read_byte(state)
    layer_number = read_or_modal(state, rui, Val(:layer), info_byte, 8)
    datatype_number = read_or_modal(state, rui, Val(:datatype), info_byte, 7)
    radius = read_or_modal(state, rui, Val(:circleRadius), info_byte, 3)
    x, y = read_or_modal_xy(state, Val(:geometryX), Val(:geometryY), info_byte, 4)
    repetition = read_repetition(state, info_byte, 6)

    center = Point{2, Int64}(x, y)
    circle = HyperSphere{2, Int64}(center, radius)
    shape = Shape(circle, layer_number, datatype_number, repetition)
    push!(state.shapes, shape)
end

function read_cblock(state::AbstractParserState)
    comp_type = rui(state)
    @assert comp_type == 0x00 "Unknown compression type encountered"
    uncomp_byte_count = rui(state)
    comp_byte_count = rui(state)

    comp_bytes = view_bytes(state, comp_byte_count)
    z = DeflateDecompressorStream(IOBuffer(comp_bytes))
    buf_decompress = Vector{UInt8}(undef, uncomp_byte_count)
    read!(z, buf_decompress)
    close(z)

    state_decomp = new_state(state, buf_decompress)
    while state_decomp.pos <= uncomp_byte_count
        record_type = read_byte(state_decomp)
        read_record(record_type, state_decomp)
    end
end

function read_record(record_type::UInt8, state::ParserState)
    # Switch statements have been shuffled corresponding to how common each record type is.
    record_type == 4  && return read_cellname_ref(state) # CELLNAME
    record_type == 13 && return read_cell_ref(state) # CELL
    record_type == 11 && return read_layername(state) # LAYERNAME
    record_type == 12 && return read_textlayername(state) # LAYERNAME
    record_type == 34 && return read_cblock(state) # CBLOCK
    record_type == 3  && return read_cellname_impl(state) # CELLNAME
    record_type == 5  && return read_textstring_impl(state) # TEXTSTRING
    record_type == 6  && return read_textstring_ref(state) # TEXTSTRING
    record_type == 7  && return skip_propname_impl(state) # PROPNAME
    record_type == 8  && return skip_propname_ref(state) # PROPNAME
    record_type == 9  && return skip_propstring_impl(state) # PROPSTRING
    record_type == 10 && return skip_propstring_ref(state) # PROPSTRING
    record_type == 14 && return read_cell_str(state) # CELL
    record_type == 28 && return skip_property(state) # PROPERTY
    record_type == 29 && return skip_record(state) # PROPERTY
    record_type == 0  && return skip_record(state) # PAD
    record_type == 1  && return read_start(state) # START
    record_type == 2  && return skip_record(state) # END
    record_type == 30 && error("XNAME record encountered; not implemented yet") # XNAME
    record_type == 31 && error("XNAME record encountered; not implemented yet") # XNAME
    error("No suitable record type found; file may be corrupted")
end

function read_record(record_type::UInt8, state::CellParserState)
    # Switch statements have been shuffled corresponding to how common each record type is.
    record_type == 17 && return read_placement(state) # PLACEMENT
    record_type == 20 && return read_rectangle(state) # RECTANGLE
    record_type == 21 && return read_polygon(state) # POLYGON
    record_type == 18 && return read_placement_mag_angle(state) # PLACEMENT
    record_type == 22 && return read_path(state) # PATH
    record_type == 34 && return read_cblock(state) # CBLOCK
    record_type == 15 && return read_xyabsolute(state) # XYABSOLUTE
    record_type == 16 && return read_xyrelative(state) # XYRELATIVE
    record_type == 19 && return read_text(state) # TEXT
    record_type == 28 && return skip_property(state) # PROPERTY
    record_type == 29 && return skip_record(state) # PROPERTY
    record_type == 23 && return read_trapezoid(state, true, true) # TRAPEZOID
    record_type == 24 && return read_trapezoid(state, true, false) # TRAPEZOID
    record_type == 25 && return read_trapezoid(state, false, true) # TRAPEZOID
    record_type == 26 && return read_ctrapezoid(state) # CTRAPEZOID
    record_type == 27 && return read_circle(state) # CIRCLE
    record_type == 0  && return skip_record(state) # PAD
    record_type == 32 && error("XELEMENT record encountered; not implemented yet") # XELEMENT
    record_type == 33 && error("XGEOMETRY record encountered; not implemented yet") # XGEOMETRY
end

function read_record(record_type::UInt8, state::LazyCellParserState)
    # Switch statements have been shuffled corresponding to how common each record type is.
    record_type == 17 && return skip_placement(state) # PLACEMENT
    record_type == 20 && return skip_rectangle(state) # RECTANGLE
    record_type == 21 && return skip_polygon(state) # POLYGON
    record_type == 18 && return skip_placement_mag_angle(state) # PLACEMENT
    record_type == 22 && return skip_path(state) # PATH
    record_type == 34 && return read_cblock(state) # CBLOCK
    record_type == 15 && return skip_record(state) # XYABSOLUTE
    record_type == 16 && return skip_record(state) # XYRELATIVE
    record_type == 19 && return skip_text(state) # TEXT
    record_type == 28 && return skip_property(state) # PROPERTY
    record_type == 29 && return skip_record(state) # PROPERTY
    record_type == 23 && return skip_trapezoid(state, true, true) # TRAPEZOID
    record_type == 24 && return skip_trapezoid(state, true, false) # TRAPEZOID
    record_type == 25 && return skip_trapezoid(state, false, true) # TRAPEZOID
    record_type == 26 && return skip_ctrapezoid(state) # CTRAPEZOID
    record_type == 27 && return skip_circle(state) # CIRCLE
    record_type == 0  && return skip_record(state) # PAD
    record_type == 32 && error("XELEMENT record encountered; not implemented yet") # XELEMENT
    record_type == 33 && error("XGEOMETRY record encountered; not implemented yet") # XGEOMETRY
    error("No suitable record type found; file may be corrupted")
end
