
struct ActionFormula
    name::Compound
    z3Var::Z3.ExprAllocated
    preconditions::Dict{Term,Z3.ExprAllocated}
    effects::Dict{Term,Z3.ExprAllocated}
end

# Do we need to have this mutable?!
mutable struct Formulastep
    step::Int64
    fluentsVars::Dict{Term, Z3.ExprAllocated}
    fluentsValues::Dict{Term, Any}
    actions::Dict{Term, ActionFormula}
    atmostConstraint::Union{Z3.ExprAllocated, Nothing}
    frame::Union{Vector{Z3.ExprAllocated}, Nothing}
end

mutable struct Formula
    domain::Domain
    problem::Problem
    initialstate::GenericState
    z3Context::Z3.ContextAllocated
    step::Dict{Int64, Formulastep}
    solver::Union{Z3.SolverAllocated, Nothing}
end

function formulastep(step::Int64, fluentsVars::Dict{Term, Z3.ExprAllocated})
    Formulastep(step, fluentsVars, Dict{Term, Z3.ExprAllocated}(), Dict{Term, ActionFormula}(), nothing, nothing)
end    

function formulastep(step::Int64, fluentsVars::Dict{Term, Z3.ExprAllocated}, fluentsVals::Dict{Term, Z3.ExprAllocated})
    Formulastep(step, fluentsVars, fluentsVals, Dict{Term, ActionFormula}(), nothing, nothing)
end    

function formulastep(step::Int64, fluentsVars::Dict{Term, Z3.ExprAllocated}, fluentsVals::Dict{Term, Z3.ExprAllocated}, actions::Dict{Term, ActionFormula})
    Formulastep(step, fluentsVars, fluentsVals, actions, nothing, nothing)
end    

function formula(domain::Domain, problem::Problem, state::GenericState, _ctx::Z3.ContextAllocated)
    Formula(domain, problem, state, _ctx, Dict{Int64, Formulastep}(), nothing)
end
