function Base.string(ele::Compound)
    return string(ele.name, "(", join(string.(ele.args), "-"), ")")
end

function Base.string(ele::Const)
    return string(ele.name)
end

function Base.string(ele::GroundAction)
    return string(ele.term)
end

function Base.string(ele::Union{Const, Compound, GroundAction}, no::Int)
    return string(ele)*"@"*string(no)
end

function Base.append!(formula::Formula, formulastep::Formulastep)
    formula.step[formulastep.step] = formulastep
end

function Base.length(_formula::Formula)
    return maximum(collect(keys(_formula.step)))
end

function Base.convert(::Type{Float64}, num::Union{CxxWrap.StdLib.StdStringAllocated})
    return parse(Float64, string(num))
end

function Base.string(num::Union{CxxWrap.StdLib.StdStringAllocated})
    numstr = reinterpret(UInt8, [num[i] for i in 1:length(num)]) |> String
    return [x for x in numstr if x != '?'] |> String
end

function Base.string(x::Vector{Term})
    return join([string(y) for y in x], "->")
end
