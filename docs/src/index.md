# OasisTools.jl

Toolkit for working with Open Artwork System Interchange Standard (OASIS) files. Work in progress.

## Installation

```
pkg> add OasisTools
```

## Getting started

To read the contents of an OASIS file, use the `oasisread` function.

```julia
using OasisTools
filepath = joinpath(OasisTools.TESTDATA_DIRECTORY, "nested.oas");
oasisread(filepath)
```

```
OASIS file v1.0 with the following cells:
TOP
├─ BOTTOM2 (4×)
│  └─ ROCKBOTTOM
├─ MIDDLE2
│  └─ BOTTOM (5×)
└─ MIDDLE (3×)
   ├─ BOTTOM2 (4×)
   │  └─ ⋯
   └─ BOTTOM (2×)
```

It returns an `Oasis` object, which contains a list of all the cells in your OASIS file, in the form of a `Cell` object. Each cell, in turn, has a list of shapes (encoded as `Shape` objects), as well as a list of cells (i.e. placements of other cells within the specified cell).

# To do

- There *will* be bugs.
- Properties are currently ignored.
- Backwards-compatible extensions are not supported. You will get an error if your file contains any.
- Curvilinear features are not yet supported.
- It is not yet possible to write an OASIS file.
- One day there will be functionality to visually display your layout &mdash; stay tuned.
