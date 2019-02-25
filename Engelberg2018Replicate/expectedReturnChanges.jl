using DataFrames, Statistics, StatsBase, Dates, TSmanip, ShiftedArrays,
      Wfcts, LoadFF, DataStructures

using PyCall
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")


py"""
import numpy as np
import pandas as pd
import pymongo
def cursordf(x):
    df = pd.DataFrame(list(x))
    return (df.values, df.columns.values)
"""


function convertPyArray(X, colnames)
    res = Dict()
    finalnames = Symbol[]
    for i in 1:length(colnames)
        if !(colnames[i] in [:_id, :date, :gsector, :permno]) && String(colnames[i])[1:2]!="nS"
            res[colnames[i]] = replace(convert(Array{Union{Missing,Float64}}, X[:,i]), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:date]
            res[colnames[i]] = convert(Array{DateTime}, X[:,i])
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:gsector]
            res[colnames[i]] = replace(convert(Array{Any}, X[:,i]), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif String(colnames[i])[1:2]=="nS"
            res[colnames[i]] = convert(Array{Union{Missing,UInt16}}, replace(convert(Array{Float64},X[:,i]), NaN=>missing))
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:permno]
            res[colnames[i]] = convert(Array{Int}, X[:,i])
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:ranksize, :rankbm, :EAD]
            res[colnames[i]] = convert(Array{Union{Missing,Int8}}, replace(convert(Array{Float64},X[:,i]), NaN=>missing))
            push!(finalnames, colnames[i])
        end
    end
    X = DataFrame(res)
    names!(X, finalnames)
    return X
end

function queryStepWiseDF(myqueries, retvalues)
    retDic = Dict(zip(retvalues, [1 for i in retvalues]))
    cursor = collection[:find](myqueries[1], retvalues)
    @time X, y = py"cursordf"(cursor)
    colnames = convert.(Symbol, y)
    @time X = convertPyArray(X, colnames)
    for i in 2:length(myqueries)
        print(myqueries[i])
        cursor = collection[:find](myqueries[i], retvalues)
        @time X2, y = py"cursordf"(cursor)
        colnames = convert.(Symbol, y)
        @time X2 = convertPyArray(X2, colnames)
        try
            X = vcat(X, X2)
        catch err
            if typeof(err)==ArgumentError
                for col in names(X2)
                    if !(col in names(X))
                        print("To X Adding column $col \n")
                        X[col] = Array{Union{Missing,Float64}}(undef, size(X,1))
                    end
                end
                for col in names(X)
                    if !(col in names(X2))
                        print("To X2 Adding column $col \n")
                        X2[col] = Array{Union{Missing,Float64}}(undef, size(X2,1))
                    end
                end
                X = vcat(X, X2)
            end
        end
    end
    return X
end

function windowRet(X, win; removeMissing=true, missShortWindows=true)
    X = replace(X,NaN=>missing)
    l = win[1]
    f = win[2]
    res = Union{Missing,Float64}[]
    for i in 1:length(X)
        if i+l<=0 #if the lag puts me too far back
            if missShortWindows
                push!(res,missing)
            elseif i+f<=length(X) && i+f>=1
                push!(res,cumret(X[1:i+f]))
            else
                push!(res,missing)
            end
        elseif i+f>length(X) #forward goes outside range
            if missShortWindows
                push!(res,missing)
            elseif i+l>=0
                if i+l<length(X) && i+l>=1
                    push!(res,cumret(X[i+l:end]))
                else
                    push!(res,missing)
                end
            end
        else
            push!(res,cumret(X[i+l:i+f]))
        end
    end
    return replace(res, NaN=>missing)
end

