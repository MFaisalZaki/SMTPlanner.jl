# Planning graph utilities for relaxed heuristic computation

"Planning graph used by relaxation-based heuristics."
mutable struct PlanningGraph
    n_axioms::Int # Number of ground actions converted from axioms
    n_goals::Int # Number of ground actions converted from goals
    actions::Vector{GroundAction} # All ground actions
    act_parents::Vector{Vector{Vector{Int}}} # Parent conditions of each action
    act_children::Vector{Vector{Int}} # Child conditions of each action
    effect_map::Dict{Term,Vector{Int}} # Map of affected fluents to actions
    conditions::Vector{Term} # All ground preconditions / goal conditions
    cond_children::Vector{Vector{Tuple{Int,Int}}} # Child actions of each condition
    cond_derived::BitVector # Whether the conditions are derived
    cond_functional::BitVector # Whether the conditions involve functions
end

# abstract type Specification end
# abstract type Solution end
# abstract type Heuristic end
# abstract type Planner end


# """
#     build_planning_graph(domain, state, [goal::Specification])

# Construct planning graph for a `domain` grounded in a `state`, with an
# optional `goal` specification that will be converted to action nodes.
# """
# function build_planning_graph(domain::Domain, state::State, goal::Specification;
#                               kwargs...)
#     goal = Compound(:and, get_goal_terms(goal))
#     return build_planning_graph(domain, state, goal; kwargs...)
# end

function ground_problem_actions(domain::Domain, state::State)
    return build_planning_graph(domain, state).actions
end

function build_planning_graph(
    domain::Domain, state::State, goal::Union{Term,Nothing}=nothing;
    statics = infer_static_fluents(domain),
    relevants = isnothing(goal) ? nothing : infer_relevant_fluents(domain, goal)
)
    # Populate list of ground actions and converted axioms
    actions = GroundAction[]
    # Add axioms converted to ground actions
    for (name, axiom) in pairs(PDDL.get_axioms(domain))
        if !isnothing(goal) && !(name in relevants)
            continue # Skip irrelevant axioms if goal is known
        end 
        for ax in groundaxioms(domain, state, axiom; statics=statics)
            if ax.effect isa PDDL.GenericDiff
                push!(actions, ax)
            else # Handle conditional effects
                append!(actions, PDDL.flatten_conditions(ax))
            end
        end
    end
    n_axioms = length(actions)
    # Add ground actions, flattening conditional actions
    for act in groundactions(domain, state; statics=statics)
        # TODO: Eliminate redundant actions
        if act.effect isa PDDL.GenericDiff
            push!(actions, act)
        else # Handle conditional effects
            append!(actions, PDDL.flatten_conditions(act))
        end
    end
    # Add goals converted to ground actions
    n_goals = 0
    if !isnothing(goal)
        goal_actions = pgraph_goal_to_actions(domain, state, goal;
                                              statics=statics)
        n_goals = length(goal_actions)
        append!(actions, goal_actions)
    end
    # Extract conditions and effects of ground actions
    cond_map = Dict{Term,Vector{Tuple{Int,Int}}}() # Map conditions to action indices
    effect_map = Dict{Term,Vector{Int}}() # Map effects to action indices
    for (i, act) in enumerate(actions)
        # Limit number of conditions to max limit of Sys.WORD_SIZE
        if length(act.preconds) > Sys.WORD_SIZE
            resize!(act.preconds, Sys.WORD_SIZE)
        end
        preconds = isempty(act.preconds) ? Term[Const(true)] : act.preconds
        for (j, cond) in enumerate(preconds) # Preconditions
            if cond.name == :or # Handle disjunctions
                for c in cond.args
                    idxs = get!(Vector{Tuple{Int,Int}}, cond_map, c)
                    push!(idxs, (i, j)) # Map to jth condition of ith action
                end
            else
                idxs = get!(Vector{Tuple{Int,Int}}, cond_map, cond)
                push!(idxs, (i, j)) # Map to jth condition of ith action
            end
        end
        for eff in act.effect.add # Add effects
            idxs = get!(Vector{Int}, effect_map, eff)
            push!(idxs, i)
        end
        for eff in act.effect.del # Delete effects
            idxs = get!(Vector{Int}, effect_map, Compound(:not, Term[eff]))
            push!(idxs, i)
        end
        for (term, _) in act.effect.ops # Assignment effects
            idxs = get!(Vector{Int}, effect_map, term)
            push!(idxs, i)
        end
    end
    # Flatten map from conditions to child indices
    cond_children = collect(values(cond_map))
    conditions = collect(keys(cond_map))
    # Determine parent and child conditions of each action
    act_parents = map(actions) do act 
        [Int[] for _ in 1:min(Sys.WORD_SIZE, length(act.preconds))]
    end
    act_children = [Int[] for _ in actions]
    for (i, cond) in enumerate(conditions)
        # Collect parent conditions
        idxs = get(Vector{Tuple{Int,Int}}, cond_map, cond)
        for (act_idx, precond_idx) in idxs
            push!(act_parents[act_idx][precond_idx], i)
        end
        # Collect child conditions
        if cond.name in (:not, true, false) || PDDL.is_pred(cond, domain)
            idxs = get(Vector{Int}, effect_map, cond) # Handle literals
        else # Handle functional terms
            terms = PDDL.constituents(cond, domain)
            idxs = reduce(union, (get(Vector{Int}, effect_map, t) for t in terms))
        end
        push!.(act_children[idxs], i)
    end
    act_children = unique!.(sort!.(act_children))
    # Determine if conditions are derived or functional
    cond_derived = isempty(PDDL.get_axioms(domain)) ?
        falses(length(conditions)) :
        broadcast(c -> PDDL.has_derived(c, domain), conditions)
    cond_functional = isempty(PDDL.get_functions(domain)) ?
        falses(length(conditions)) :
        broadcast(c -> PDDL.has_func(c, domain) ||
                       PDDL.has_global_func(c), conditions)
    # Construct and return graph
    return PlanningGraph(
        n_axioms, n_goals, actions, act_parents, act_children, effect_map,
        conditions, cond_children, cond_derived, cond_functional
    )
