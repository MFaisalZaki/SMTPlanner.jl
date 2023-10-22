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

using PDDL
using Z3

include("encodings/structs.jl")

include("exts/baseext.jl")
include("exts/z3ext.jl")

include("encodings/utils.jl")
include("encodings/linear.jl")

export Formulastep, Formula, formulastep, formula

export solve, extractPlan

end # module SMTPlanner
