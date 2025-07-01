function oasiswrite(filename::AbstractString, oas::Oasis; bufsize = 16 * 1024 * 1024)
    state = WriterState(filename, bufsize)

    write_bytes(state, MAGIC_BYTES)
    write_start(state, oas)
    write_cells(state, oas)
    write_references(state, oas)
    write_end(state)

    write(state.io, @view state.buf[1:(state.pos - 1)])
    close(state.io)
end

function write_cells(state, oas::Oasis)
    for (cell_number, cell) in pairs(oas.cells)
        write_cell(state, oas, cell_number, cell)
    end
end

write_references(state::WriterState, oas::Oasis) = write_references(state, oas.references)

function write_references(state, references::References)
    write_cellname_references(state, references.cellNames)
    write_layername_references(state, references.layerNames)
    write_textlayername_references(state, references.textLayerNames)
    write_textstring_references(state, references.textStrings)
end

function write_cellname_references(state::WriterState, cellnames)
    for reference in cellnames
        write_cellname(state, reference.name)
    end
end

function write_layername_references(state::WriterState, layernames)
    for reference in layernames
        write_layername(state, reference.name, reference.layerInterval, reference.datatypeInterval)
    end
end

function write_textlayername_references(state::WriterState, textlayernames)
    for reference in textlayernames
        write_textlayername(state, reference.name, reference.layerInterval, reference.datatypeInterval)
    end
end

function write_textstring_references(state::WriterState, textstrings)
    for reference in textstrings
        write_textstring(state, reference.name)
    end
end
