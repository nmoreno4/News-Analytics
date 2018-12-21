module PtfPerf
using DataFrames, FindFcts

export ptfRet

function ptfRet(data, coll, Wfct=VWeight)
    @time Sidx = isinIDX(data, :permno, coll)
    Sdf = data[Sidx,:]
    retvec = by(Sdf, :perid) do cdf
        cdf = cdf[(!).(ismissing.(cdf[:cumret])),:] #keep only nonmissing values
        cdf = cdf[(!).(ismissing.(cdf[:wt])),:]
        Wfct(cdf, :cumret)
    end
    sort!(retvec, :perid)
    return retvec[:x1]
end

end #module
