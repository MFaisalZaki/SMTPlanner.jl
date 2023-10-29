function encodestate!(step::Int, fluentslist::Vector{Term}, domain::Domain, _ctx::Z3.ContextAllocated)
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

function encodeInitialState!(_formula::Formula)
    state = initstate(_formula.domain, _formula.problem);
    # Get all the fluents in the initial state
    initialstateformula = encodestate!(0, _formula.fluents, _formula.domain, _formula.z3Context)
    # Encode those fluents into _ctx context.
    for fluent in _formula.fluents
        initialstateformula.fluentsValues[fluent] = state[fluent]
    end
    return initialstateformula
end

function increment!(_formula::Formula)
    return encodestep!(length(_formula), _formula)
end

function encodestep!(step::Int64, _formula::Formula)
    @debug "Encoding step $(step+1)"
    @debug "Encoding actions"
    _formula.formulatype == LINEAR ? (return encodesteplinear!(step, _formula)) : nothing
    @error "unkown formula type"
end

function solve!(step::Int64, _formula::Formula, goalstate::Union{Z3.ExprAllocated, Nothing}, timeout::Union{Nothing, Int64} = nothing)
   
    # Now add the initial state.
    for (f, v) in _formula.step[0].fluentsVars
        _type = Symbol(typeof(_formula.step[0].fluentsValues[f]))
        z3val = z3Type2ValFunction[_type](_formula.z3Context, _formula.step[0].fluentsValues[f])
        add(_formula.solver, v == z3val)
    end    

    # Now add the steps formulas.
    # for step in 0:length(_formula)
    for (f, action) in _formula.step[step].actions
        # Add the actions preconditions
        for actionpre in [Z3.implies(action.z3Var, precondition) for (c, precondition) in action.preconditions]
            add(_formula.solver, actionpre)
        end
        # Add the actions effects
        for actioneff in [Z3.implies(action.z3Var, effect) for (c, effect) in action.effects]
            add(_formula.solver, actioneff)
        end
        # Add the frame axioms
        for frame in _formula.step[step].frame
            add(_formula.solver, frame)
        end
    end

    !isnothing(_formula.step[step].atmostConstraint) ? add(_formula.solver, _formula.step[step].atmostConstraint) : nothing

    # Add goal state
    push!(_formula)
    isnothing(goalstate) ? nothing : add(_formula.solver, goalstate)
    isnothing(timeout) ? nothing : set(_formula.solver, "timeout", convert(UInt, timeout))
    res = check(_formula.solver) 
    res == Z3.unsat ? (pop!(_formula)) : nothing
    return res
end

function solve(mode::EncoderMode, domain::Domain, problem::Problem, upperbound::Int, iterationtimeout::Union{Nothing,Int64} = nothing)

    # Since they all follow the same structure
    state = initstate(domain, problem);
    fluents = groundfluents(domain, state);
    g_actions = groundActions(domain, state);
    
    z3ctx = Context();
    plan_formula = formula(domain, problem, state, g_actions, fluents, z3ctx, mode);
    
    # Encode the initial state.
    @debug "Encoding initial state"
    append!(plan_formula, encodeInitialState!(plan_formula)) 
    
    # Now we need to find the proper structure to maintain our required information.
    # The basic formula is I(s0) ^ T(si,si+1) ^ G(sn)
    plan_formula.solver = Solver(plan_formula.z3Context);
    foundatstep = nothing
    for step in 0:upperbound
        foundatstep = step
        z3goalstate = increment!(plan_formula)
        @debug "Solving the formula"
        res = solve!(step, plan_formula, z3goalstate, iterationtimeout)
        res == Z3.sat ? break : nothing
    end
    plan_formula.solved = (foundatstep < upperbound)
    plan_formula.solved ? (@debug "found solution at setp $(step+1)") : (@debug "No solution found in $(upperbound) steps.")
    return plan_formula
end