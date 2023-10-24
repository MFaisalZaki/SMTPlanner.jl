
function encodeState!(step::Int, fluentslist::Vector{Term}, domain::Domain, _ctx::Z3.ContextAllocated)
    statefluentsvars = Dict{Term, Z3.ExprAllocated}()
    for fluent in fluentslist
        if haskey(domain.functions, fluent.name)
            # This is a function
            statefluentsvars[fluent] = encodeFluentVar(fluent, :Int, step, _ctx)
        elseif haskey(domain.predicates, fluent.name)
            # This is a predicate
            statefluentsvars[fluent] = encodeFluentVar(fluent, :Bool, step, _ctx)
        elseif haskey(domain.constants, fluent.name)
            # This is a constant
            statefluentsvars[fluent] = encodeFluentVar(fluent, :Const, step, _ctx)
        else
            @assert false "Fluent $(fluent) is unkown type or we are not handling it."
        end
    end
    return formulastep(step, statefluentsvars)
end


function encodeInitialState!(domain::Domain, problem::Problem, _ctx::Z3.ContextAllocated)
    state = initstate(domain, problem);
    # Get all the fluents in the initial state
    fluents = groundfluents(domain, state)
    initialstateformula = encodeState!(0, fluents, domain, _ctx)
    # Encode those fluents into _ctx context.
    for fluent in fluents
        initialstateformula.fluentsValues[fluent] = state[fluent]
    end
    return initialstateformula
end

function encodeGoalState!(goal::Compound, fluentVars::Dict{Term, Z3.ExprAllocated}, _ctx::Z3.ContextAllocated)
    goalstate = Dict{Term, Z3.ExprAllocated}()
    for predicate in goal.args
        if predicate.name in (:+, :-, :*, :/, :<, :>, :<=, :>=, :(==), :!=)
            goalstate[predicate] = traverse_arithemric_expression(predicate, fluentVars, _ctx)
        else
            goalstate[predicate] = traverse_boolean_expression(predicate, fluentVars)
        end
    end
    return goalstate
end

function encodeAction!(step::Int, action::GroundAction, _planformula::Formula)
    pr = encodePreconditions!(action, _planformula.step[step].fluentsVars, _planformula.z3Context)
    effs = encodeEffects!(action, step, _planformula)
    return ActionFormula(action, z3Type2VarFunction[:Bool](_planformula.z3Context, string(action, step)), pr, effs)
end

function encodePreconditions!(action::GroundAction, fluentVars::Dict{Term, Z3.ExprAllocated}, _ctx::Z3.ContextAllocated)
    precondZ3 = Dict{Term, Z3.ExprAllocated}()
    for precondition in action.preconds
        if precondition.name in (:+, :-, :*, :/, :<, :>, :<=, :>=, :(==), :!=)
            precondZ3[precondition] = traverse_arithemric_expression(precondition, fluentVars, _ctx)
        else
            precondZ3[precondition] = traverse_boolean_expression(precondition, fluentVars)
        end
    end
    return precondZ3
end

function encodeEffects!(action::GroundAction, step::Int, _planformula::Formula)
    effects = Dict{Term,Z3.ExprAllocated}()

    shared_add_del_eles = intersect(Set(action.effect.add), Set(action.effect.del))

    for addeff in action.effect.add
        addeff in shared_add_del_eles ? continue : nothing
        effects[addeff] = traverse_boolean_expression(addeff, _planformula.step[step+1].fluentsVars)
    end
    
    for del in action.effect.del
        del in shared_add_del_eles ? continue : nothing
        effects[del] = Z3.not(traverse_boolean_expression(del, _planformula.step[step+1].fluentsVars))
    end
    
    for ops in action.effect.ops
        nextZ3var    = traverse_arithemric_expression(ops.first, _planformula.step[step+1].fluentsVars, _planformula.z3Context)
        currnetZ3var = traverse_arithemric_expression(ops.second, _planformula.step[step].fluentsVars, _planformula.z3Context)
        effects[ops.first] = nextZ3var == currnetZ3var
    end
    return effects
end


