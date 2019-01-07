module Misc

export repeatN

function repeatN(val, reps)
    res = []
    for i in 1:reps
        push!(res, val)
    end
    return res
end

end #module