monthrange = Month(3)
y1 = Dates.DateTime(2002,12,31):monthrange:Dates.DateTime(2017,12,31)-monthrange
y2 = Dates.DateTime(2002,12,31)+monthrange:monthrange:Dates.DateTime(2017,12,31)
dateranges = [(y1, y2) for (y1, y2) in zip(y1, y2)]
myquery = [Dict("date"=> Dict("\$gt"=> date1, "\$lte"=> date2)) for (date1, date2) in dateranges]
# query = {"td": {"$gte": 3750}}
retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc", "td",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100",
             "nS_CMPNY_inc_nov24H_0_rel100", "posSum_CMPNY_inc_nov24H_0_rel100", "negSum_CMPNY_inc_nov24H_0_rel100",
             "nS_BACT_inc_nov24H_0_rel100", "posSum_BACT_inc_nov24H_0_rel100", "negSum_BACT_inc_nov24H_0_rel100",]
X = @time queryStepWiseDF(myquery, retvalues)
@time sort!(X, [:permno, :date])


# Rolling beta as dependent variable
# Rolling stock-variability/idiosyncratic return --> as ϵ of regression Mkt, HML, SMB, MOM?
# expected return over looong windows
@time a = by(X, :permno) do xdf
    res = Dict()
    res[:l480_l241_ret] = windowRet(xdf[:retadj], (-480,-241); missShortWindows=false)
    res[:l240_l121_ret] = windowRet(xdf[:retadj], (-240,-121); missShortWindows=false)
    res[:l120_l61_ret] = windowRet(xdf[:retadj], (-120,-61); missShortWindows=false)
    res[:l60_l41_ret] = windowRet(xdf[:retadj], (-60,-41); missShortWindows=false)
    res[:l40_l21_ret] = windowRet(xdf[:retadj], (-40,-21); missShortWindows=false)
    res[:l20_l11_ret] = windowRet(xdf[:retadj], (-20,-11); missShortWindows=false)
    res[:l10_l6_ret] = windowRet(xdf[:retadj], (-10,-6); missShortWindows=false)
    res[:l5_l3_ret] = windowRet(xdf[:retadj], (-5,-3); missShortWindows=false)
    res[:l2_ret] = windowRet(xdf[:retadj], (-2,-2); missShortWindows=false)
    res[:l1_ret] = windowRet(xdf[:retadj], (-1,-1); missShortWindows=false)
    res[:f1_ret] = windowRet(xdf[:retadj], (1,1); missShortWindows=false)
    res[:f2_ret] = windowRet(xdf[:retadj], (2,2); missShortWindows=false)
    res[:f3_f5_ret] = windowRet(xdf[:retadj], (3,5); missShortWindows=false)
    res[:f6_f10_ret] = windowRet(xdf[:retadj], (6,10); missShortWindows=false)
    res[:f11_f20_ret] = windowRet(xdf[:retadj], (11,20); missShortWindows=false)
    res[:f21_f40_ret] = windowRet(xdf[:retadj], (21,40); missShortWindows=false)
    res[:f41_f60_ret] = windowRet(xdf[:retadj], (41,60); missShortWindows=false)
    res[:f61_f120_ret] = windowRet(xdf[:retadj], (61,120); missShortWindows=false)
    res[:f121_f240_ret] = windowRet(xdf[:retadj], (121,240); missShortWindows=false)
    res[:f241_f480_ret] = windowRet(xdf[:retadj], (241,480); missShortWindows=false)
    res[:f481_f720_ret] = windowRet(xdf[:retadj], (481,720); missShortWindows=false)
    res[:date] = xdf[:date]
    DataFrame(res)
end
sort!(a, [:permno,:date])
deletecols!(a, [:permno, :date])
X = hcat(X, a)
a = nothing ; GC.gc();


#### Identifier for windows.
rolling = true
dateVar = :date
windowlength= 19

windowGrouping(X, 10, dateVar, rolling)

