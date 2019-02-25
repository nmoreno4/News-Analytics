using DataFrames, PyCall, Dates, XLSX

### Connect to MongoDB ###
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")
py"""
from collections import OrderedDict
"""
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
            res[colnames[i]] = convert(Array{Union{Missing,Int64}}, replace(convert(Array{Float64},X[:,i]), NaN=>missing))
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

function queryStepWiseList(myqueries, retvalues, saveFunc=py"cursordf")
    retDic = Dict(zip(retvalues, [1 for i in retvalues]))
    cursor = collection[:find](myqueries[1], retvalues)
    @time X = saveFunc(cursor)
    for i in 2:length(myqueries)
        print(myqueries[i])
        cursor = collection[:find](myqueries[i], retvalues)
        @time X2 = saveFunc(cursor)
        X = [X, X2]
    end
    return X
end
###########################

### Read permids ###
xf = XLSX.readdata("/home/nicolas/Documents/Memoires/Constituents2011-2016.xlsx", "Constituents", "C3:C134")
doubles = Dict()
for i in 1:length(xf)
    if typeof(xf[i])!=Int64
        doubles[i] = xf[i]
    end
end
permids = Int[]
for i in 1:length(xf)
    if !(i in keys(doubles))
        push!(permids, xf[i])
    end
end
for (k,v) in doubles
    for perm in split(doubles[68], "/")
        push!(permids, parse(Int, perm))
    end
end
####


permids = [4295903420, 5030853586, 4295905494, 4295904853, 4295908715, 4295908573, 4295915611, 4297686573, 4298358651, 4295902158, 4295913071, 4298365329]
retvalues = ["date", "permno", "permid", "comnam", "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100",
             "negSum_nov24H_0_rel100", "gsubind", "negSum_DEAL1_inc_nov24H_0_rel100",
             "posSum_DEAL1_inc_nov24H_0_rel100", "nS_DEAL1_inc_nov24H_0_rel100",
             "negSum_MRG_inc_nov24H_0_rel100", "posSum_MRG_inc_nov24H_0_rel100",
             "nS_MRG_inc_nov24H_0_rel100", "negSum_MRG_DEAL1_inc_nov24H_0_rel0",
             "posSum_MRG_DEAL1_inc_nov24H_0_rel0", "nS_MRG_DEAL1_inc_nov24H_0_rel0"]
# retvalues = ["date", "permno", "permid", "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100",
#              "negSum_nov24H_0_rel100", "gsubind", "stories"]

retDic = Dict(zip(retvalues, [1 for i in retvalues]))
py"""
myqueries = [OrderedDict({"date": {"$gt":$(Dates.DateTime(2011,12,31)), "$lte":$(Dates.DateTime(2017,12,31))}, "permid": int(permid)}) for permid in $(permids)]
X = []
for mquery in myqueries:
    print(mquery)
    cursor = $(collection).find(mquery, $(retvalues))
    X.append(list(cursor))

import pickle
outfile = open("/home/nicolas/Documents/Memoires/ManonData.pkl",'wb')
pickle.dump(X,outfile)
outfile.close()
"""
