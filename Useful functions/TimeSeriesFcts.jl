module TimeSeriesFcts
export cumret, TStoArray, nonnanidx, cumlogret

function cumret(x, s = 1)
    res = Float64[s]
    cc=0
    for ret in x
        cc+=1
        push!(res, res[cc]*(1+ret))
    end
    return res
end

function cumlogret(x)
    return sum([!ismissing(r) ? log(1+r) : 0 for r in x])
end

function TStoArray(TS)
    res = Float64[]
    x=collect(TS)
    for row in x
        push!(res, row[2][1])
    end
    return res
end

function nonnanidx(x)
    res=Int[]
    cc=0
    for i in x
        cc+=1
        if !isnan(i)
            push!(res, cc)
        end
    end
    return res
end

end #module
