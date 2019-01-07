module Buckets

using Dates
export assignBucket

function assignBucket(score, breakpoints, grades=1:length(breakpoints)+1)
    if typeof(breakpoints)==Array{DateTime,1}
        breakpoints = [Dates.DateTime(0,1,1);breakpoints;Dates.DateTime(2999,1,1)]
    elseif typeof(breakpoints)==Array{Date,1}
        breakpoints = [Dates.Date(0,1,1);breakpoints;Dates.Date(2999,1,1)]
    elseif typeof(breakpoints)==Array{Float64,1}
        breakpoints = [-Inf;breakpoints;Inf]
    elseif typeof(breakpoints)==Array{Float64,1}
        breakpoints = [-Inf;breakpoints;Inf]
    else
        return [missing]
    end
    for i in 2:length(breakpoints)
        if breakpoints[i-1] <= score < breakpoints[i]
            return grades[i-1]
            break
        end
    end
end

end #module
