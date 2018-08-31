function by2x3(X,Y,class2=["S","B"],class3=["L","M","H"],quantiles=10)
    # Size classification
    a,b = missing, missing
    if X<=quantiles/2
        a = class2[1]
    else
        a = class2[2]
    end
    if Y<=quantiles/3
        b = class3[1]
    elseif Y>=2*quantiles/3
        b = class3[3]
    else
        b = class3[2]
    end
    return "$a$b"
end

function ranking(X,Y,maxrank=10)
    percentileCount = length(Y)
    for rank in 1:maxrank
        if X <= Y[Int(rank*maxrank/percentileCount)]
            return rank
            break
        end
    end
    if X >= Y[maxrank]
        return maxrank
    end
end
