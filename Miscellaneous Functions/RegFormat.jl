module RegFormat
using GLM, StatsBase

export OLScoeftableToDF


function OLScoeftableToDF(crttable)
    crttable = coeftable(crttable)
    depvars = crttable.rownms
    crtcolnames = crttable.colnms
    resDF = depvars
    for i in 1:length(crttable.cols)
        resDF = hcat(resDF, crttable.cols[i])
    end
    resDF = convert(DataFrame, resDF)
    names!(resDF, [[:depvar]; [Symbol(x) for x in crtcolnames]])
    return resDF
end

end #module