function windowGrouping(X, windowlength, dateVar, rolling)
    if dateVar==:td
        dateType = Int
        if rolling
            paddings = 0:1:windowlength
        else
            paddings = [0]
        end
    elseif dateVar==:date
        dateType=DateTime
        windowlength = Day(windowlength)
        if windowlength<Day(3)
            error("Because of missing weekends, specify at least a 3 day window length! (or use trading days)")
        end
        if rolling
            paddings = Day(0):Day(1):Day(windowlength)
        else
            paddings = [Day(0)]
        end
    end

    @time sort!(X, dateVar)

    finalRes = []

    for padd in paddings
        print(padd)
        dateRanges = collect(minimum(X[dateVar])+padd:windowlength:maximum(X[dateVar]))
        if maximum(dateRanges)<=maximum(X[dateVar])
            push!(dateRanges, dateRanges[end]+windowlength)
        end
        perGroup = Array{Union{dateType,Missing}}(undef,size(X,1))
        groupIdx = 1
        dateVec = X[dateVar]
        minDate = minimum(dateRanges)
        maxDate = maximum(dateVec)
        @time for dfIdx in 1:length(dateVec)
            if dateVec[dfIdx]>=minDate && dateVec[dfIdx]>=dateRanges[groupIdx] && dateVec[dfIdx]<dateRanges[groupIdx+1]
                if dateRanges[groupIdx+1]>maxDate
                    perGroup[dfIdx] = maxDate
                else
                    try
                        perGroup[dfIdx] = dateRanges[groupIdx+1]
                    catch x
                        print(groupIdx)
                        print(length(dateRanges))
                        error(x)
                    end
                end
            elseif dateVec[dfIdx]>=minDate
                groupIdx+=1
                if dateRanges[groupIdx+1]>maxDate
                    perGroup[dfIdx] = maxDate
                else
                    try
                        perGroup[dfIdx] = dateRanges[groupIdx+1]
                    catch x
                        print(groupIdx)
                        print(length(dateRanges))
                        error(x)
                    end
                end
            end
        end
        push!(finalRes, perGroup)
    end
    return finalRes
end



# Positive and Negative news tone
X[:NEG_ALL] = X[:negSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:POS_ALL] = X[:posSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:SENT_ALL] = (X[:posSum_nov24H_0_rel100] .- X[:negSum_nov24H_0_rel100]) ./ X[:nS_nov24H_0_rel100]
X[:NEG_RES] = X[:negSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:POS_RES] = X[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:SENT_RES] = (X[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] .- X[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]) ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:NEG_RESF] = X[:negSum_RESF_inc_nov24H_0_rel100] ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:POS_RESF] = X[:posSum_RESF_inc_nov24H_0_rel100] ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:SENT_RESF] = (X[:posSum_RESF_inc_nov24H_0_rel100] .- X[:negSum_RESF_inc_nov24H_0_rel100]) ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:NEG_CMPNY] = X[:negSum_CMPNY_inc_nov24H_0_rel100] ./ X[:nS_CMPNY_inc_nov24H_0_rel100]
X[:POS_CMPNY] = X[:posSum_CMPNY_inc_nov24H_0_rel100] ./ X[:nS_CMPNY_inc_nov24H_0_rel100]
X[:SENT_CMPNY] = (X[:posSum_CMPNY_inc_nov24H_0_rel100] .- X[:negSum_CMPNY_inc_nov24H_0_rel100]) ./ X[:nS_CMPNY_inc_nov24H_0_rel100]
X[:NEG_BACT] = X[:negSum_BACT_inc_nov24H_0_rel100] ./ X[:nS_BACT_inc_nov24H_0_rel100]
X[:POS_BACT] = X[:posSum_BACT_inc_nov24H_0_rel100] ./ X[:nS_BACT_inc_nov24H_0_rel100]
X[:SENT_BACT] = (X[:posSum_BACT_inc_nov24H_0_rel100] .- X[:negSum_BACT_inc_nov24H_0_rel100]) ./ X[:nS_BACT_inc_nov24H_0_rel100]
X[:NEUT_ALL] = 1 .- X[:POS_ALL] .- X[:NEG_ALL]
X[:negDay] = 0
X[:neutDay] = 0
X[:posDay] = 0
for row in 1:size(X,1)
    if !ismissing(X[row, :scaledPos])
        if X[row, :scaledNeut] > X[row, :scaledPos] && X[row, :scaledNeut] > X[row, :scaledNeg]
            X[row, :neutDay] = 1
        elseif X[row, :scaledPos] > X[row, :scaledNeut] && X[row, :scaledPos] > X[row, :scaledNeg]
            X[row, :posDay] = 1
        elseif X[row, :scaledNeg] > X[row, :scaledNeut] && X[row, :scaledNeg] > X[row, :scaledPos]
            X[row, :negDay] = 1
        end
    end
