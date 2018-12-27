module Windsorize

using StatsBase
export windsorize

function windsorize(X, toplevel, bottomlevel, extremVec=false)
    extremes = Float64[]
    topthresh = percentile(convert(Array{Float64}, X),toplevel)
    bottomthresh = percentile(convert(Array{Float64}, X),bottomlevel)
    for i in 1:length(X)
        if X[i]>topthresh
            push!(extremes,i)
            X[i] = topthresh
        end
        if X[i]<bottomthresh
            push!(extremes,i)
            X[i] = bottomthresh
        end
    end
    if extremVec
        return X, extremVec
    else
        return X
    end
end

end #module
