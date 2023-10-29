
function encodestatelinear!(step::Int, _f::Formula)
    statefluentsvars = Dict{Term, Union{Z3.ExprAllocated, Deque{Z3.ExprAllocated}}}()
    for fluent in _f.fluents
        statefluentsvars[fluent] = encodefluentvar(fluent, getfluentz3type(_f.domain, fluent), step, _f.z3Context)
    end
    return formulastep(step, statefluentsvars)
end

function encodeGoalStatelinear!(goal::Compound, fluentVars::Dict{Term, Union{Z3.ExprAllocated, Deque{Z3.ExprAllocated}}}, _ctx::Z3.ContextAllocated)
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

function encodeactionlinear!(step::Int, action::GroundAction, _planformula::Formula)
    pr = encodepreconditionslinear!(action, _planformula.step[step].fluentsVars, _planformula.z3Context)
    effs = encodeeffectslinear!(action, step, _planformula)
    return ActionFormula(action, z3Type2VarFunction[:Bool](_planformula.z3Context, string(action, step)), pr, effs)
end

function encodepreconditionslinear!(action::GroundAction, fluentVars::Dict{Term, Union{Z3.ExprAllocated, Deque{Z3.ExprAllocated}}}, _ctx::Z3.ContextAllocated)
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

function encodeeffectslinear!(action::GroundAction, step::Int, _planformula::Formula)
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

function encodeframelinear!(plan_formula::Formula, step::Int)
    frame = Z3.ExprAllocated[]
    for fluent in plan_formula.fluents
        _pre  = get(plan_formula.step[step].fluentsVars, fluent, nothing)
        _post = get(plan_formula.step[step+1].fluentsVars, fluent, nothing)
        
        if isnothing(_pre) || isnothing(_post)
            continue
        end

        if Z3.is_bool(_pre)
            actionadd = Z3.ExprAllocated[]
            actiondel = Z3.ExprAllocated[]
            
            for action in plan_formula.groundedactions
                fluent in action.effect.add ? push!(actionadd, plan_formula.step[step].actions[action.term].z3Var) : nothing
                fluent in action.effect.del ? push!(actiondel, plan_formula.step[step].actions[action.term].z3Var) : nothing
            end
            
            addExprVector = Z3.ExprVector(plan_formula.z3Context, [v for v in actionadd]);
            delExprVector = Z3.ExprVector(plan_formula.z3Context, [v for v in actiondel]);
            
            push!(frame, Z3.implies(Z3.and(Z3.ExprVector(plan_formula.z3Context, [Z3.not(_pre), _post])), Z3.or(addExprVector)))
            push!(frame, Z3.implies(Z3.and(Z3.ExprVector(plan_formula.z3Context, [_pre, Z3.not(_post)])), Z3.or(delExprVector)))
        else
            actionnum = Z3.ExprAllocated[]
            for action in plan_formula.groundedactions
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


function encodesteplinear!(step::Int64, _formula::Formula)
    @debug "Encoding step $(step+1)"
    @debug "Encoding actions"
    for action in _formula.groundedactions
        append!(_formula, encodestatelinear!(step+1, _formula));
        _formula.step[step].actions[action.term] = encodeactionlinear!(step, action, _formula);
    end
    _formula.step[step].atmostConstraint = Z3.atmost(Z3.ExprVector(_formula.z3Context, [a.second.z3Var for a in _formula.step[step].actions]), 1)
    _formula.step[step].frame = encodeframelinear!(_formula, step)
    @debug "Encoding goal state"
    goalstate = encodeGoalStatelinear!(_formula.problem.goal, _formula.step[step+1].fluentsVars, _formula.z3Context)
    z3goalstate = Z3.and(Z3.ExprVector(_formula.z3Context, [var for (f, var) in goalstate]))
    return z3goalstate
end
