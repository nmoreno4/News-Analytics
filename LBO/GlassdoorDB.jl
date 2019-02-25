using DataFrames, Statistics, StatsBase, Dates, TSmanip, ShiftedArrays,
      Wfcts, LoadFF, DataStructures, PyCall, CSV

pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Employee_LBO"]
collection = db["Glassdoors"]
pydatetime = pyimport("datetime")


py"""
import numpy as np
import pandas as pd
import pymongo
def cursordf(x):
    df = pd.DataFrame(list(x))
    return (df.values, df.columns.values)
"""

cursor = collection[:find]()
foo = collect(cursor)

collect(keys(foo[1]))

function dictarray_to_df(foo)
    resDF = Dict(zip(keys(foo[1]), [[] for i in keys(foo[1])]))
    for i in 2:length(foo)
        for col in keys(resDF)
            try
                if isa(foo[i][col], Nothing)
                    push!(resDF[col], missing)
                else
                    if typeof(foo[i][col]) == String
                        replace(foo[i][col], "," => "")
                    end
                    if col=="Date"
                        push!(resDF[col], Date(foo[i][col]))
                    elseif foo[i][col][end]=='"'
                        push!(resDF[col], foo[i][col][1:end-1])
                    else
                        push!(resDF[col], foo[i][col])
                    end
                end
            catch err
                if isa(err, KeyError)
                    push!(resDF[col], missing)
                end
            end
        end
    end
    delete!(resDF, "_id")
    return DataFrame(resDF)
end

resDF = dictarray_to_df(foo)
resDF = resDF[.!ismissing.(replace(resDF[:Date], NaN=>missing)),:]
sort!(resDF, [:Company, :Date])
resDF = resDF[.!ismissing.(replace(resDF[:Cons], NaN=>missing)),:]
deletecols!(resDF, :Constart)

a = length(resDF[(resDF[:Date].>Date(2000,1,1)) .& (resDF[:Date].<Date(2011,1,1)),:Date])

CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/SampleGlassdoors.csv", resDF)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/SampleCompanies.csv", resDF)




##### Summary Stats #####
companies = [
    ("ADB Airfield Solutions", Date(2013,3,4)),
    ("Latitude Financial Services", Date(2015,3,15)),
    ("Gates Corporation", Date(2014,4,4)),
    ("Petco", Date(2015,11,23)),
    ("USI Insurance Services", Date(2017,3,17)),
    ("Abila", Date(2013,2,15)),
    ("101 Mobility", Date(2013,5,22)),
    ("Playtika", Date(2016,7,30)),
    ("SIG Holding", Date(2014,11,23)),
    ("Springer International Publishing", Date(2013,6,19)),
    ("UFC", Date(2013,7,9)),
    ("Acosta", Date(2011,1,5)),
    ("Ortho Clinical Diagnostics", Date(2014,1,16)),
    ("Intelsat", Date(2007,6,19)),
    ("Ally Financial", Date(2006,4,3)),
    ("Alight Solutions", Date(2017,2,10)),
    ("Refinitiv", Date(2018,1,30)),
    ("Samson Resources", Date(2011,11,23)),
    ("Axalta", Date(2012,8,30)),
    ("Neiman Marcus", Date(2013,9,9)),
    ("Sedgwick Claims Management Services", Date(2018,9,12)),
    ("Johnson Controls", Date(2018,11,13)),
    ("MultiPlan", Date(2016,5,5)),
    ("Albertsons Companies", Date(2006,1,23)),
    ("Supercell", Date(2016,6,21)),
    ("EP Energy", Date(2012,2,25)),
    ("Toshiba", Date(2017,9,13)),
    ("Veritas", Date(2015,8,11)),
    ("Toys \"R\" Us", Date(2005,7,21))
    ]

