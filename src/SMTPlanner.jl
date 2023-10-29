module SMTPlanner

using Base: @kwdef, peek
using Base.Iterators: countfrom
using Parameters: @unpack
using AutoHashEquals: AutoHashEquals, @auto_hash_equals
using DataStructures: PriorityQueue, enqueue!, dequeue!, dequeue_pair!
using StatsBase: sample, Weights
using PDDL: flatten_conjs
using DocStringExtensions
using Random, Logging
using DataStructures

using CxxWrap
using PDDL
using Z3

include("encodings/structs.jl")

include("exts/baseext.jl")
include("exts/z3ext.jl")

include("encodings/utils.jl")

include("encodings/linear.jl")
include("encodings/r2e.jl")
include("encodings/encoder.jl")

export Formulastep, Formula, formulastep, formula

export solve, solve!, extractplan

export encodeInitialState!, encodeGoalState!, encodestatelinear!, encodeaction!, encodeframe!, encodestep!, increment!

export get_decls, dump, z3LogicalOperations, z3ArithmeticOperation, z3Type2VarFunction, z3Type2ValFunction, check, get_model

end # module SMTPlanner
