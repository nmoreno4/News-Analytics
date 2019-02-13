using DataFrames, Statistics, StatsBase, Dates, TSmanip, ShiftedArrays,
      Wfcts, LoadFF, DataStructures, CSV

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

function queryStepWise(myqueries, retvalues)
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

monthrange = Month(3)
y1 = Dates.DateTime(2002,12,31):monthrange:Dates.DateTime(2017,12,31)-monthrange
y2 = Dates.DateTime(2002,12,31)+monthrange:monthrange:Dates.DateTime(2017,12,31)
dateranges = [(y1, y2) for (y1, y2) in zip(y1, y2)]
myquery = [Dict("date"=> Dict("\$gt"=> date1, "\$lte"=> date2), "gsector"=>Dict("\$ne"=> "40")) for (date1, date2) in dateranges]
# query = {"td": {"$gte": 3750}}
retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc", "ebitda",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_CMPNY_inc_nov24H_0_rel100", "nS_BACT_inc_nov24H_0_rel100", "nS_RES_inc_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "nS_MRG_inc_nov24H_0_rel100", "nS_MNGISS_inc_nov24H_0_rel100",
             "nS_DEAL1_inc_nov24H_0_rel100", "nS_DIV_inc_nov24H_0_rel100", "nS_AAA_inc_nov24H_0_rel100",
             "nS_FINE1_inc_nov24H_0_rel100", "nS_BOSS1_inc_nov24H_0_rel100",
             "nS_IPO_inc_nov24H_0_rel100", "nS_STAT_inc_nov24H_0_rel100", "nS_BUYB_inc_nov24H_0_rel100",
             "nS_ALLCE_inc_nov24H_0_rel100", "nS_DVST_inc_nov24H_0_rel100", "nS_SISU_inc_nov24H_0_rel100",
             "nS_REORG_inc_nov24H_0_rel100", "nS_CPROD_inc_nov24H_0_rel100", "nS_STK_inc_nov24H_0_rel100",
             "nS_CASE1_inc_nov24H_0_rel100", "nS_BKRT_inc_nov24H_0_rel100", "nS_MONOP_inc_nov24H_0_rel100",
             "nS_CLASS_inc_nov24H_0_rel100", "nS_CFO1_inc_nov24H_0_rel100", "nS_MEET1_inc_nov24H_0_rel100",
             "nS_CEO1_inc_nov24H_0_rel100", "nS_SHRACT_inc_nov24H_0_rel100", "nS_LIST1_inc_nov24H_0_rel100",
             "nS_LAYOFS_inc_nov24H_0_rel100", "nS_DBTR_inc_nov24H_0_rel100", "nS_DDEAL_inc_nov24H_0_rel100",
             "nS_SPLITB_inc_nov24H_0_rel100", "nS_CHAIR1_inc_nov24H_0_rel100", "nS_HOSAL_inc_nov24H_0_rel100",
             "nS_ACCI_inc_nov24H_0_rel100", "nS_XPAND_inc_nov24H_0_rel100"]
X = @time queryStepWise(myquery, retvalues)
sort!(X, [:permno, :date])
# retvalues2 = ["date", "permno", ]
# X2 = @time queryStepWise(myquery, retvalues2)
# sort!(X2, [:permno, :date])

for i in names(X)
    if String(i)[1:2]=="nS"
        X[i] = replace(X[i], missing=>0)
    end
end

function mymean(X)
    if length(collect(skipmissing(X)))>0
        return mean(skipmissing(X))
    else
        return missing
    end
end

statvars = ["topic", "Avg_Nb_stories_day", "Nb_permnos_day", "volume", "AVG_scaledNeg",
            "VWret2", "Size2", "totNews", "EBITDA", "AVG_scaledPos",
            "STD_scaledNeg", "STD_scaledPos", "MIN_scaledNeg", "MIN_scaledPos",
            "MAX_scaledNeg", "MAX_scaledPos", "q25_scaledNeg", "q25_scaledPos",
            "median_scaledNeg", "median_scaledPos", "q75_scaledNeg", "q75_scaledPos",
            "scaledSent", "nb_neg_news", "nb_pos_news"]
