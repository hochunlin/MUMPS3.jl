# this file mirros the relevant content of the "[sdcz]mumps_c.h" file of MUMPS 5.2.0
# there are three structs: MumpsC, which exactly mirrors the C-content,
# GC_haven, which contains Julia references to protect the pointers passed to C
# from gargage collection, and Mumps, which is the only one directly accessed by
# the functions and user.
export Mumps

const MUMPS_VERSION = "5.2.0"
const MUMPS_VERSION_MAX_LEN = 30

# mirror of structre in [sdcz]mumps_c.h
mutable struct MumpsC{TC,TR}
    sym::MUMPS_INT # MANDATORY 0 for unsymmetric, 1 for symmetric and posdef, 2 for general symmetric. All others treated as 0
    par::MUMPS_INT # MANDATORY 0 host not involved in parallel factorization and solve, 1 host is involved
    job::MUMPS_INT # MANDATORY -1 initializes package, must come first, -2 terminates, 1 analysis, 2 factorization, 3 solve, 4=1&2, 5=2&3, 6=1&2&3
    comm_fortran::MUMPS_INT # MANDATORY valid MPI communicator
    icntl::NTuple{60,MUMPS_INT}
    keep::NTuple{500,MUMPS_INT}
    cntl::NTuple{15,TR}
    dkeep::NTuple{230,TR}
    keep8::NTuple{150,MUMPS_INT8}
    n::MUMPS_INT

    nz_alloc::MUMPS_INT

    nz::MUMPS_INT
    nnz::MUMPS_INT8
    irn::Ptr{MUMPS_INT}
    jcn::Ptr{MUMPS_INT}
    a::Ptr{TC}

    nz_loc::MUMPS_INT
    nnz_loc::MUMPS_INT8
    irn_loc::Ptr{MUMPS_INT}
    jcn_loc::Ptr{MUMPS_INT}
    a_loc::Ptr{TC}

    nelt::MUMPS_INT
    eltptr::Ptr{MUMPS_INT}
    eltvar::Ptr{MUMPS_INT}
    a_elt::Ptr{TC}

    perm_in::Ptr{MUMPS_INT}

    sym_perm::Ptr{MUMPS_INT}
    uns_perm::Ptr{MUMPS_INT}

    colsca::Ptr{TR}
    rowsca::Ptr{TR}

    colsca_from_mumps::MUMPS_INT
    rowsca_from_mumps::MUMPS_INT

    rhs::Ptr{TC}
    redrhs::Ptr{TC}
    rhs_sparse::Ptr{TC}
    sol_loc::Ptr{TC}
    rhs_loc::Ptr{TC}

    irhs_sparse::Ptr{MUMPS_INT}
    irhs_ptr::Ptr{MUMPS_INT}
    isol_loc::Ptr{MUMPS_INT}
    irhs_loc::Ptr{MUMPS_INT}

    nrhs::MUMPS_INT
    lrhs::MUMPS_INT
    lredrhs::MUMPS_INT
    nz_rhs::MUMPS_INT
    lsol_loc::MUMPS_INT
    nloc_rhs::MUMPS_INT
    lrhs_loc::MUMPS_INT

    schur_mloc::MUMPS_INT
    schur_nloc::MUMPS_INT
    schur_lld::MUMPS_INT

    mblock::MUMPS_INT
    nblock::MUMPS_INT
    nprow::MUMPS_INT
    npcol::MUMPS_INT

    info::NTuple{80,MUMPS_INT}
    infog::NTuple{80,MUMPS_INT}

    rinfo::NTuple{40,TR}
    rinfog::NTuple{40,TR}

    deficiency::MUMPS_INT
    pivnul_list::Ptr{MUMPS_INT}
    mapping::Ptr{MUMPS_INT}

    size_schur::MUMPS_INT
    listvar_schur::Ptr{MUMPS_INT}
    schur::Ptr{TC}

    instance_number ::MUMPS_INT
    wk_user     ::Ptr{TC}

    version_number ::NTuple{MUMPS_VERSION_MAX_LEN+1+1,Cchar}
    ooc_tmpdir     ::NTuple{256,Cchar}
    ooc_prefix      ::NTuple{64,Cchar}
    write_problem  ::NTuple{256,Cchar}
    lwk_user    ::MUMPS_INT
    save_dir    ::NTuple{256,Cchar}
    save_prefix ::NTuple{256,Cchar}

    metis_options::NTuple{40,MUMPS_INT}

    MumpsC{T}(sym::Int,par::Int,comm) where T = new{T,real(T)}(sym,par,-1,comm)
end


# structure to store chucnks of data to keep it safe from Julia gc
mutable struct GC_haven{TC,TR}
    irn::Vector{MUMPS_INT}
    jcn::Vector{MUMPS_INT}
    a::Vector{TC}
    irn_loc::Vector{MUMPS_INT}
    jcn_loc::Vector{MUMPS_INT}
    a_loc::Vector{TC}
    eltptr::Vector{MUMPS_INT}
    eltvar::Vector{MUMPS_INT}
    a_elt::Vector{TC}
    perm_in::Vector{MUMPS_INT}
    sym_in::Vector{MUMPS_INT}
    uns_in::Vector{MUMPS_INT}
    colsca::Vector{TR}
    rowsca::Vector{TR}
    rhs::Vector{TC}
    redrhs::Vector{TC}
    rhs_sparse::Vector{TC}
    sol_loc::Vector{TC}
    rhs_loc::Vector{TC}
    irhs_sparse::Vector{MUMPS_INT}
    irhs_ptr::Vector{MUMPS_INT}
    isol_loc::Vector{MUMPS_INT}
    irhs_loc::Vector{MUMPS_INT}
    pivnul_list::Vector{MUMPS_INT}
    mapping::Vector{MUMPS_INT}
    listvar_schur::Vector{MUMPS_INT}
    schur::Vector{TC}
    wk_user::Vector{TC}

    GC_haven{T}() where T = new{T,real(T)}()
end


# structure used througout package, which contains the mumps struct as well as
# a struct to hold data to keep it safe from garbage collection (due to necessity)
# of passing pointers to MUMPS that are not safe from Julia gc
mutable struct Mumps{TC,TR}
    mumpsc::MumpsC{TC,TR}
    gc_haven::GC_haven{TC,TR}
    finalized::Bool

    function Mumps{T}(sym::Int,par::Int,comm) where T
        mumpsc = MumpsC{T}(sym,par,comm)
        invoke_mumps_unsafe!(mumpsc)
        new{T,real(T)}(mumpsc,GC_haven{T}(),false)
    end
end


# this is necessary to make the call "real(TV)" work in the inner constructor for Mumps above
function Base.real(T::TypeVar)
    if T<:Number
        return real(T)
    else
        throw(ArgumentError("real not defined for type $T"))
    end
end
