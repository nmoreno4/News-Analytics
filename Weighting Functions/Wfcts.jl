module Wfcts

using DataFrames, RollingFunctions, ShiftedArrays, TSmap, Dates, Buckets, TSmanip
export FFweighting, varWeighter, rebalPeriods, driftWeights, everyDayWeights


function FFweighting(crtdf, timeVar, wVar, iVar)
    error("Not working because of repeat?")
    crtdf[:perTotW] = by(crtdf, timeVar, totW = wVar => x -> repeat([sum(skipmissing(x))],length(x)) )[:totW]
    crtdf[:relW] = crtdf[wVar] ./ crtdf[:perTotW]
    crtdf[:contrib] = crtdf[iVar] .* crtdf[:relW]
    # Control the weights of all dates sum to 1
    # by(crtdf, timeVar, x1 = :relW => x -> sum(skipmissing(x)))
    res = by(crtdf, timeVar, x1 = :contrib => x -> sum(skipmissing(x)))
    return res
end



function simpleEW(crtdf, timeVar, wVar, iVar)
    crtdf[:perTotW] = by(crtdf, timeVar, nbStocks = iVar => x -> repeat([length(collect(skipmissing(x)))],length(x)) )[:nbStocks]
    crtdf[:contrib] = crtdf[iVar] .* (1 ./ crtdf[:perTotW])
    # Control the weights of all dates sum to 1
    # by(crtdf, timeVar, x1 = :relW => x -> sum(skipmissing(x)))
    res = by(crtdf, timeVar, x1 = :contrib => x -> sum(skipmissing(x)))
    return res
end



"""
From a DataFrame containing an array of dates [datesCol], add a column allowing the
grouping between two rebalancement dates. Rebalancing dates can either be identified
by indicating the number of periods between two rebalancements [nbPeriods], or each time
the date hits a specific period [rebalPer] (e.g. month, week, year).
Specify either [nbPeriods] OR [rebalPer].
"""
function rebalPeriods(cdf, datesCol; nbPeriods=false, rebalPer=false, everyday=false)
    dVec = cdf[datesCol]
    daysToKeep = typeof(dVec[1])[]
    if typeof(rebalPer)!=Bool && !nbPeriods && !everyday
        possibleRebalDays = minimum(dVec):Dates.Day(1):maximum(dVec)
        dayIDfunc, rebalID = rebalPer[1], rebalPer[2]
        if !(typeof(rebalID)<:AbstractArray)
            error("The second element of rebalPer must be an Array (even if a single value)")
        end
        for d in possibleRebalDays
            if dayIDfunc(d) in rebalID
                push!(daysToKeep, d)
            end
        end
    elseif typeof(nbPeriods)!=Bool && !rebalPer && !everyday
        print("The method where rebalancement every X days is made needs still to be implemented!")
    elseif everyday && !rebalPer && !nbPeriods
        res = ones(size(cdf, 1))
    else
        error("You need to specify either [nbPeriods] or [rebalPer] or [everyday]!!")
    end

    if !everyday
        res = typeof(daysToKeep[1])[]
        for i in dVec
            push!(res, assignBucket(i, daysToKeep, [dVec[1]-Dates.Day(1); daysToKeep]) )
        end
    end

    return res
end



function everyDayWeights(crtdf, WS; meCol=:me, stockCol=:permno, dateCol=:date)
   result = by(crtdf, dateCol) do xdf
       res = Dict()

       if WS=="EW"
           res[:W] = (xdf[:,meCol] .* 0 .+ 1) ./ length(collect(skipmissing(xdf[:,meCol])))
       elseif WS=="VW"
           res[:W] = xdf[:,meCol] ./ sum(skipmissing(xdf[:,meCol]))
       end
       DataFrame(res)
   end
   return result[:W]
end



"""
Returns a column of drifted weights of the same size as the initial input DF.
Is helpful for VW only for stocks that had a weight of 0% at the beginning
of the period.
"""
function driftWeights(crtdf, WS; rebalCol=:rebalPer, meCol=:me, stockCol=:permno, dateCol=:date, NS=false)
    sort!(crtdf, [stockCol, dateCol])
    print(size(crtdf))
    result = by(crtdf, rebalCol) do xdf
        res = Dict()
        firstper = findall(xdf[:,dateCol].==minimum(xdf[:,dateCol]))

        if WS=="EW"
            res[:startW] = (xdf[firstper,meCol] .* 0 .+ 1) ./ length(collect(skipmissing(xdf[firstper,meCol])))
        elseif WS=="VW"
            res[:startW] = xdf[firstper,meCol] ./ sum(skipmissing(xdf[firstper,meCol]))
        end
        res[stockCol] = xdf[firstper,stockCol]

        DataFrame(res)
    end
    print(size(result))
    startDF = join(crtdf, result, on=[rebalCol, stockCol], kind=:left)
    unique!(startDF)
    print(size(startDF))

    dWeights = by(startDF, [rebalCol, stockCol]) do xdf
        res = Dict()
        if !NS
            cumulRet = 1 .+ running(cumret, xdf[:,:retadj], size(xdf,1))
        else
            cumulRet = [1]
        end
        cumulRet = [1;lag(cumulRet)[2:end]]
        res[:driftW] = xdf[:,:startW] .* cumulRet
        DataFrame(res)
    end
    startDF[:driftW] = dWeights[:driftW]

    dayTotW = by(startDF, [dateCol]) do xdf
        res = Dict()
        res[:totW] = sum(skipmissing(xdf[:,:driftW]))
        DataFrame(res)
    end
    totWDF = join(startDF, dayTotW, on=[dateCol], kind=:left)

    result = by(totWDF, [dateCol]) do xdf
        res = Dict()
        res[:driftW] = xdf[:,:driftW] ./ xdf[:,:totW]
        DataFrame(res)
    end
    print(size(result))

    return result[:driftW]
end


"""
ONM stands for "Only Non Missing"
"""
function varWeighter(crtdf, varCol, dateCol, wCol; ONM=false)
    result = by(crtdf, [dateCol]) do xdf
        res = Dict()
        if length(collect(skipmissing(xdf[:,varCol]))) != 0
            wVec = xdf[:,wCol]
            if ONM==true
                wV = (xdf[:,varCol] .* 0 .+ 1) .* wVec
                wSum = sum(skipmissing(wV))
                wVec = wV ./ wSum
            end
            res[varCol] = sum(skipmissing(xdf[:,varCol] .* wVec))
        else
            # print("\n No news on day $(xdf[1,dateCol]) \n")
            res[varCol] = missing
        end
        DataFrame(res)
    end

    return result
end



end #module
