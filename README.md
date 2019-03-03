# MUMPS3

The MUMPS3 package provides a Julia interface with the [MUMPS 5.1.2](http://mumps.enseeiht.fr) parallel direct solver, used for solving `A*x=y` for square `A` (as well as some other functionality).

This package *does not* come with a distribution of MUMPS, and it is up to the user to provide a working MUMPS library (see MUMPS installation section).


##### Goal and Design
The goal of this package is to provide simultaneously the full functionality and control that [MUMPS 5.1.2 offers](http://mumps.enseeiht.fr/doc/userguide_5.1.2.pdf), while also providing intuitive high-level usage that requires next-to-no knowledge about the [MUMPS 5.1.2](http://mumps.enseeiht.fr) API.

This is done by providing a Julia structure `MumpsC{T}` which exactly matches the [SDCZ]MUMPS_STRUC_C used inside MUMPS 5.1.2, which is then passed to the MUMPS library. In fact this structure is itself wrapped inside another Julia structure `Mumps{T}` for the purposes of [protecting the memory used by C from Julia's garbage collection](https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/#Garbage-Collection-Safety-1). This `Mumps{T}` structure is what is exposed to the user.

##### Name
There are already two MUMPS pacakages called [MUMPS.jl](https://github.com/JuliaSparse/MUMPS.jl) and [MUMPS.jl](https://github.com/JuliaSmoothOptimizers/MUMPS.jl), which seemed a bit crowded to me. I considered [MMR](https://www.cdc.gov/vaccines/hcp/vis/vis-statements/mmr.html) as the solution to the MUMPS problem, but this seemed a bit ambitious, and had other problems.

## Installation

#### Installing MUMPS3.jl

The package is installed by entering the Pkg environment by typing `]add git@github.com:wrs28/MUMPS3.jl.git`, which will looks like this:
````JULIA
(v1.1) pkg> add git@github.com:wrs28/MUMPS3.jl.git
````

Alternatively, it can be installed through the Pkg package:
````JULIA
using Pkg
Pkg.add("git@github.com:wrs28/MUMPS3.jl.git")
````

MUMPS3 will need to be told where the MUMPS library is via the environment variable
`ENV["MUMPS_PREFIX"]`, which defaults to
````JULIA
ENV["MUMPS_PREFIX"] = "/usr/local/opt/brewsci-mumps"
````
This must be set each time before loading the package. I recommend putting
it in your startup.jl file by adding this line to `~/.julia/config/startup.jl`
````JULIA
push!(ENV,"MUMPS_PREFIX"=>"/path/to/your/mumps/directory")
````

In addition to MUMPS.jl, you will need [MPI.jl](`https://github.com/JuliaParallel/MPI.jl`), via `Pkg.add("MPI")` or `]add MPI`:
````JULIA
(v1.1) pkg> add MPI
````

#### Installing [MUMPS 5.1.2](http://mumps.enseeiht.fr)

This can be a bit tricky. The source code can be downloaded [here](http://mumps.enseeiht.fr),
but compiling and linking it into a dynamic library is awkward at best.

On Mac OS, there is an easy alternative from Homebrew, and detailed instructions
can be found [here](https://github.com/JuliaSmoothOptimizers/MUMPS.jl/blob/master/README.md).
In short, the calls
````SHELL
$ brew tap brewsci/num
$ brew install brewsci-mumps
````
should be sufficient for installing mumps and its dependencies.

By default, this installs MUMPS and its dependencies in `"/usr/local/opt/brewsci-mumps"`

## Getting Started

To load the package, simply call `using MUMPS3`. Additionally you will need to load
[MPI.jl](`https://github.com/JuliaParallel/MPI.jl`) by calling `using MPI`.

Before any calls to MUMPS3, you must initialize the MPI environment by calling
`MPI.Init()`. If working in interactive mode, to avoid multiples `MPI.Init` calls, and to ensure proper finalization of MPI, I recommend putting
````JULIA
MPI.Initialized() ? nothing : MPI.Init()
MPI.finalize_atexit()
````
at the top of your code.

##### Note on using MPI in REPL session

To my knowledge, there is no easy way on Julia v1 to run MPI with multiple workers in an interactive REPL session. To take full advantage of the parallelism of MUMPS, write a Julia script and use `mpirun` from the command line, for example `mpirun -np 4 julia [filename]` executes `filename` with 4 workers.

To get the parallel advantage in an interactive session, consider using [Pardiso.jl](https://github.com/JuliaSparse/Pardiso.jl), which interfaces with a different PARallel DIrect SOlver.

## Basic Examples
````JULIA
using MUMPS3,MPI,LinearAlgebra,SparseArrays

MPI.Initialized() ? nothing : MPI.Init()
MPI.finalize_atexit()

N, M = 1000, 10
A = sparse(I,N,N) + sprand(N,N,1/N)
y = sprand(N,M,1/sqrt(N*M))

x = mumps_solve(A,y)
norm(A*x-y) # should be ~1-e15
````

## Basic Usage

There are five high-level functions that use the [MUMPS 5.1.2 library](http://mumps.enseeiht.fr): `mumps_solve`, `mumps_factorize`, `mumps_det`, `mumps_schur`, `mumps_select_inv`. The first three are self-explanatory, and last two compute the Schur complement matrix and select entries of the inverse, respectively. With the exception of `mumps_factorize`, all of these methods internally create and destroy their own mumps instances.

`mumps_solve(A,y) -> x` takes in a square matrix `A` and vector or matrix `y` and outputs `x` such that `A*x=y`.

`mumps_factorize(A) -> LU` does an LU factorization on `A`. The returned object is a `Mumps` object, and can be used with `\`, `ldiv`, and `ldiv!`, eg `x=LU\y`. This requires first loading LinearAlgebra: `using LinearAlgebra`.

`mumps_det(A) -> d` computes the determinant of `A`.

`mumps_schur(A,shur_inds) -> S` computes the Schur complement `S` of `A`. The indices defining the Schur block are contained in `schur_inds`, either as an integer array or as a sparse matrix, the populated rows of which define the Schur variables.

`mumps_select_inv(A,IJ) -> a⁻¹` and
`mumps_select_inv(A,I,J) -> a⁻¹`
computes select elements of the inverse of `A`. `IJ` is a sparse matrix whose sparsity pattern defines which elements are computed. `I`, `J` are arrays of integers such that the `k`th linear index of `a⁻¹` has the cartesian counterpart `(I[k],J[k])`.

## Lower-level usage

The MUMPS3 package is build around the `Mumps{T}` structure, which contains `MumpsC{T}`, a structure which mirrors the [SDCZ]MUMPS_STRUC_C used inside the MUMPS library. For more control over how to access MUMPS, one can work directly with this structure.

`Mumps(A; [sym, par=1]) -> mumps` initializes a `Mumps` object with the same type as `A`. The `sym` argument can be passed explicitly, else it is determined from the symmetry and positive definiteness of `A`. See the [MUMPS 5.1.2 documentation](http://mumps.enseeiht.fr/doc/userguide_5.1.2.pdf#page=24) for what `sym` and `par` mean.

`Mumps(A, y; [sym, par=1]) -> mumps` initializes a `Mumps` object with the type determined by `A` and `y`, loaded with matrix `A` and right hand side `y`.

`Mumps{T}(; sym=0, par=1)->mumps` initializes a blank `Mumps{T}` instance.

`mumps_solve(mumps) -> x` solves for `x`, and both a matrix and rhs must have been previously provided to `mumps`. This can be done by initializing with `A` and `y`, or by using the `provide_matrix!` and `provide_rhs!` functions.

`mumps_solve(mumps,y) -> x` solves for `x` and provides `mumps` with the right hand side `y`.

`mumps_factorize!(mumps)` does and LU factorization on `mumps` in place.

`mumps_det!(mumps)` computes the determinant in `mumps`. The determinant can be accessed by subsequently calling `det(mumps)`. This requires first loading LinearAlgebra: `using LinearAlgebra`.

`mumps_schur!(mumps,x)` computes the Schur complement matrix, where the Schur indices are defined by `x` in the same way as for `mumps_schur` (see above). The Schur complement can be subsequently accessed by `get_schur(mumps)`.

`mumps_select_inv!(x,mumps)` computes selected elements of the inverse of `A` (previously provided to `mumps`). The elements sought are determined from the sparsity pattern of `x`, which the results are also saved in.

There are also in-place versions of all of these (eg `mumps_solve!(x,A,y)`, which is equivalent to `ldiv!(x,A,y)`). See the documentation, eg, `?mumps_solve!` for more detail.

#### Accessing `Mumps` data

If not working with the highest level functions, it is often necessary to provide or retrieve data from `Mumps{T}`.

`provide_matrix(mumps,A)` gives the `Mumps` instance `mumps` the square matrix `A`. It attempts to convert `A` to a type consistent with `mumps`, throwing warnings when this happens.

`provide_rhs!(mumps,y)` gives the `Mumps` instance `mumps` the right hand side (matrix or vector) `y`. It attempts to convert `y` to a type consistent with `mumps`, throwing warnings when this happens.

`get_rhs(mumps) -> y` retrieves the right hand side from `mumps`, if available.
`get_rhs!(y,mumps)` does the same thing in-place.

`get_schur(mumps) -> S` retrieves the Schur complement matrix `S` from `mumps`, if available. `get_schur!(S,mumps)` does the same thing in-place.

`get_sol(mumps) -> x` retrieves the solution `x` from `mumps`. MUMPS 5.1.2 can overwrite the rhs with the solution (see [Section 5.13.4 of manual](http://mumps.enseeiht.fr/doc/userguide_5.1.2.pdf)). This function differs from `get_rhs!` because it returns always the solution data, which may or may not be the same as the rhs data (depending on whether rhs is sparse or not). `get_sol!(x,mumps)` does the same thing, in-place.

`finalize!(mumps)` frees the pointers contained therein for garbage collection. Its counterpart, `initialize!(mumps)` resets `mumps`.

## Lowest Level Usage

For complete control over MUMPS 5.1.2, one can manipulate a `Mumps{T}` object directly. Be warned, this can expose unsafe operation which can crash Julia, if, for example, one attempts to access a finalized `Mumps` instance.

I recommend refering to the [MUMPS 5.1.2 documentation](http://mumps.enseeiht.fr/doc/userguide_5.1.2.pdf), Section 6.1 in particular.

Given a `Mumps{T}` object `mumps`, you can set the ICNTL integer array by `set_icntl!(mumps,index,value)`. The current ICNTL can be viewed by `display_icntl(mumps)`

As indicated above, matrices and rhs's can be provided with `provide_matrix!` and `provide_rhs!`.

The JOB parameter can be set by `set_job!(mumps,job)`.

A call to MUMPS can be made with `invoke_mumps!(mumps)`.

Some convenience functions for changing INCTL are provided, though their documentation is not complete. For example, to set ICNTL to its default, call `default_icntl!(mumps)`. To set the printing level, `set_print_level!(mumps,level)`. To suppress printing entirely (except for errors) `suppress_printing!(mumps)` or `suppress_display!(mumps)`.

## List of Methods

|low-level manipulation|
|---|
|`invoke_mumps!(mumps)`|
|`set_icntl!(mumps,index,value; [displaylevel=1])`|
|`set_job!(mumps,job)`|

|low-level access|
|---|
|`provide_matrix!(mumps,A)`|
|`provide_rhs!(mumps,y)`|
|`get_rhs!(y,mumps)`|
|`get_rhs(mumps) -> y`|
|`get_schur!(S,mumps)`|
|`get_schur(mumps) -> S`|
|`get_sol!(x,mumps)`|
|`get_sol(mumps) -> x`|

|Mumps initialization|
|---|
|`Mumps{T}(;[sym=0, par=1]) -> mumps`|
|`Mumps(A; [sym, par=1]) -> mumps`|
|`Mumps(A,rhs; [sym, par=1]) -> mumps`|
|`initialize!(mumps)`|
|`finalize!(mumps)`|

|Mumps solution|
|---|
|`mumps_solve!(x,mumps)`|
|`mumps_solve!(x,A,y)`|
|`mumps_solve!(x,mumps,y)`|
|`mumps_solve(mumps) -> x`|
|`mumps_solve(A,y) -> x`|
|`mumps_solve(mumps,y) -> x`|
|`mumps_factorize!(mumps)`|
|`mumps_factorize(A) -> mumps`|
|`mumps_det!(mumps; discard=true)`|
|`mumps_det(A) -> det`|
|`mumps_schur!(mumps, schur_inds)`|
|`mumps_schur!(mumps, x)`|
|`mumps_schur(A,schur_inds) -> S`|
|`mumps_schur(A,x) -> S`|
|`mumps_select_inv!(x,mumps)`|
|`mumps_select_inv!(x,A)`|
|`mumps_select_inv(A,IJ::Sparse) -> A⁻¹`|
|`mumps_select_inv(A,I,J) -> A⁻¹`|

|ICNTL manipulation|
|---|
|`display_icntl(mumps)`|
|`set_error_stream!(mumps,stream)`|
|`set_diagnostics_stream!(mumps,stream)`|
|`set_info_stream!(mumps,stream)`|
|`set_print_level!(mumps,level)`|
|`suppress_printing!(mumps)`|
|`toggle_printing!(mumps)`|
|`sparse_matrix!(mumps)`|
|`dense_matrix!(mumps)`|
|`sparse_rhs!(mumps)`|
|`dense_rhs!(mumps)`|
|`toggle_null_pivot!(mumps)`|
|`transpose!(mumps)`|

|LinearAlgebra extensions|
|---|
|`det(mumps) -> det`|
|`\(mumps,y)` = `mumps\y -> x`|
|`ldiv(mumps,y) -> x`|
|`ldiv!(x,mumps,y)`|
