@enum EncoderMode begin
    linear = 1
    r2e = 2
end


function solve(mode::EncoderMode, domain::Domain, problem::Problem, upperbound::Int, iterationtimeout::Union{Nothing,Int64} = nothing)
    mode == linear ? (return solvelinear(domain, problem, upperbound, iterationtimeout)) : nothing

end