end
X[:newNeg] = Array{Union{Float64,Missing}}(undef,size(X,1))
X[:newPos] = Array{Union{Float64,Missing}}(undef,size(X,1))
for row in 1:size(X,1)
    if X[row, :posDay]==1
        X[row, :newPos] = X[row, :scaledPos]
    elseif X[row, :negDay]==1
        X[row, :newNeg] = X[row, :scaledNeg]
    end
end
X[:year] = Dates.year.(X[:date])
@time a = by(X, :year) do xdf
    res = Dict()
    res[:yearmean_scaledPos] = mean(skipmissing(xdf[:scaledPos]))
    res[:yearstd_scaledPos] = std(skipmissing(xdf[:scaledPos]))
    res[:yearmean_scaledNeg] = mean(skipmissing(xdf[:scaledNeg]))
    res[:yearstd_scaledNeg] = std(skipmissing(xdf[:scaledNeg]))
    res[:yearmean_newPos] = mean(skipmissing(xdf[:newPos]))
    res[:yearstd_newPos] = std(skipmissing(xdf[:newPos]))
    res[:yearmean_newNeg] = mean(skipmissing(xdf[:newNeg]))
    res[:yearstd_newNeg] = std(skipmissing(xdf[:newNeg]))
    res[:yeargoodnews] = sum(xdf[:posDay])
    res[:yearbadnews] = sum(xdf[:negDay])
    DataFrame(res)
end
deletecols!(X, [:yearmean_scaledPos, :yearstd_scaledPos, :yearmean_scaledNeg, :yearstd_scaledNeg, :yearmean_newPos,
            :yearstd_newPos, :yearmean_newNeg, :yearstd_newNeg, :yeargoodnews, :yearbadnews])
X = join(X, a, on=:year, kind=:left)
X[:stand_scaledNeg] = (X[:scaledNeg] .- X[:yearmean_scaledNeg]) ./ X[:yearstd_scaledNeg]
X[:stand_scaledPos] = (X[:scaledPos] .- X[:yearmean_scaledPos]) ./ X[:yearstd_scaledPos]
X[:stand_newNeg] = (X[:newNeg] .- X[:yearmean_newNeg]) ./ X[:yearstd_newNeg]
X[:stand_newPos] = (X[:newPos] .- X[:yearmean_newPos]) ./ X[:yearstd_newPos]



# Accumulation of negative news over multiple days






# Regressions
X[:DateCategorical] = categorical(X[:date])
X[:StockCategorical] = categorical(X[:permno])
using RegressionTables, FixedEffectModels
m1 = @time reg(X, @model(retadj ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(f1_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(f2_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(f3_f5_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m5 = @time reg(X, @model(f6_f10_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m6 = @time reg(X, @model(f11_f20_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m7 = @time reg(X, @model(f21_f40_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m7 = @time reg(X, @model(f41_f60_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m8 = @time reg(X, @model(f61_f120_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m9 = @time reg(X, @model(f121_f240_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m10 = @time reg(X, @model(f241_f480_ret ~  scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m11 = @time reg(X, @model(f481_f720_ret ~ scaledNeg*negDay + scaledPos*posDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
