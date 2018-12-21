module RetManip
using Statistics

export VWeight, EWeight, cumret, ret2tick

function VWeight(v, namestoVW)
    res = Dict()
    totweight = sum(v[:wt])
    stockweight = v[:wt] ./ totweight
    return sum(v[namestoVW] .* stockweight)
end

function EWeight(v, namestoVW)
    res = Dict()
    totweight = sum(v[:wt])
    stockweight = mean(v[:wt]) ./ totweight
    return sum(v[namestoVW] .* stockweight)
end

function cumret(vec)
    prices = ret2tick(vec)
    res = (prices[end]-prices[1])/prices[1]
    if length(vec)>0
        return res
    else
        return missing
    end
end

function ret2tick(vec, val=100)
    res = Float64[val]
    for i in vec
        if ismissing(i)
            i=0
        end
        val*=(1+i)
        push!(res, val)
    end
    return res
end

end #module
