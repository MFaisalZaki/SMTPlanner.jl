using Pkg
Pkg.activate(".")

using PDDL
using PlanningDomains


using Base: @kwdef, peek
using Base.Iterators: countfrom
using Parameters: @unpack
using AutoHashEquals: AutoHashEquals, @auto_hash_equals
using DataStructures: PriorityQueue, enqueue!, dequeue!, dequeue_pair!
using StatsBase: sample, Weights
using PDDL: flatten_conjs
using DocStringExtensions
using Random, Logging

using CxxWrap
using PDDL
using Z3


include("../src/encodings/structs.jl")

include("../src/exts/baseext.jl")
include("../src/exts/z3ext.jl")

include("../src/encodings/utils.jl")
include("../src/encodings/linear.jl")

include("../src/encodings/encoder.jl")

roverdomain  = load_domain(IPCInstancesRepo,  "ipc-2002-rovers-numeric-automatic");
roverproblem = load_problem(IPCInstancesRepo, "ipc-2002-rovers-numeric-automatic", 2);




# roverdomain  = load_domain("/home/ma342/Developer/BPlanning-Tests/TBD-Behaviour-Planning/planning-tasks/numeric-planning-tasks/ipc-2002/domains/depots-numeric-automatic/domain.pddl");
# roverproblem = load_problem("/home/ma342/Developer/BPlanning-Tests/TBD-Behaviour-Planning/planning-tasks/numeric-planning-tasks/ipc-2002/domains/depots-numeric-automatic/instances/instance-2.pddl");


_solutionformula = solve(linear, roverdomain, roverproblem, 100, 60000);
_solutionformula.solved
plan1, z3actins = extractplan(_solutionformula);
@assert length(plan1) > 0

# write("$(pwd())/../../test-write", plan1)


# actions = ["($(Symbol(a.name)) $(join(a.args, " ")))" for a in plan1]
# push!(actions, "; plan cost $(length(actions)) ")
