module MongoDF
using DataFrames, Dates, PyCall
export TRNAmongoDF


function __init__()
    py"""
    import numpy as np
    import pandas as pd
    def cursordf(x):
        df = pd.DataFrame(list(x))
        return (df.values, df.columns.values)
    """
end


function TRNAmongoDF(retvalues; monthrange = Month(3), startDate = DateTime(2002,12,31), endDate = DateTime(2017,12,31))
    pymongo = pyimport("pymongo")
    pydatetime = pyimport("datetime")
    client = pymongo.MongoClient()
    db = client.Jan2019
    collection = db.PermnoDay

    y1 = startDate:monthrange:endDate-monthrange
    y2 = startDate+monthrange:monthrange:endDate
    dateranges = [(y1, y2) for (y1, y2) in zip(y1, y2)]
    myqueries = [Dict("date"=> Dict("\$gt"=> date1, "\$lte"=> date2)) for (date1, date2) in dateranges]

    retDic = Dict(zip(retvalues, [1 for i in retvalues]))

    dflist = []
    for myquery in myqueries
        X, cols = py"cursordf"(collection.find(myquery, retvalues))
        push!(dflist, convertPyArray(X, convert(Array{Symbol}, cols)))
    end
    return dflist
end



"""
Convert a python array with corresponding column names to a julia dataframe.
Converts the columns to appropriate type.
#
Please add more new columns over time, if not yet included in the below solution.
#
This function takes in `X` a python array that was obtained through the transformation
of a list of mongo dictionary results to a dataframe.
`colnames` is a julia array of Symbols in the order of the columns of X.
"""
function convertPyArray(X::PyObject, colnames::Array{Symbol,1})
    print(typeof(colnames))
    res = Dict()
    finalnames = Symbol[]
    for i in 1:length(colnames)
        if !(colnames[i] in [:_id, :date, :gsector, :permno]) && String(colnames[i])[1:2]!="nS"
            res[colnames[i]] = replace(convert(Array{Union{Missing,Float64}}, py"$(X)[:,$(i-1)]"), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:date]
            res[colnames[i]] = convert(Array{DateTime}, py"$(X)[:,$(i-1)]")
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:gsector]
            res[colnames[i]] = replace(convert(Array{Any}, py"$(X)[:,$(i-1)]"), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif String(colnames[i])[1:2]=="nS"
            res[colnames[i]] = convert(Array{Union{Missing,UInt16}}, replace(convert(Array{Float64},py"$(X)[:,$(i-1)]"), NaN=>missing))
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:permno]
            res[colnames[i]] = convert(Array{Int}, py"$(X)[:,$(i-1)]")
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:ranksize, :rankbm, :EAD]
            res[colnames[i]] = convert(Array{Union{Missing,Int8}}, replace(convert(Array{Float64},py"$(X)[:,$(i-1)]"), NaN=>missing))
            push!(finalnames, colnames[i])
        end
    end
    X = DataFrame(res)
    names!(X, finalnames)
    return X
end


end #module
