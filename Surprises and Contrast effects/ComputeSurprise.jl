using DataFrames, PyCall, Dates

### Connect to MongoDB ###
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
###########################

# NB: project can work with "cond" to return a field only if it matches a certain condition!
retvalues = ["permno", "date", "retadj", "nS_nov24H_0_rel100"]
retDic = Dict(zip(retvalues, [1 for i in retvalues]))

function simplePipe(var1, var2, var3, date1, date2, retDic)
    pipeline = [
            Dict("\$match"=> Dict("date"=> Dict("\$gt"=> DateTime(date1), "\$lte"=> DateTime(date2)))),
            Dict("\$group"=>Dict("_id"=> Dict("permno"=>"\$permno",
                                              "date"=>Dict("\$toDate"=>Dict(
                                                "\$subtract"=>[Dict("\$toLong"=>"\$date"),
                                                               Dict("\$mod"=>[1000*60*60*24*5*5+45, 1000*60*60*24*5])
                                                               ]
                                                ))),
                                 "posSum"=>Dict("\$sum"=>"\$$(var1)"),
                                 "negSum"=>Dict("\$sum"=>"\$$(var2)"),
                                 "nS"=>Dict("\$sum"=>"\$$(var3)"))),
            Dict("\$project"=>Dict("_id"=>0,
                                   "permno"=>"\$_id.permno",
                                   "date"=>"\$_id.date",
                                   "posSum"=>1,
                                   "negSum"=>1,
                                   "nS"=>1))
        ]
    return pipeline
end
crtpipe = simplePipe("posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100", "nS_nov24H_0_rel100", LTstart, LTend, retDic)


date1 = DateTime(LTstart)
date2 = DateTime(LTend)
var1, var2, var3 = "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100", "nS_nov24H_0_rel100"
py"""
pipeline = [
    {"$match": {"date": {"$gt": $(date1), "$lte": $(date2)}}},
    { "$group": {
      "_id": {
        "permno": "$permno",
        "date": {
          "$subtract": [
            { "$toLong": "$date" },
            { "$mod": [ { "$toLong": "$date" }, 1000 * 60 * 60 * 24 * 5 ] }
          ]
        }
      },
      "posSum": { "$sum": "$"+str($(var1)) },
      "negSum": { "$sum": "$"+str($(var2)) },
      "nS": { "$sum": "$"+str($(var3)) },
      "date": { "$last": "$date" }
    }},
    { "$project":{
      "_id": 0,
      "permno": "$_id.permno",
      "date":1,
      "posSum":1,
      "negSum":1,
      "nS":1
    }}
    ]
"""

@time py"list"(collection[:aggregate](py"pipeline"))


x = 1+1
py"""
g = "helo" + str($x)
"""
a = py"pipeline"




LTwindow = [Month(6), Week(1)]
STwindow = [Week(1), Day(0)]
startDate, endDate = DateTime(2003,1,1), DateTime(2005,1,1)

X = []
@time for currentDate in startDate:Week(1):endDate
    print("$(currentDate)\n")
    LTstart = currentDate-LTwindow[1]
    LTend = currentDate-LTwindow[2]
    STstart = currentDate-STwindow[1]
    STend = currentDate-STwindow[2]
    crtpipe = simplePipe("posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100", "nS_nov24H_0_rel100", LTstart, LTend, retDic)
    @time Y, cols = py"cursordf"(collection[:aggregate](crtpipe))
    colnames = replace(convert.(Symbol, cols), :_id=>:permno)
    Y = convertPyArray(Y, colnames)
    for col in 1:size(Y,2)
        Y[:,col] = replace(Y[:,col], 0=>missing)
    end
    push!(X, Y)
end
currentDate = DateTime(2003,4,25)
