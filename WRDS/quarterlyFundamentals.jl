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
            print(colnames[i])
            res[colnames[i]] = convert.(Union{Missing,Float64}, X[:,i])
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:date]
            res[colnames[i]] = convert.(DateTime, X[:,i])
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:gsector]
            res[colnames[i]] = convert.(Any, X[:,i])
            push!(finalnames, colnames[i])
        elseif String(colnames[i])[1:2]=="nS"
            res[colnames[i]] = convert.(Float64, X[:,i])
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:permno]
            res[colnames[i]] = convert.(UInt64, X[:,i])
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
        cursor = collection[:find](myqueries[i], retvalues)
        @time X2, y = py"cursordf"(cursor)
        colnames = convert.(Symbol, y)
        @time X2 = convertPyArray(X2, colnames)
        X = vcat(X, X2)
    end
    return X
end


yranges = [(y,y+1) for y in 2002:2016]
myquery = [Dict("date"=> Dict("\$gt"=> Dates.DateTime(y1, 12, 31), "\$lte"=> Dates.DateTime(y2, 12, 31))) for (y1, y2) in yranges]
# query = {"td": {"$gte": 3750}}
retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100"]
X = @time queryStepWise(myquery, retvalues)
