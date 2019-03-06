module MongoDF
using DataFrames, Dates, PyCall
export TRNAmongoDF, glassdoorMongoDF


function __init__()
    py"""
    import numpy as np
    import pandas as pd
    def cursordf(x):
        df = pd.DataFrame(list(x))
        return (df.values, df.columns.values)
    """
end


function TRNAmongoDF(retvalues::Array{String,1}; monthrange = Month(3), startDate = DateTime(2002,12,31), endDate = DateTime(2017,12,31), showAdv=false)
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
        if showAdv
            print("$myquery \n")
        end
        X, cols = py"cursordf"(collection.find(myquery, retvalues))
        push!(dflist, convertPyArray(X, convert(Array{Symbol}, cols)))
    end
    return vcat(dflist...)
end



function glassdoorMongoDF(retvalues::Array{String,1}, collName; myquery=Dict())
    pymongo = pyimport("pymongo")
    pydatetime = pyimport("datetime")
    client = pymongo.MongoClient()
    db = client.Employee_LBO
    if collName=="Glassdoors_1"
        collection = db.Glassdoors_1
    elseif collName=="Companies_1"
        collection = db.Companies_1
    end

    X, cols = py"cursordf"(collection.find(myquery, retvalues))
    return convertPyArray(X, convert(Array{Symbol}, cols))
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
    res = Dict()
    finalnames = Symbol[]
    for i in 1:length(colnames)
        if !(colnames[i] in [:_id, :date, :gsector, :permno, :Date, :Poprank, :Score, :WLB, :Cult, :CO, :CB,
                            :SM, :recommended, :outlook, :LBO, :Summary, :CEO, :Company, :Main, :Pros, :Cons,
                            :Location, :Position, :MgtAdv, :nbReviews, :Announced, :Competitors, :Description,
                            :Founded, :Headquarters, :Industry, :OrigName, :Ownership_Type, :Revenue, :Size,
                            :State, :Closed]) && String(colnames[i])[1:2]!="nS"
            res[colnames[i]] = replace(convert(Array{Union{Missing,Float64}}, py"$(X)[:,$(i-1)]"), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:date, :Date, :Announced, :Closed]
            res[colnames[i]] = convert(Array{DateTime}, py"$(X)[:,$(i-1)]")
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:gsector, :Summary, :CEO, :Company, :Main, :Pros, :Cons, :Location, :Position, :MgtAdv, :Competitors, :Description,
                                :Founded, :Headquarters, :Industry, :OrigName, :Ownership_Type, :Revenue, :Size, :State]
            prov = replace(convert(Array{Any}, py"$(X)[:,$(i-1)]"), NaN=>missing)
            stringArray = []
            for i in prov
                if py"$i is None"
                    push!(stringArray, missing)
                else
                    push!(stringArray, convert(String, i))
                end
            end
            res[colnames[i]] = convert(Array{Union{String,Missing}}, stringArray)
            push!(finalnames, colnames[i])
        elseif String(colnames[i])[1:2]=="nS" || colnames[i] in [:Poprank, :Score, :WLB, :Cult, :CO, :CB, :SM, :recommended, :outlook, :LBO, :nbReviews]
            res[colnames[i]] = convert(Array{Union{Missing,Int}}, replace(convert(Array{Float64},py"$(X)[:,$(i-1)]"), NaN=>missing))
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
