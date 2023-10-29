function encodestater2e!(step::Int, _formula::Formula)
    statefluentsvars = Dict{Term, Union{Z3.ExprAllocated, Deque{Z3.ExprAllocated}}}()
    for fluent in fluentslist
        !haskey(statefluentsvars, fluent) ? (statefluentsvars[fluent] = Deque{Z3.ExprAllocated}()) : nothing
        push!(statefluentsvars[fluent],  encodefluentvar(fluent, getfluentz3type(domain, fluent), step, _ctx))
    end

    if step == 0
        # Add here the initial state variables.
    end
    
    return formulastep(step, statefluentsvars)
end


function encodestepr2e!(step::Int64, _formula::Formula)
    @debug "Encoding step $(step+1)"
    @debug "Encoding actions"
    for action in sort(_formula.groundedactions)
        append!(_formula, encodestater2e!(step, _formula));
        _formula.step[step].actions[action.term] = encodeactionr2e!(step, action, _formula);
    end
    goalstate = encodeGoalStater2e!(_formula.problem.goal, _formula.step[step+1].fluentsVars, _formula.z3Context)
    z3goalstate = Z3.and(Z3.ExprVector(_formula.z3Context, [var for (f, var) in goalstate]))
    return z3goalstate
end

function encodeactionr2e!(step::Int, action::GroundAction, _planformula::Formula)
   
    
   
    # So R2e is about chaining variables. But we need to construct the 
    @error "r2e encode action not implemented yet." 
end

function encodeGoalStater2e!(goal::Compound, fluentVars::Dict{Term, Z3.ExprAllocated}, _ctx::Z3.ContextAllocated)
    @error "r2e encode goal state not implemented yet."
end

