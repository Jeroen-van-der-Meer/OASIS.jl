skip_record(::OasisStream, ::AbstractOasisData) = return

function parse_start(os::OasisStream, of::OasisFile)
    version = VersionNumber(read_string(os.io))
    of.metadata.version = version
    unit = read_real(os.io)
    of.metadata.unit = 1e6 / unit
    offset_flag = rui(os.io)
    if iszero(offset_flag)
        # We ignore the 12 integers corresponding to the table offset structure.
        for _ in 1:12
            rui(os.io)
        end
    end
end

function parse_cellname_impl(os::OasisStream, of::OasisFile)
    cellname = read_string(os.io)
    cellname_number = length(of.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(of.references.cellNames, reference)
end

parse_propname_impl(os::OasisStream, ::AbstractOasisData) = read_string(os.io)

parse_propstring_impl(os::OasisStream, ::AbstractOasisData) = read_string(os.io)

function parse_layername(os::OasisStream, of::OasisFile)
    layername = read_string(os.io)
    layer_interval = read_interval(os.io)
    datatype_interval = read_interval(os.io)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(of.references.layerNames, layer_reference)
end

function parse_textlayername(os::OasisStream, of::OasisFile)
    layername = read_string(os.io)
    layer_interval = read_interval(os.io)
    datatype_interval = read_interval(os.io)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(of.references.textLayerNames, layer_reference)
end

function is_end_of_cell(next_record::UInt8)
    # The end of a cell is implied when the upcoming record is any of the following:
    # END, CELLNAME, TEXTSTRING, PROPNAME, PROPSTRING, LAYERNAME, CELL, XNAME
    return (0x02 <= next_record <= 0x0e) || (next_record == 0x1e) || (next_record == 0x1f)
end
function parse_cell_ref(os::OasisStream, od::AbstractOasisData)
    # The reason we look ahead one byte is because we cannot tell in advance when the CELL
    # record ends. If it ends, this function will likely return to the main parser which also
    # needs to read a byte to find the next record.
    cellname_number = rui(os.io)
    cell = Cell([], cellname_number)
    while true
        record_type = peek(os.io, UInt8)
        is_end_of_cell(record_type) ? break : read(os.io, UInt8)
        RECORD_PARSER_PER_TYPE[record_type + 1](os, cell)
    end
    push!(od.cells, cell)
end

function parse_xyabsolute(os::OasisStream, ::AbstractOasisData)
    os.modals.xyAbsolute = true
end

function parse_xyrelative(os::OasisStream, ::AbstractOasisData)
    os.modals.xyAbsolute = false
end

function parse_polygon(os::OasisStream, cell::Cell)
    info_byte = read(os.io, UInt8)
    layer_number = read_or_modal(os, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(os, rui, :datatype, info_byte, 7)
    point_list = read_or_modal(os, read_point_list, :polygonPointList, info_byte, 3)
    x = read_or_modal(os, read_signed_integer, :geometryX, info_byte, 4)
    y = read_or_modal(os, read_signed_integer, :geometryY, info_byte, 5)
    repetition = read_or_nothing(os, read_repetition, :repetition, info_byte, 6)

    point_list .+= Point{2, Int64}(x, y)
    polygon = Polygon(point_list)
    shape = Shape(polygon, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_property(os::OasisStream, ::AbstractOasisData)
    # We ignore properties. The code here is only meant to figure out how many bytes to skip.
    info_byte = read(os.io, UInt8)
    propname_explicit = bit_is_nonzero(info_byte, 6)
    if propname_explicit
        propname_as_reference = bit_is_nonzero(info_byte, 7)
        if propname_as_reference
            rui(os.io)
        else
            read_string(os.io)
        end
    end
    value_list_implicit = bit_is_nonzero(info_byte, 5)
    if !value_list_implicit
        number_of_values = info_byte >> 4
        if number_of_values == 0x0f
            number_of_values = rui(os.io)
        end
        for _ in 1:number_of_values
            read_property_value(os.io)
        end
    end
end

const RECORD_PARSER_PER_TYPE = (
    skip_record,
    parse_start,
    skip_record,
    parse_cellname_impl,
    skip_record, #parse_cellname_ref,
    skip_record, #parse_textstring_impl,
    skip_record, #parse_textstring_ref, 
    parse_propname_impl,
    skip_record, #parse_propname_ref,
    parse_propstring_impl, #parse_propstring_impl,
    skip_record, #parse_propstring_ref,
    parse_layername,
    parse_textlayername,
    parse_cell_ref,
    skip_record, #parse_cell_str,
    parse_xyabsolute,
    parse_xyrelative,
    skip_record, #parse_placement,
    skip_record, #parse_placement_mag_angle,
    skip_record, #parse_text,
    skip_record, #parse_rectangle,
    parse_polygon,
    skip_record, #parse_path,
    skip_record, #parse_trapezoid_ab,
    skip_record, #parse_trapezoid_a,
    skip_record, #parse_trapezoid_b,
    skip_record, #parse_ctrapezoid,
    skip_record, #parse_circle,
    parse_property,
    skip_record, #parse_modal_property,
)
