# OASIS.jl

Open Artwork System Interchange Standard (OASIS) file parser. Work in progress.

## Installation

```
pkg> dev https://github.com/Jeroen-van-der-Meer/OASIS.jl.git
```

## Getting started

To read the contents of an OASIS file:

```julia
using OASIS
filepath = "examplefile.oas"
oasisread(filepath)
```