function summstats1(companies, resDF)
    alldict = []
    for (comp, bdate) in companies
        pre = resDF[(resDF[:Company].==comp) .& (resDF[:Date].<bdate),:]
        post = resDF[(resDF[:Company].==comp) .& (resDF[:Date].>=bdate),:]
        tot = resDF[(resDF[:Company].==comp),:]
        predict = missing
        try
            predict = OrderedDict(
                    "Company" => comp,
                    "state" => "Pre-buyout",
                    "Buyout" => bdate,
                    "Score_AVG" => mean(skipmissing(pre[:Score])),
                    "Score_MED" => median(skipmissing(pre[:Score])),
                    "Score_STD" => std(skipmissing(pre[:Score])),
                    "CB_AVG" => mean(skipmissing(pre[:CB])),
                    "CB_MED" => median(skipmissing(pre[:CB])),
                    "CB_STD" => std(skipmissing(pre[:CB])),
                    "WLB_AVG" => mean(skipmissing(pre[:WLB])),
                    "WLB_MED" => median(skipmissing(pre[:WLB])),
                    "WLB_STD" => std(skipmissing(pre[:WLB])),
                    "CO_AVG" => mean(skipmissing(pre[:CO])),
                    "CO_MED" => median(skipmissing(pre[:CO])),
                    "CO_STD" => std(skipmissing(pre[:CO])),
                    "Cult_AVG" => mean(skipmissing(pre[:Cult])),
                    "Cult_MED" => median(skipmissing(pre[:Cult])),
                    "Cult_STD" => std(skipmissing(pre[:Cult])),
                    "SM_AVG" => mean(skipmissing(pre[:SM])),
                    "SM_MED" => median(skipmissing(pre[:SM])),
                    "SM_STD" => std(skipmissing(pre[:SM])),
                    "outlook_AVG" => mean(skipmissing(pre[:outlook])),
                    "outlook_MED" => median(skipmissing(pre[:outlook])),
                    "outlook_STD" => std(skipmissing(pre[:outlook])),
                    "recommended_AVG" => mean(skipmissing(pre[:recommended])),
                    "recommended_MED" => median(skipmissing(pre[:recommended])),
                    "recommended_STD" => std(skipmissing(pre[:recommended])),
                    "Tot_rev" => length(pre[:Score])
                )
        catch
            predict = OrderedDict(
                    "Company" => comp,
                    "state" => "Pre-buyout",
                    "Buyout" => bdate,
                    "Score_AVG" => missing,
                    "Score_MED" => missing,
                    "Score_STD" => missing,
                    "CB_AVG" => missing,
                    "CB_MED" => missing,
                    "CB_STD" => missing,
                    "WLB_AVG" => missing,
                    "WLB_MED" => missing,
                    "WLB_STD" => missing,
                    "CO_AVG" => missing,
                    "CO_MED" => missing,
                    "CO_STD" => missing,
                    "Cult_AVG" => missing,
                    "Cult_MED" => missing,
                    "Cult_STD" => missing,
                    "SM_AVG" => missing,
                    "SM_MED" => missing,
                    "SM_STD" => missing,
                    "outlook_AVG" => missing,
                    "outlook_MED" => missing,
                    "outlook_STD" => missing,
                    "recommended_AVG" => missing,
                    "recommended_MED" => missing,
                    "recommended_STD" => missing,
                    "Tot_rev" => 0
                )
        end
        push!(alldict, predict)

        postdict = missing
        try
            postdict = OrderedDict(
                    "Company" => comp,
                    "state" => "Post-buyout",
                    "Buyout" => bdate,
                    "Score_AVG" => mean(skipmissing(post[:Score])),
                    "Score_MED" => median(skipmissing(post[:Score])),
                    "Score_STD" => std(skipmissing(post[:Score])),
                    "CB_AVG" => mean(skipmissing(post[:CB])),
                    "CB_MED" => median(skipmissing(post[:CB])),
                    "CB_STD" => std(skipmissing(post[:CB])),
                    "WLB_AVG" => mean(skipmissing(post[:WLB])),
                    "WLB_MED" => median(skipmissing(post[:WLB])),
                    "WLB_STD" => std(skipmissing(post[:WLB])),
                    "CO_AVG" => mean(skipmissing(post[:CO])),
                    "CO_MED" => median(skipmissing(post[:CO])),
                    "CO_STD" => std(skipmissing(post[:CO])),
                    "Cult_AVG" => mean(skipmissing(post[:Cult])),
                    "Cult_MED" => median(skipmissing(post[:Cult])),
                    "Cult_STD" => std(skipmissing(post[:Cult])),
                    "SM_AVG" => mean(skipmissing(post[:SM])),
                    "SM_MED" => median(skipmissing(post[:SM])),
                    "SM_STD" => std(skipmissing(post[:SM])),
                    "outlook_AVG" => mean(skipmissing(post[:outlook])),
                    "outlook_MED" => median(skipmissing(post[:outlook])),
                    "outlook_STD" => std(skipmissing(post[:outlook])),
                    "recommended_AVG" => mean(skipmissing(post[:recommended])),
                    "recommended_MED" => median(skipmissing(post[:recommended])),
                    "recommended_STD" => std(skipmissing(post[:recommended])),
                    "Tot_rev" => length(post[:Score])
                )
        catch
            postdict = OrderedDict(
                    "Company" => comp,
                    "state" => "Post-buyout",
                    "Buyout" => bdate,
                    "Score_AVG" => missing,
                    "Score_MED" => missing,
                    "Score_STD" => missing,
                    "CB_AVG" => missing,
                    "CB_MED" => missing,
                    "CB_STD" => missing,
                    "WLB_AVG" => missing,
                    "WLB_MED" => missing,
                    "WLB_STD" => missing,
                    "CO_AVG" => missing,
                    "CO_MED" => missing,
                    "CO_STD" => missing,
                    "Cult_AVG" => missing,
                    "Cult_MED" => missing,
                    "Cult_STD" => missing,
                    "SM_AVG" => missing,
                    "SM_MED" => missing,
                    "SM_STD" => missing,
                    "outlook_AVG" => missing,
                    "outlook_MED" => missing,
                    "outlook_STD" => missing,
                    "recommended_AVG" => missing,
                    "recommended_MED" => missing,
                    "recommended_STD" => missing,
                    "Tot_rev" => 0
                )
        end
        push!(alldict, postdict)

        totdict = missing
        try
            totdict = OrderedDict(
                    "Company" => comp,
                    "state" => "All obs",
                    "Buyout" => bdate,
                    "Score_AVG" => mean(skipmissing(tot[:Score])),
                    "Score_MED" => median(skipmissing(tot[:Score])),
                    "Score_STD" => std(skipmissing(tot[:Score])),
                    "CB_AVG" => mean(skipmissing(tot[:CB])),
                    "CB_MED" => median(skipmissing(tot[:CB])),
                    "CB_STD" => std(skipmissing(tot[:CB])),
                    "WLB_AVG" => mean(skipmissing(tot[:WLB])),
                    "WLB_MED" => median(skipmissing(tot[:WLB])),
                    "WLB_STD" => std(skipmissing(tot[:WLB])),
                    "CO_AVG" => mean(skipmissing(tot[:CO])),
                    "CO_MED" => median(skipmissing(tot[:CO])),
                    "CO_STD" => std(skipmissing(tot[:CO])),
                    "Cult_AVG" => mean(skipmissing(tot[:Cult])),
                    "Cult_MED" => median(skipmissing(tot[:Cult])),
                    "Cult_STD" => std(skipmissing(tot[:Cult])),
                    "SM_AVG" => mean(skipmissing(tot[:SM])),
                    "SM_MED" => median(skipmissing(tot[:SM])),
                    "SM_STD" => std(skipmissing(tot[:SM])),
                    "outlook_AVG" => mean(skipmissing(tot[:outlook])),
                    "outlook_MED" => median(skipmissing(tot[:outlook])),
                    "outlook_STD" => std(skipmissing(tot[:outlook])),
                    "recommended_AVG" => mean(skipmissing(tot[:recommended])),
                    "recommended_MED" => median(skipmissing(tot[:recommended])),
                    "recommended_STD" => std(skipmissing(tot[:recommended])),
                    "Tot_rev" => length(tot[:Score])
                )
        catch
            totdict = OrderedDict(
                    "Company" => comp,
                    "state" => "All obs",
                    "Buyout" => bdate,
                    "Score_AVG" => missing,
                    "Score_MED" => missing,
                    "Score_STD" => missing,
                    "CB_AVG" => missing,
                    "CB_MED" => missing,
                    "CB_STD" => missing,
                    "WLB_AVG" => missing,
                    "WLB_MED" => missing,
                    "WLB_STD" => missing,
                    "CO_AVG" => missing,
                    "CO_MED" => missing,
                    "CO_STD" => missing,
                    "Cult_AVG" => missing,
                    "Cult_MED" => missing,
                    "Cult_STD" => missing,
                    "SM_AVG" => missing,
                    "SM_MED" => missing,
                    "SM_STD" => missing,
                    "outlook_AVG" => missing,
                    "outlook_MED" => missing,
                    "outlook_STD" => missing,
                    "recommended_AVG" => missing,
                    "recommended_MED" => missing,
                    "recommended_STD" => missing,
                    "Tot_rev" => 0
                )
        end
        push!(alldict, totdict)
    end
    return alldict
end
a = summstats1(companies, resDF)

res = vcat(DataFrame.(a)...)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/SampleStats.csv", res)


totrev = []
x_axis = []
interval = Month(3)
for cdate in minimum(resDF[:Date]):interval:maximum(resDF[:Date])
    push!(totrev, length(resDF[(resDF[:Date].>=cdate) .& (resDF[:Date].<cdate+interval),:Date]))
    push!(x_axis, cdate+interval)
end

using Plots
plot(x_axis, totrev)
savefig("/home/nicolas/Documents/Paper L Phalippou/Data/reviewsOverTime.png")
