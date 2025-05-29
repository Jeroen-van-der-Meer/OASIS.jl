skip_record(::IO, ::ModalVariables, ::AbstractOasisData) = return

function parse_start(io::IO, ::ModalVariables, oas::Oasis)
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

function parse_cellname_impl(io::IO, ::ModalVariables, oas::Oasis)
    cellname = read_string(io)
    cellname_number = length(oas.references.cellNames)
    reference = NumericReference(cellname, cellname_number)
    push!(oas.references.cellNames, reference)
end

parse_propname_impl(io::IO, ::ModalVariables, ::Oasis) = read_string(io)

parse_propstring_impl(io::IO, ::ModalVariables, ::Oasis) = read_string(io)

function parse_layername(io::IO, ::ModalVariables, oas::Oasis)
    layername = read_string(io)
    layer_interval = read_interval(io)
    datatype_interval = read_interval(io)
    layer_reference = LayerReference(layername, layer_interval, datatype_interval)
    push!(oas.references.layerNames, layer_reference)
end

function parse_textlayername(io::IO, ::ModalVariables, oas::Oasis)
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
function parse_cell_ref(io::IO, modals::ModalVariables, oas::Oasis)
    # The reason we look ahead one byte is because we cannot tell in advance when the CELL
    # record ends. If it ends, this function will likely return to the main parser which also
    # needs to read a byte to find the next record.
    cellname_number = rui(io)
    cell = Cell([], cellname_number)
    while true
        record_type = peek(io, UInt8)
        is_end_of_cell(record_type) ? break : read(io, UInt8)
        RECORD_PARSER_PER_TYPE[record_type + 1](io, modals, cell)
    end
    push!(oas.cells, cell)
end

function parse_xyabsolute(::IO, modals::ModalVariables, ::Oasis)
    modals.xyAbsolute = true
end

function parse_xyrelative(::IO, modals::ModalVariables, ::Oasis)
    modals.xyAbsolute = false
end

function parse_polygon(io::IO, modals::ModalVariables, cell::Cell)
    info_byte = read(io, UInt8)
    layer_number = read_or_modal(io, modals, rui, :layer, info_byte, 8)
    datatype_number = read_or_modal(io, modals, rui, :datatype, info_byte, 7)
    point_list = read_or_modal(io, modals, read_point_list, :polygonPointList, info_byte, 3)
    x = read_or_modal(io, modals, read_signed_integer, :geometryX, info_byte, 4)
    y = read_or_modal(io, modals, read_signed_integer, :geometryY, info_byte, 5)
    repetition = read_or_nothing(io, modals, read_repetition, :repetition, info_byte, 6)

    point_list .+= Point{2, Int64}(x, y)
    polygon = Polygon(point_list)
    shape = Shape(polygon, layer_number, datatype_number, repetition)
    push!(cell.shapes, shape)
end

function parse_property(io::IO, ::ModalVariables, ::AbstractOasisData)
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

function parse_cblock(io::IO, modals::ModalVariables, oas::Oasis)
    comp_type = rui(io)
    @assert comp_type == 0x00 "Unknown compression type encountered"
    uncomp_byte_count = rui(io)
    comp_byte_count = rui(io)
    
    cblock_buffer = IOBuffer(read(io, comp_byte_count))
    io_decompress = DeflateDecompressorStream(cblock_buffer)

    while !eof(io_decompress)
        record_type = read(io_decompress, UInt8)
        RECORD_PARSER_PER_TYPE[record_type + 1](io_decompress, modals, oas)
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
    skip_record, #parse_placement, # PLACEMENT (17)
    skip_record, #parse_placement_mag_angle, # PLACEMENT (18)
    skip_record, #parse_text, # TEXT (19)
    skip_record, #parse_rectangle, # RECTANGLE (20)
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
