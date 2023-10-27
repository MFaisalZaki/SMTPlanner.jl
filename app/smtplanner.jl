using Pkg
Pkg.activate(".")

using PDDL
using SMTPlanner

using PlanningDomains


roverdomain  = load_domain(IPCInstancesRepo,  "ipc-2002-depots-numeric-automatic");
roverproblem = load_problem(IPCInstancesRepo, "ipc-2002-depots-numeric-automatic", 2);

_solutionformula = solve(roverdomain, roverproblem, 100, 60000);
_solutionformula.solved
plan1, z3actins = extractplan(_solutionformula);
@assert length(plan1) > 0

# write("$(pwd())/../../test-write", plan1)


# actions = ["($(Symbol(a.name)) $(join(a.args, " ")))" for a in plan1]
# push!(actions, "; plan cost $(length(actions)) ")