statDict = Dict(zip(statvars, [Union{Float64, Missing, String, Int64, Dict{Union{Missing,Float64},Int64}}[] for i in statvars]))
for topic in ["CMPNY", "BACT", "RES", "RESF", "MRG", "MNGISS", "DEAL1", "DIV", "AAA", "IPO", "STAT", "BUYB",
              "ALLCE", "DVST", "SISU", "REORG", "CPROD", "STK", "CASE1", "BKRT", "MONOP", "CLASS", "CFO1",
              "MEET1", "CEO1", "SHRACT", "LIST1", "LAYOFS", "DBTR", "DDEAL", "SPLITB", "CHAIR1", "HOSAL",
              "ACCI", "XPAND", "ALL", "BOSS1", "FINE1"]
    print(topic)
    if topic != "ALL"
        resDF = X[X[Symbol("nS_$(topic)_inc_nov24H_0_rel100")].>0,:]
    else
        print("hey")
        resDF = X
    end
    push!(statDict["topic"], topic)
    try
        res = by(resDF, [:date]) do xdf
            res = Dict()
            totME = sum(skipmissing(xdf[:me]))
            res["ret"] = sum(skipmissing( (xdf[:me] ./ totME) .* xdf[:retadj] ))
        end
        push!(statDict["VWret2"],  (1 + mean(res[:x1]))^(252) - 1)
    catch
        push!(statDict["VWret2"],  missing)
    end
    prov = by(resDF, :permno, :me => mymean)
    push!(statDict["Size2"],  mymean([i for i in prov[:me_mymean]]))
    prov = by(resDF, :permno, :ebitda => mymean)
    push!(statDict["EBITDA"],  mymean([i for i in prov[:ebitda_mymean]]))
    prov = by(resDF, :permno, :volume => mymean)
    push!(statDict["volume"],  mymean([i for i in prov[:volume_mymean]]))
    push!(statDict["totNews"],  convert(Float64, sum(skipmissing(resDF[:nS_nov24H_0_rel100]))))
    push!(statDict["Avg_Nb_stories_day"], mymean(resDF[:nS_nov24H_0_rel100]))
    prov = by(resDF, :date, :permno => size)
    try
        push!(statDict["Nb_permnos_day"], mymean([i[1] for i in prov[:permno_size]]))
    catch x
        show(resDF)
        show(prov)
        error(x)
    end
    push!(statDict["AVG_scaledNeg"],  sum(resDF[:negSum_nov24H_0_rel100])/statDict["totNews"][end])
    push!(statDict["AVG_scaledPos"],  sum(resDF[:posSum_nov24H_0_rel100])/statDict["totNews"][end])
    push!(statDict["STD_scaledNeg"],  std(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["STD_scaledPos"],  std(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["MIN_scaledNeg"],  minimum(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["MIN_scaledPos"],  minimum(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["MAX_scaledNeg"],  maximum(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["MAX_scaledPos"],  maximum(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])))
    push!(statDict["q25_scaledNeg"],  percentile(collect(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 25))
    push!(statDict["q25_scaledPos"],  percentile(collect(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 25))
    push!(statDict["median_scaledNeg"],  percentile(collect(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 50))
    push!(statDict["median_scaledPos"],  percentile(collect(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 50))
    push!(statDict["q75_scaledNeg"],  percentile(collect(skipmissing(resDF[:negSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 75))
    push!(statDict["q75_scaledPos"],  percentile(collect(skipmissing(resDF[:posSum_nov24H_0_rel100] ./ resDF[:nS_nov24H_0_rel100])), 75))
    push!(statDict["scaledSent"],  (sum(resDF[:posSum_nov24H_0_rel100]) - sum(resDF[:negSum_nov24H_0_rel100])) / statDict["totNews"][end])
    push!(statDict["nb_neg_news"], sum( resDF[:negSum_nov24H_0_rel100] .> 0.33 ))
    push!(statDict["nb_pos_news"], sum( resDF[:posSum_nov24H_0_rel100] .> 0.33 ))
end

CSV.write("/home/nicolas/Documents/Paper Denada/newstats2.csv", DataFrame(statDict))
