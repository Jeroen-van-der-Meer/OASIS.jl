function oasiswrite(filename::AbstractString, oas::Oasis; bufsize = 16 * 1024 * 1024)
    state = WriterState(oas, filename, bufsize)

    write_bytes(state, MAGIC_BYTES)
    write_start(state)
    write_cells(state)
    write_references(state)
    write_end(state)

    write(state.io, @view state.buf[1:(state.pos - 1)])
    close(state.io)
end

function write_cells(state)
    for (cell_number, cell) in pairs(state.oas.cells)
        write_cell(state, cell_number, cell)
    end
end

function write_references(state)
    write_cellname_references(state)
    write_layername_references(state)
    write_textlayername_references(state)
    write_textstring_references(state)
end

function write_cellname_references(state::WriterState)
    for reference in state.oas.references.cellNames
        write_cellname(state, reference)
    end
end

function write_layername_references(state::WriterState)
    for reference in state.oas.references.layerNames
        write_layername(state, reference)
    end
end

function write_textlayername_references(state::WriterState)
    for reference in state.oas.references.textLayerNames
        write_textlayername(state, reference)
    end
end

function write_textstring_references(state::WriterState)
    for reference in state.oas.references.textStrings
        write_textstring(state, reference)
    end
end