end


function groundActions(domain::Domain, state::State)
    return build_planning_graph(domain, state).actions
end


function groundfluents(domain::Domain, state::State, fluent::Symbol)
    return [Compound(fluent, collect(Term, args)) for args in 
                PDDL.groundargs(domain, state, fluent)]
end

function groundfluents(domain::Domain, state::State)
     fluent_terms = Term[]
     for (name, signature) in PDDL.get_fluents(domain)
            append!(fluent_terms, groundfluents(domain, state, name))
     end
     return fluent_terms
end

function encodeFluentVar(f::Compound, type::Symbol, timestep::Int, _ctx::Z3.ContextAllocated)
    return z3Type2VarFunction[type](_ctx, string(f, timestep))
end


function encodeFluentVarVal(f::Compound, val::Union{Bool,Int,Float64}, timestep::Int, _ctx::Z3.ContextAllocated)
    z3val = z3Type2ValFunction[Symbol(typeof(val))](_ctx, val)
    z3var = z3Type2VarFunction[Symbol(typeof(val))](_ctx, string(f, timestep))
    return z3var, z3val
end


# Define a function to traverse expressions
function traverse_arithemric_expression(expr::Union{Const,Compound}, varslist::Dict{Term, Z3.ExprAllocated}, _ctx::Z3.ContextAllocated)
    if expr.name in (:+, :-, :*, :/, :<, :>, :<=, :>=, :(==), :!=)
        # We know that the expression in PDDL is two operands only
        loperand = traverse_arithemric_expression(expr.args[1], varslist, _ctx)
        roperand = traverse_arithemric_expression(expr.args[2], varslist, _ctx)
        return z3ArithmeticOperation[expr.name](loperand, roperand)
    elseif haskey(varslist, expr)
        # You can perform some action on non-expression elements here
        return varslist[expr]
    else
        return z3Type2ValFunction[Symbol(typeof(expr))](_ctx, string(expr))
    end
end

function traverse_boolean_expression(expr::Union{Const,Compound}, varslist::Dict{Term, Z3.ExprAllocated})
    if expr.name in (:and, :or)
        # We know that the expression in PDDL is two operands only
        loperand = traverse_boolean_expression(expr.args[1], varslist)
        roperand = traverse_boolean_expression(expr.args[2], varslist)
        return z3LogicalOperations[expr.name](loperand, roperand)
    elseif expr.name == :not
        # We know that the expression in PDDL is two operands only
        return z3LogicalOperations[expr.name](traverse_boolean_expression(expr.args[1], varslist))
    elseif haskey(varslist, expr)
        # You can perform some action on non-expression elements here
        return varslist[expr]
    end
end

function collect_arithemric_expression_fluents!(expr::Union{Const,Compound}, varslist::Dict{Term, Z3.ExprAllocated}, retset::Set{Term})
    if expr.name in (:+, :-, :*, :/, :<, :>, :<=, :>=, :(==), :!=)
        # We know that the expression in PDDL is two operands only
        collect_arithemric_expression_fluents!(expr.args[1], varslist, retset)
        collect_arithemric_expression_fluents!(expr.args[2], varslist, retset)
    elseif haskey(varslist, expr)
        # You can perform some action on non-expression elements here
        push!(retset, expr)
    end
end

# Now we need to extract the plan from the model.
function extractplan(planformula::Formula)
    isnothing(planformula.solver) && return Term[]
    model = get_model(planformula.solver);
    plan = Term[]
    z3actions = Z3.ExprAllocated[]
    for step in 0:length(planformula)
        _formula_at_step = planformula.step[step];
        for (action, z3action) in _formula_at_step.actions
            if Z3.is_true(Z3.eval(model, z3action.z3Var))
                push!(plan, action)
                push!(z3actions, z3action.z3Var)
                break
            end
        end
    end
    # Now validate the plan
    end_state = PDDL.simulate(EndStateSimulator(), planformula.domain, planformula.initialstate, plan);
    return satisfy(planformula.domain, end_state, planformula.problem.goal) ? (plan, z3actions) : (Term[], Z3.ExprAllocated[])
end