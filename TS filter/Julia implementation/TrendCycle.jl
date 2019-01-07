module TrendCycle

using RCall, SparseArrays
export HPfilter, neverHPfilter

function HPfilter(y::Vector{Float64}, lambda::Number)
    n = length(y)
    @assert n >= 4

    diag2 = lambda*ones(n-2)
    diag1 = [ -2lambda; -4lambda*ones(n-3); -2lambda ]
    diag0 = [ 1+lambda; 1+5lambda; (1+6lambda)*ones(n-4); 1+5lambda; 1+lambda ]

    D = spdiagm(-2=>diag2, -1=>diag1, 0=>diag0, 1=>diag1, 2=>diag2)

    return D\y
end

function neverHPfilter()
    R""
end

end #module
