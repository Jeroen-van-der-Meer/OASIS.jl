function Base.show(io::IO, oas::Oasis)
    print(io,
        "OASIS file v", oas.metadata.version.major, ".", oas.metadata.version.minor, " ",
        "with the following cells: \n")
    show_cells(oas; depth = 2, flat = false, io)
end

"""
    show_cells(oas; kw...)

Obtain an overview of the cells in your OASIS objects.

# Arguments

- `oas::Oasis`: Your OASIS object, loaded with `oasisread`.

# Keyword Arguments

- `depth = 100`: Specify until what depth you'd like to the cell hierarchy to be displayed.
- `flat = false`: If set to `true`, rather than displaying a hierarchy, `show_cells` simply
  lists the names of all cells that can be found in `oas`. If set to `true`, the keyword
  argument `depth` is ignored.
"""
function show_cells(oas::Oasis; depth = 100, flat = false, io = stdout)
    if flat
        for cell in oas.cells
            println(io, find_reference(cell.nameNumber, oas.references.cellNames))
        end
    else
        show_hierarchy(oas; maxdepth = depth, io)
    end
end

function show_hierarchy(
    oas::Oasis;
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
        show_hierarchy(
            oas;
            cell_hierarchy,
            maxdepth, io, count,
            root = child,
            current_depth = current_depth + 1,
            prefix = new_prefix,
            last = child_is_last
        )
    end
end

function show_shapes(oas::Oasis; cell::AbstractString, depth = 1, flat = false)
    @error "Not implemented"
end