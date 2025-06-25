# Public display functions

"""
    show_cells(oas; kw...)

Obtain an overview of the cells in your OASIS objects.

# Arguments

- `oas::Oasis`: Your OASIS object, loaded with `oasisread`.

# Keyword Arguments

- `maxdepth = 100`: Specify until what maxdepth you'd like to the cell hierarchy to be
  displayed.
- `flat = false`: If set to `true`, rather than displaying a hierarchy, `show_cells` simply
  lists the names of all cells that can be found in `oas`. If set to `true`, the keyword
  argument `maxdepth` is ignored.
"""
function show_cells(oas::Oasis; maxdepth = 100, flat = false, io = stdout)
    if flat
        for cell in oas.cells
            println(io, find_reference(cell.nameNumber, oas.references.cellNames))
        end
    else
        _show_hierarchy(oas; maxdepth = maxdepth, io = io)
    end
end

function show_cells(oas::LazyOasis; maxdepth = 100, flat = false, io = stdout)
    if flat
        for k in keys(oas.hierarchy)
            println(io, find_reference(k, oas.references.cellNames))
        end
    else
        _show_hierarchy(oas; maxdepth = maxdepth, io = io)
    end
end

# Same as show_cells(oas) but starting from a specified cell
function show_cells(cell::Cell; maxdepth = 100, flat = false, io = stdout)
    if flat
        for cell in oas.cells
            println(io, find_reference(cell.nameNumber, oas.references.cellNames))
        end
    else
        _show_hierarchy(oas; maxdepth = maxdepth, root = cell.nameNumber, io = io)
    end
end

function show_shapes(oas::Oasis; cell::AbstractString, maxdepth = 1, flat = false)
    @error "Not implemented"
end

# Custom shows

function Base.show(io::IO, oas::Oasis)
    print(io,
        "OASIS file v", oas.metadata.version.major, ".", oas.metadata.version.minor, " ",
        "with the following cells: \n")
    show_cells(oas; maxdepth = 2, flat = false, io = io)
end

function Base.show(io::IO, oas::LazyOasis)
    print(io,
        "Lazy OASIS file v", oas.metadata.version.major, ".", oas.metadata.version.minor, " ",
        "with the following cells: \n")
    show_cells(oas; maxdepth = 2, flat = false, io = io)
end

#=
function Base.show(io::IO, cell::Cell)
    print(io, "Cell $(cell.nameNumber) with the following contents: \n")
    show_shapes(cell; io = io)
    show_cells(cell; maxdepth = 2, flat = false, io = io)
end
=#

function Base.show(io::IO, placement::CellPlacement)
    print(io, "Placement of cell $(placement.nameNumber) at ($(placement.location[1]), $(placement.location[2]))")
    repetition = !isnothing(placement.repetition)
    if repetition
        nrep = length(placement.repetition)
        print(io, " ($nrep×)")
    end
end

function Base.show(io::IO, shape::Shape{Polygon{2, Int64}})
    location = sum(shape.shape.exterior) .÷ length(shape.shape.exterior)
    _show_shape(io, shape, "Polygon", location)
end

function Base.show(io::IO, shape::Shape{Rect{2, Int64}})
    location = shape.shape.origin + shape.shape.widths .÷ 2
    _show_shape(io, shape, "Rectangle", location)
end

function Base.show(io::IO, shape::Shape{Circle{Int64}})
    location = shape.shape.center
    _show_shape(io, shape, "Circle", location)
end

function Base.show(io::IO, shape::Shape{Path{2, Int64}})
    location = sum(shape.shape.points) .÷ length(shape.shape.points)
    _show_shape(io, shape, "Path", location)
end

# Internal functions

function _show_hierarchy(
    oas;
    cell_hierarchy = CellHierarchy(oas),
    maxdepth = 100, io = stdout, count = 1,
    current_depth = 0, prefix = "", last = true, root = cell_hierarchy.root
)
    if current_depth == 0
        print(prefix, find_reference(root, oas.references.cellNames))
        new_prefix = prefix
    else
        print('\n')
        connector = last ? "└─ " : "├─ "
        print(prefix, connector, find_reference(root, oas.references.cellNames))
        # If a cell occurs N times with N > 1, we annotate the cell name with "(N×)".
        count > 1 && print(" ($(count)×)")
        new_prefix = prefix * (last ? "   " : "│  ")
    end
    children = cell_hierarchy.hierarchy[root]
    # If `maxdepth` is reached, we check whether the current element has any further children.
    # Rather than printing them, we print an ellipsis (⋯) to indicate that there are children.
    if current_depth >= maxdepth
        if length(children) > 0
            print('\n', new_prefix, "└─ ⋯")
        end
        return
    end
    # Count how often each child occurs to avoid printing duplicates and instead print how often
    # the child occurs.
    count_map = Dict{UInt64, Int64}()
    for child in children
        # FIXME: What if a child appears once but with repetition? Might want to print the
        # number of repetitions in that case.
        count_map[child] = get(count_map, child, 0) + 1
    end
    nunique_children = length(count_map)
    for (i, (child, count)) in enumerate(pairs(count_map))
        child_is_last = i == nunique_children
        _show_hierarchy(
            oas;
            cell_hierarchy = cell_hierarchy,
            maxdepth = maxdepth,
            io = io,
            count = count,
            root = child,
            current_depth = current_depth + 1,
            prefix = new_prefix,
            last = child_is_last
        )
    end
end

function _show_shape(io::IO, shape::Shape, name, location)
    print(io, "$name in layer ($(shape.layerNumber)/$(shape.datatypeNumber)) at ($(location[1]), $(location[2]))")
    repetition = !isnothing(shape.repetition)
    if repetition
        nrep = length(shape.repetition)
        print(io, " ($nrep×)")
    end
end