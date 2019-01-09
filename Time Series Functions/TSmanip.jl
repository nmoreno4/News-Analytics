module TSmanip

using TSmap, DataFrames, Statistics, StatsBase, FindFcts
export ret2tick, cumret2, cumret, aggRetByPeriod, aggNewsByPeriod, NSsuprise, computeNS

function ret2tick(vec::AbstractArray, val=100 ; ignoremissing=false, dropinception=false)
    res = Float64[val]
    for i in vec
        if ignoremissing
            if !ismissing(i)
                val*=(1+i)
                push!(res, val)
            end
        else
            if ismissing(i)
                i=0
            end
            val*=(1+i)
            push!(res, val)
        end
    end
    if dropinception
        return res[2:end]
    else
        return res
    end
end

function cumret2(vec::AbstractArray)
    prices = ret2tick(vec)
    res = (prices[end]-prices[1])/prices[1]
    if length(vec)>0
        return res
    else
        return missing
    end
end

"""
Computes the cumulative return of an array of returns. Ignores missing values.
"""
function cumret(X)
    a = geomean(1 .+ skipmissing(X))
    res = cumprod(repeat([a],length(X)))[end] - 1
    return res
end


"""
For returns it makes more sense to let the returns drift first.
If you choose to ignore this advice and compute the weighting after this frequency
adjustment, the function gives you the average :me over the period.

stockCol = false or :permno
"""
function aggRetByPeriod(perFct, crtdf, retCol; meCol=false, dateCol=:date, stockCol=:permno)
    if typeof(stockCol)!=Symbol
        stockCol = :commonID
        crtdf[stockCol] = 1
    end
    crtdf[:perID] = perFct.(crtdf[dateCol])
    if typeof(meCol)==Symbol
        res = by(crtdf, [stockCol, :perID], aggRet = retCol => x -> cumret(x),
                                            me = meCol => x -> mean(x))
    else
        res = by(crtdf, [stockCol, :perID], aggRet = retCol => x -> cumret(x))
    end
    return res
end


"""
For :me output, I decide to taake the average me of a stock over the period.
The reasoning is the following: I know all the information until the last news.
Since I want the market importance of a stock's news over the period, the most
sensible thing to do is to assign it it's average market equity. Otherwise I either
favor winning stock (if I take last me) or losing stock (if I take first me).

stockCol = false or :permno
"""
function aggNewsByPeriod(perFct, crtdf, totNews, posNews, negNews, meCol, dateCol=:date, stockCol=:permno)
    # Check if stockCol exists!
    if typeof(stockCol)!=Symbol
        stockCol = :commonID
        crtdf[stockCol] = 1
    end
    crtdf[:perID] = perFct.(crtdf[dateCol])
    result = by(crtdf, [stockCol, :perID]) do xdf
        res = Dict()
        res[:NS] = (sum(skipmissing(xdf[:,posNews])) - sum(skipmissing(xdf[:,negNews]))) / sum(skipmissing(xdf[:,totNews]))
        res[:me] = mean(xdf[:,meCol])
        DataFrame(res)
    end
    result[:NS] = replace(result[:NS], NaN=>missing)
    return result
end



"""
TO-DO: Implement a version where instead of looking x observations back I look x "DAYS" back
"""
function NSsuprise(crtdf, LTspan, STspan, iS, newsTopics, wCol=:driftW)
    topicLT = newsTopics[1]
    topicST = newsTopics[2]
    res = by(crtdf, [:permno]) do xdf
        res = Dict()
        T = size(xdf,1) #Total number of observations
        nbObs = length(1:iS:(T-(LTspan+STspan)+1))
        if nbObs>0
            NSsurp = zeros(nbObs)
            for (j,k) in zip(1:iS:(T-(LTspan+STspan)+1), (LTspan+1):iS:T)
                LTdf = xdf[(j:(k-1)), :]
                LTNS = computeNS(LTdf, topicLT[1], topicLT[2], topicLT[3])
                STdf = xdf[(k:(k+STspan-1)), :]
                STNS = computeNS(STdf, topicST[1], topicST[2], topicST[3])
                NSsurp[j] = LTNS-STNS
            end
            res[:NSsurp] = replace(NSsurp, NaN=>missing)
            res[:date] = xdf[(LTspan+STspan):end, :date]
            res[wCol] = xdf[(LTspan+STspan):end, wCol]
        else
            res[:NSsurp] = missing
            res[:date] = missing
            res[wCol] = missing
        end
        DataFrame(res)
    end
    return deleteMissingRows(res, :date)
end


function computeNS(cdf, countCol, posCol, negCol)
    pos = sum(skipmissing(cdf[posCol]))
    neg = sum(skipmissing(cdf[negCol]))
    totNews = sum(skipmissing(cdf[countCol]))
    return (pos-neg)/totNews
end


end #module
