# Note this dict should be extened by time to cover all possibile types.

z3Type2ValFunction = Dict{Symbol, Function}(:Bool  => bool_val, 
                                            :Real  => real_val, 
                                            :Int   => int_val,
                                            :Int64   => int_val,
                                            :Const => real_val)

z3Type2VarFunction = Dict{Symbol, Function}(:Bool  => bool_const, 
                                            :Real  => real_const, 
                                            :Int   => int_const, 
                                            :Int64 => int_const, 
                                            :Const => real_const)

z3ArithmeticOperation = Dict(
    :+    => (+),
    :-    => (-),
    :*    => (*),
    :/    => (/),
    :<    => (<),
    :>    => (>),
    :<=   => (<=),
    :>=   => (>=),
    :(==) => (==),
    :!=   => (!=)
)

z3LogicalOperations = Dict(
    :and => (Z3.and),
    :or => (Z3.or),     
    :not => (Z3.not),          
    :implies => (Z3.implies)
)

get_decls(m::Model) = [get_const_decl(m, i) for i in 0:num_consts(m) - 1]

function dump(s::Z3.SolverAllocated, name::String)
    decls      = [string(dec) for dec in get_decls(get_model(s))]
    assersions = ["(assert $a)" for a in Z3.assertions(s)]
    modelsexpr = vcat(decls, assersions)
    open(name, "w") do io
        for line in modelsexpr
            write(io, "$line\n")
        end
    end
end
