using Pkg
Pkg.activate(".")

using PDDL
using SMTPlanner



using PlanningDomains


roverdomain  = load_domain(IPCInstancesRepo,  "ipc-2002-rovers-strips-automatic");
roverproblem = load_problem(IPCInstancesRepo, "ipc-2002-rovers-strips-automatic", 3);


_solutionformula = solve(roverdomain, roverproblem, 100);
plan1, z3actins = extractplan(_solutionformula);
@assert length(plan1) > 0

