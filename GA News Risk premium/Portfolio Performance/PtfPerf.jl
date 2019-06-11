module PtfPerf
using DataFrames, FindFcts

export ptfRet

function ptfRet(data, coll, Wfct=VWeight)
    Sidx = isin_IDX(data, :permno, coll)
    # @time Sidx = findall(isin_IDX_old(data, :permno, coll))
    Sdf = data[Sidx,:]
    print("a \n")
    retvec = by(Sdf, :perid) do cdf
        cdf = cdf[(!).(ismissing.(cdf[:cumret])),:] #keep only nonmissing values
        cdf = cdf[(!).(ismissing.(cdf[:wt])),:]
        Wfct(cdf, :cumret)
    end
    print("b \n")
    for i in 1:(length(Set(Sdf[:perid]))-length(Set(data[:perid])))
        push!(retvec, [0,-i])
    end
    print("c \n")
    sort!(retvec, :perid)
    return retvec[:x1]
end

end #module