function encodeFrame!(plan_formula::Formula, step::Int, fluents::Vector{Term}, g_actions::Vector{GroundAction})
    frame = Z3.ExprAllocated[]
    for fluent in fluents
        _pre  = get(plan_formula.step[step].fluentsVars, fluent, nothing)
        _post = get(plan_formula.step[step+1].fluentsVars, fluent, nothing)
        
        if isnothing(_pre) || isnothing(_post)
            continue
        end

        if Z3.is_bool(_pre)
            actionadd = Z3.ExprAllocated[]
            actiondel = Z3.ExprAllocated[]
            
            for action in g_actions
                fluent in action.effect.add ? push!(actionadd, plan_formula.step[step].actions[action.term].z3Var) : nothing
                fluent in action.effect.del ? push!(actiondel, plan_formula.step[step].actions[action.term].z3Var) : nothing
            end
            
            addExprVector = Z3.ExprVector(plan_formula.z3Context, [v for v in actionadd]);
            delExprVector = Z3.ExprVector(plan_formula.z3Context, [v for v in actiondel]);
            
            push!(frame, Z3.implies(Z3.and(Z3.ExprVector(plan_formula.z3Context, [Z3.not(_pre), _post])), Z3.or(addExprVector)))
            push!(frame, Z3.implies(Z3.and(Z3.ExprVector(plan_formula.z3Context, [_pre, Z3.not(_post)])), Z3.or(delExprVector)))
        else
            actionnum = Z3.ExprAllocated[]
            for action in g_actions
                fluentset = Set{Term}()
                for ops in action.effect.ops
                    collect_arithemric_expression_fluents!(ops.second, plan_formula.step[0].fluentsVars, fluentset)
                end

                if fluent in fluentset
                    push!(actionnum, plan_formula.step[step].actions[action.term].z3Var)
                end                
            end
            push!(actionnum, _pre == _post)
            push!(frame, Z3.or(Z3.ExprVector(plan_formula.z3Context, actionnum)))
        end
    end
    return frame
end

function encodestep!(step::Int64, _formula::Formula, fluents::Vector{Term})
    @info "Encoding step $(step+1)"
    @debug "Encoding actions"
    for action in _formula.groundedactions
        append!(_formula, encodeState!(step+1, fluents, _formula.domain, _formula.z3Context));
        _formula.step[step].actions[action.term] = encodeAction!(step, action, _formula);
    end
    _formula.step[step].atmostConstraint = Z3.atmost(Z3.ExprVector(_formula.z3Context, [a.second.z3Var for a in _formula.step[step].actions]), 1)
    _formula.step[step].frame = encodeFrame!(_formula, step, fluents, _formula.groundedactions)
    @debug "Encoding goal state"
    goalstate = encodeGoalState!(_formula.problem.goal, _formula.step[step+1].fluentsVars, _formula.z3Context)
    z3goalstate = Z3.and(Z3.ExprVector(_formula.z3Context, [var for (f, var) in goalstate]))
    return z3goalstate
end

function solve(domain::Domain, problem::Problem, upperbound::Int)
    state = initstate(domain, problem);
    fluents = groundfluents(domain, state);
    g_actions = groundActions(domain, state);
    
    z3ctx = Context();
    plan_formula = formula(domain, problem, state, g_actions, z3ctx);
    
    # Encode the initial state.
    @debug "Encoding initial state"
    append!(plan_formula, encodeInitialState!(plan_formula.domain, plan_formula.problem, plan_formula.z3Context));
    
    # Now we need to find the proper structure to maintain our required information.
    # The basic formula is I(s0) ^ T(si,si+1) ^ G(sn)
    solver = Solver(plan_formula.z3Context);
    for step in 0:upperbound
        z3goalstate = encodestep!(step, plan_formula, fluents)
        @debug "Solving the formula"
        plan_formula.solver = solve!(solver, step, plan_formula, z3goalstate)
        !isnothing(plan_formula.solver) ? (@info "Found solution at $(step+1)", return plan_formula) : nothing
    end
    @info "No solution found in $(upperbound) steps."
    return plan_formula
end

function solve!(solver::Z3.SolverAllocated, step::Int64, _formula::Formula, goalstate::Union{Z3.ExprAllocated, Nothing})
   
    # Now add the initial state.
    for (f, v) in _formula.step[0].fluentsVars
        _type = Symbol(typeof(_formula.step[0].fluentsValues[f]))
        z3val = z3Type2ValFunction[_type](_formula.z3Context, _formula.step[0].fluentsValues[f])
        add(solver, v == z3val)
    end    

    # Now add the steps formulas.
    # for step in 0:length(_formula)
    for (f, action) in _formula.step[step].actions
        # Add the actions preconditions
        for actionpre in [Z3.implies(action.z3Var, precondition) for (c, precondition) in action.preconditions]
            add(solver, actionpre)
        end
        # Add the actions effects
        for actioneff in [Z3.implies(action.z3Var, effect) for (c, effect) in action.effects]
            add(solver, actioneff)
        end
        # Add the frame axioms
        for frame in _formula.step[step].frame
            add(solver, frame)
        end
    end
    
    !isnothing(_formula.step[step].atmostConstraint) ? add(solver, _formula.step[step].atmostConstraint) : nothing

    # Add goal state
    push(solver)
    isnothing(goalstate) ? nothing : add(solver, goalstate)

    return check(solver) == Z3.sat ? (solver) : ( pop(solver,1), return nothing)
end
