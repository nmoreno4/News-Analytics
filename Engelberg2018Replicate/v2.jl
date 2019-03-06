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
    return (df, df.columns.values)
"""


function convertPyArray(X, colnames)
    res = Dict()
    finalnames = Symbol[]
    print("length : $(length(colnames))")
    for i in 1:length(colnames)
        print(get(X, PyArray, String(colnames[i])))
        if !(colnames[i] in [:_id, :date, :gsector, :permno]) && String(colnames[i])[1:2]!="nS"
            try
                res[colnames[i]] = replace(convert(Array{Union{Missing,Float64}}, get(X, String(colnames[i]))), NaN=>missing)
            catch err
                error(err)
            end
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:date]
            res[colnames[i]] = convert(Array{DateTime}, get(X, String(colnames[i])))
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:gsector]
            res[colnames[i]] = replace(convert(Array{Any}, get(X, String(colnames[i]))), NaN=>missing)
            push!(finalnames, colnames[i])
        elseif String(colnames[i])[1:2]=="nS"
            res[colnames[i]] = convert(Array{Union{Missing,UInt16}}, replace(convert(Array{Float64},get(X, String(colnames[i]))), NaN=>missing))
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:permno]
            res[colnames[i]] = convert(Array{Int}, get(X, String(colnames[i])))
            push!(finalnames, colnames[i])
        elseif colnames[i] in [:ranksize, :rankbm, :EAD]
            res[colnames[i]] = convert(Array{Union{Missing,Int8}}, replace(convert(Array{Float64},get(X, String(colnames[i]))), NaN=>missing))
            push!(finalnames, colnames[i])
        end
    end
    X = DataFrame(res)
    names!(X, finalnames)
    return X
end

function queryStepWiseDF(myqueries, retvalues, saveFunc=py"cursordf")
    retDic = Dict(zip(retvalues, [1 for i in retvalues]))
    cursor = collection[:find](myqueries[1], retvalues)
    @time X, y = saveFunc(cursor)
    colnames = Symbol.(X)
    @time X = convertPyArray(X, colnames)
    for i in 2:length(myqueries)
        print(myqueries[i])
        cursor = collection.find(myqueries[i], retvalues)
        @time X2, y = saveFunc(cursor)
        colnames = convert.(Symbol, y)
        @time X2 = convertPyArray(X2, colnames)
        X = vcat(X, X2)
    end
    return X
end

monthrange = Month(3)
y1 = Dates.DateTime(2002,12,31):monthrange:Dates.DateTime(2017,12,31)-monthrange
y2 = Dates.DateTime(2002,12,31)+monthrange:monthrange:Dates.DateTime(2017,12,31)
dateranges = [(y1, y2) for (y1, y2) in zip(y1, y2)]
myquery = [Dict("date"=> Dict("\$gt"=> date1, "\$lte"=> date2)) for (date1, date2) in dateranges]
# query = {"td": {"$gte": 3750}}
retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100"]
X = @time queryStepWiseDF(myquery, retvalues)
@time sort!(X, [:permno, :date])


monthrange = Month(3)
y1 = Dates.DateTime(2002,12,31):monthrange:Dates.DateTime(2017,12,31)-monthrange
y2 = Dates.DateTime(2002,12,31)+monthrange:monthrange:Dates.DateTime(2017,12,31)
dateranges = [(y1, y2) for (y1, y2) in zip(y1, y2)]
myquery = [Dict("date"=> Dict("\$gt"=> date1, "\$lte"=> date2)) for (date1, date2) in dateranges]
# query = {"td": {"$gte": 3750}}
retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RES_excl_RESF_excl_nov24H_0_rel100", "posSum_RES_excl_RESF_excl_nov24H_0_rel100", "negSum_RES_excl_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100"]
X = @time queryStepWiseDF(myquery, retvalues)
@time sort!(X, [:permno, :date])


function standardizePerPeriod(X, myvar; datevar=:date, per=Dates.year)
    X[:pergroup] = per.(X[datevar])
    a = by(X, :pergroup) do xdf
        res=Dict()
        res[:meanvar] = mean(skipmissing(xdf[myvar]))
        res[:stdvar] = std(skipmissing(xdf[myvar]))
        DataFrame(res)
    end
    X = join(X, a, kind=:left, on=:pergroup)
    res = (X[myvar] .- X[:meanvar]) ./ X[:stdvar]
    return res
end

# Keep only price > 5
X = X[replace(X[:prc], missing=>0).>5,:]
deletecols!(X, :prc)

# Compute around EAD
X[:EAD] = convert(Array{Int8}, replace(X[:EAD], missing=>0))
X[:a_EAD] = copy(X[:EAD])
for row in 2:size(X, 1)-1
    if X[row-1, :EAD]==1 || X[row+1, :EAD]==1
        X[row, :a_EAD] = 1
    end
end

# Reverse ranksize
X[:ranksize] = replace(X[:ranksize], 1=>10, 2=>9, 3=>8, 4=>7, 5=>6, 6=>5, 7=>4, 8=>3, 9=>2, 10=>1)

#GRO and VAL quintiles
X = X[.!ismissing.(X[:rankbm]),:]
X = X[.!ismissing.(X[:ranksize]),:]

X[:VAL] = Array{Union{Missing, Int}}(undef, size(X,1))
X[:GRO] = Array{Union{Missing, Int}}(undef, size(X,1))
for row in 1:size(X,1)
    if !ismissing(X[row, :rankbm])
        if X[row, :rankbm]>=9
            X[row, :VAL] = 1
            X[row, :GRO] = 0
        elseif X[row, :rankbm]<=2
            X[row, :VAL] = 0
            X[row, :GRO] = 1
        else
            X[row, :VAL] = 0
            X[row, :GRO] = 0
        end
    end
end

X[:SMALL] = Array{Union{Missing, Int}}(undef, size(X,1))
X[:BIG] = Array{Union{Missing, Int}}(undef, size(X,1))
for row in 1:size(X,1)
    if !ismissing(X[row, :ranksize])
        if X[row, :ranksize]>=9
            X[row, :SMALL] = 1
            X[row, :BIG] = 0
        elseif X[row, :ranksize]<=2
            X[row, :SMALL] = 0
            X[row, :BIG] = 1
        else
            X[row, :SMALL] = 0
            X[row, :BIG] = 0
        end
    end
end


# Compute NDay
X[:nS_nov24H_0_rel100] = replace(X[:nS_nov24H_0_rel100], missing=>0)
X[:NDay] = 0
for row in 1:size(X,1)
    if X[row,:nS_nov24H_0_rel100] > 0
        X[row,:NDay] = 1
    end
end
X[:nS_RES_inc_RESF_excl_nov24H_0_rel100] = replace(X[:nS_RES_inc_RESF_excl_nov24H_0_rel100], missing=>0)
X[:NDayRES] = 0
for row in 1:size(X,1)
    if X[row,:nS_RES_inc_RESF_excl_nov24H_0_rel10nS_RES_inc_RESF_excl_nov24H_0_rel1000] > 0
        X[row,:NDayRES] = 1
    end
end
X[:nS_RESF_inc_nov24H_0_rel100] = replace(X[:nS_RESF_inc_nov24H_0_rel100], missing=>0)
X[:NDayRESF] = 0
for row in 1:size(X,1)
    if X[row,:nS_RESF_inc_nov24H_0_rel100] > 0
        X[row,:NDayRESF] = 1
    end
end
X[:nS_RES_excl_RESF_excl_nov24H_0_rel100] = replace(X[:nS_RES_excl_RESF_excl_nov24H_0_rel100], missing=>0)
X[:NDayOTHER] = 0
for row in 1:size(X,1)
    if X[row,:nS_RES_excl_RESF_excl_nov24H_0_rel100] > 0
        X[row,:NDayOTHER] = 1
    end
end
for row in 1:size(X,1)
    if X[row,:nS_RES_inc_RESF_excl_nov24H_0_rel100] > 0
        X[row,:NDayRES] = 1
    end
end
X[:nS_RESF_inc_nov24H_0_rel100] = replace(X[:nS_RESF_inc_nov24H_0_rel100], missing=>0)
X[:NDayRESF] = 0
for row in 1:size(X,1)
    if X[row,:nS_RESF_inc_nov24H_0_rel100] > 0
        X[row,:NDayRESF] = 1
    end
end
X[:nS_RES_excl_RESF_excl_nov24H_0_rel100] = replace(X[:nS_RES_excl_RESF_excl_nov24H_0_rel100], missing=>0)
X[:NDayOTHER] = 0
for row in 1:size(X,1)
    if X[row,:nS_RES_excl_RESF_excl_nov24H_0_rel100] > 0
        X[row,:NDayOTHER] = 1
    end
end


# Compute sentiment
X[:NEG_ALL] = X[:negSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:POS_ALL] = X[:posSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:SENT_ALL] = (X[:posSum_nov24H_0_rel100] .- X[:negSum_nov24H_0_rel100]) ./ X[:nS_nov24H_0_rel100]
X[:NEG_RES] = X[:negSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:POS_RES] = X[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:SENT_RES] = (X[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] .- X[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]) ./ X[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
X[:NEG_RESF] = X[:negSum_RESF_inc_nov24H_0_rel100] ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:POS_RESF] = X[:posSum_RESF_inc_nov24H_0_rel100] ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:SENT_RESF] = (X[:posSum_RESF_inc_nov24H_0_rel100] .- X[:negSum_RESF_inc_nov24H_0_rel100]) ./ X[:nS_RESF_inc_nov24H_0_rel100]
X[:NEG_OTHER] = X[:negSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
X[:POS_OTHER] = X[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ X[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
X[:SENT_OTHER] = (X[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] .- X[:negSum_RES_excl_RESF_excl_nov24H_0_rel100]) ./ X[:nS_RES_excl_RESF_excl_nov24H_0_rel100]


# Portfolio sentiment
function weightVar(crtdf,varDict; WS="VW")
    crtdf[:driftW] = everyDayWeights(crtdf, WS)
    res = by(crtdf, [:date]) do xdf
        res = Dict()
        for (k,v) in varDict
            idx = findall(.!ismissing.(xdf[v]))
            nonMissW = sum(xdf[:driftW][idx])
            res[k] = sum(xdf[v][idx] .* (xdf[:driftW][idx] ./ nonMissW) )
        end
        DataFrame(res)
    end
    return res
end

function sumVar(crtdf,varDict)
    res = by(crtdf, [:date]) do xdf
        res = Dict()
        for (k,v) in varDict
            res[k] = sum(skipmissing(xdf[v]))
        end
        DataFrame(res)
    end
    return res
end

varDict = OrderedDict(:Mkt_SENT_ALL=>:SENT_ALL, :Mkt_NEG_ALL=>:NEG_ALL, :Mkt_POS_ALL=>:POS_ALL)
Mkt=sort(weightVar(X,varDict; WS="VW"), :date)
plot(Mkt[:Mkt_SENT_ALL])
Mkt[:Mkt_NEUT_ALL] = 1 .- Mkt[:Mkt_POS_ALL] .- Mkt[:Mkt_NEG_ALL]
varDict = OrderedDict(:VAL_SENT_ALL=>:SENT_ALL, :VAL_NEG_ALL=>:NEG_ALL, :VAL_POS_ALL=>:POS_ALL)
VAL=sort(weightVar(X[X[:VAL].==1,:],varDict; WS="VW"), :date)[:, 2:4]
VAL[:VAL_NEUT_ALL] = 1 .- VAL[:VAL_POS_ALL] .- VAL[:VAL_NEG_ALL]
varDict = OrderedDict(:GRO_SENT_ALL=>:SENT_ALL, :GRO_NEG_ALL=>:NEG_ALL, :GRO_POS_ALL=>:POS_ALL)
GRO=sort(weightVar(X[X[:GRO].==1,:],varDict; WS="VW"), :date)[:, 2:4]
GRO[:GRO_NEUT_ALL] = 1 .- GRO[:GRO_POS_ALL] .- GRO[:GRO_NEG_ALL]
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:HML_SENT_ALL, :HML_NEG_ALL, :HML_POS_ALL, :HML_NEUT_ALL])
ALL = hcat(Mkt, VAL, GRO, HML)

varDict = OrderedDict(:Mkt_SENT_RES=>:SENT_RES, :Mkt_NEG_RES=>:NEG_RES, :Mkt_POS_RES=>:POS_RES)
Mkt=sort(weightVar(X,varDict; WS="VW"), :date)
Mkt[:Mkt_NEUT_RES] = 1 .- Mkt[:Mkt_POS_RES] .- Mkt[:Mkt_NEG_RES]
varDict = OrderedDict(:VAL_SENT_RES=>:SENT_RES, :VAL_NEG_RES=>:NEG_RES, :VAL_POS_RES=>:POS_RES)
VAL=sort(weightVar(X[X[:VAL].==1,:],varDict; WS="VW"), :date)[:, 2:4]
VAL[:VAL_NEUT_RES] = 1 .- VAL[:VAL_POS_RES] .- VAL[:VAL_NEG_RES]
varDict = OrderedDict(:GRO_SENT_RES=>:SENT_RES, :GRO_NEG_RES=>:NEG_RES, :GRO_POS_RES=>:POS_RES)
GRO=sort(weightVar(X[X[:GRO].==1,:],varDict; WS="VW"), :date)[:, 2:4]
GRO[:GRO_NEUT_RES] = 1 .- GRO[:GRO_POS_RES] .- GRO[:GRO_NEG_RES]
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:HML_SENT_RES, :HML_NEG_RES, :HML_POS_RES, :HML_NEUT_RES])
RES = hcat(Mkt, VAL, GRO, HML)
deletecols!(RES, :date)


varDict = OrderedDict(:Mkt_SENT_RESF=>:SENT_RESF, :Mkt_NEG_RESF=>:NEG_RESF, :Mkt_POS_RESF=>:POS_RESF)
Mkt=sort(weightVar(X,varDict; WS="VW"), :date)
Mkt[:Mkt_NEUT_RESF] = 1 .- Mkt[:Mkt_POS_RESF] .- Mkt[:Mkt_NEG_RESF]
varDict = OrderedDict(:VAL_SENT_RESF=>:SENT_RESF, :VAL_NEG_RESF=>:NEG_RESF, :VAL_POS_RESF=>:POS_RESF)
VAL=sort(weightVar(X[X[:VAL].==1,:],varDict; WS="VW"), :date)[:, 2:4]
VAL[:VAL_NEUT_RESF] = 1 .- VAL[:VAL_POS_RESF] .- VAL[:VAL_NEG_RESF]
varDict = OrderedDict(:GRO_SENT_RESF=>:SENT_RESF, :GRO_NEG_RESF=>:NEG_RESF, :GRO_POS_RESF=>:POS_RESF)
GRO=sort(weightVar(X[X[:GRO].==1,:],varDict; WS="VW"), :date)[:, 2:4]
GRO[:GRO_NEUT_RESF] = 1 .- GRO[:GRO_POS_RESF] .- GRO[:GRO_NEG_RESF]
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:HML_SENT_RESF, :HML_NEG_RESF, :HML_POS_RESF, :HML_NEUT_RESF])
RESF = hcat(Mkt, VAL, GRO, HML)
deletecols!(RESF, :date)


varDict = OrderedDict(:Mkt_SENT_OTHER=>:SENT_OTHER, :Mkt_NEG_OTHER=>:NEG_OTHER, :Mkt_POS_OTHER=>:POS_OTHER)
Mkt=sort(weightVar(X,varDict; WS="VW"), :date)
Mkt[:Mkt_NEUT_OTHER] = 1 .- Mkt[:Mkt_POS_OTHER] .- Mkt[:Mkt_NEG_OTHER]
varDict = OrderedDict(:VAL_SENT_OTHER=>:SENT_OTHER, :VAL_NEG_OTHER=>:NEG_OTHER, :VAL_POS_OTHER=>:POS_OTHER)
VAL=sort(weightVar(X[X[:VAL].==1,:],varDict; WS="VW"), :date)[:, 2:4]
VAL[:VAL_NEUT_OTHER] = 1 .- VAL[:VAL_POS_OTHER] .- VAL[:VAL_NEG_OTHER]
varDict = OrderedDict(:GRO_SENT_OTHER=>:SENT_OTHER, :GRO_NEG_OTHER=>:NEG_OTHER, :GRO_POS_OTHER=>:POS_OTHER)
GRO=sort(weightVar(X[X[:GRO].==1,:],varDict; WS="VW"), :date)[:, 2:4]
GRO[:GRO_NEUT_OTHER] = 1 .- GRO[:GRO_POS_OTHER] .- GRO[:GRO_NEG_OTHER]
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:HML_SENT_OTHER, :HML_NEG_OTHER, :HML_POS_OTHER, :HML_NEUT_OTHER])
OTHER = hcat(Mkt, VAL, GRO, HML)
deletecols!(OTHER, :date)

FF = FFfactors()[[:Mkt_RF, :HML, :SMB, :Mom]]
Tdata = hcat(ALL, RES, RESF, OTHER, FF)
X = @time join(X, Tdata, on=:date, kind=:left)


# Dispersion of sentiment
@time dispersion = by(X, [:date]) do xdf
    res = Dict()
    res[:disp_SENT_ALL] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:SENT_ALL]))))
    res[:disp_SENT_RES] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:SENT_RES]))))
    res[:disp_SENT_RESF] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:SENT_RESF]))))
    res[:disp_SENT_OTHER] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:SENT_OTHER]))))
    res[:disp_POS_ALL] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_ALL]))))
    res[:disp_POS_RES] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_RES]))))
    res[:disp_POS_RESF] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_RESF]))))
    res[:disp_POS_OTHER] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_OTHER]))))
    res[:disp_NEG_ALL] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:NEG_ALL]))))
    res[:disp_NEG_RES] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:NEG_RES]))))
    res[:disp_NEG_RESF] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:NEG_RESF]))))
    res[:disp_NEG_OTHER] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:NEG_OTHER]))))
    DataFrame(res)
end
X = join(X, dispersion, on=:date, kind=:left)


# Surprise
@time surp = by(X, [:date]) do xdf
    res = Dict()
    res[:sum_NEG_ALL] = sum(skipmissing(xdf[:negSum_nov24H_0_rel100]))
    res[:sum_POS_ALL] = sum(skipmissing(xdf[:posSum_nov24H_0_rel100]))
    res[:sum_nS_ALL] = sum(skipmissing(xdf[:nS_nov24H_0_rel100]))
    res[:sum_NEG_RES] = sum(skipmissing(xdf[:negSum_nov24H_0_rel100]))
    res[:sum_POS_RES] = sum(skipmissing(xdf[:posSum_nov24H_0_rel100]))
    res[:sum_nS_RES] = sum(skipmissing(xdf[:nS_nov24H_0_rel100]))
    res[:sum_NEG_RESF] = sum(skipmissing(xdf[:negSum_nov24H_0_rel100]))
    res[:sum_POS_RESF] = sum(skipmissing(xdf[:posSum_nov24H_0_rel100]))
    res[:sum_nS_RESF] = sum(skipmissing(xdf[:nS_nov24H_0_rel100]))
    DataFrame(res)
end
X = join(X, superNews, on=:date, kind=:left)


# Standardized coverage



# Val vs Gro positive



# strong Val - growth
X[:SuperGood] = 0
X[:SuperBad] = 0
for row in 1:size(X,1)
    if !ismissing(X[row,:posSum_nov24H_0_rel100]) && X[row,:posSum_nov24H_0_rel100] >= 0.5
        X[row,:SuperGood] = 1
    elseif !ismissing(X[row,:negSum_nov24H_0_rel100]) && X[row,:negSum_nov24H_0_rel100] <= 0.5
        X[row,:SuperBad] = 1
    end
end
superNews = by(X, [:date]) do xdf
    res = Dict()
    goodvalsum = 0
    badvalsum = 0
    goodgrosum = 0
    badgrosum = 0
    for row in 1:size(xdf,1)
        if xdf[row,:VAL]==1
            goodvalsum+=xdf[row,:SuperGood]
            badvalsum+=xdf[row,:SuperGood]
        elseif xdf[row,:GRO]==1
            goodgrosum+=xdf[row,:SuperGood]
            badgrosum+=xdf[row,:SuperGood]
        end
    end
    totnews = sum(xdf[:NDay])
    res[:ValGood] = goodvalsum/totnews
    res[:ValBad] = badvalsum/totnews
    res[:GroGood] = goodgrosum/totnews
    res[:GroBad] = badgrosum/totnews
    res[:HML_Good] = (goodvalsum-goodgrosum)/totnews
    res[:HML_Bad] = (badvalsum-badgrosum)/totnews
    DataFrame(res)
end
X = join(X, superNews, on=:date, kind=:left)



# Monthly aggreg
X[:ymonth] = yearmonth.(X[:date])
@time a = by(X, [:permno, :ymonth]) do xdf
    res = Dict()
    pos = sum(skipmissing(xdf[:posSum_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_nov24H_0_rel100]))
    res[:M_SENT_ALL] = (pos-neg)/totnews
    pos = sum(skipmissing(xdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]))
    res[:M_SENT_RES] = (pos-neg)/totnews
    pos = sum(skipmissing(xdf[:posSum_RESF_inc_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_RESF_inc_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_RESF_inc_nov24H_0_rel100]))
    res[:M_SENT_RESF] = (pos-neg)/totnews
    pos = sum(skipmissing(xdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]))
    res[:M_SENT_OTHER] = (pos-neg)/totnews
    res[:VAL] = xdf[:VAL][end]
    res[:GRO] = xdf[:GRO][end]
    res[:date] = xdf[:date][end]
    res[:retM] = cumret(xdf[:retadj])
    # Sum of EAD and news
    res[:EADM] = sum(skipmissing(xdf[:EAD]))
    res[:covM] = totnews
    res[:HML_M] = cumret(xdf[:HML])
    res[:M_ValGood] = sum(skipmissing(xdf[:ValGood]))
    res[:M_ValBad] = sum(skipmissing(xdf[:ValBad]))
    res[:M_GroGood] = sum(skipmissing(xdf[:GroGood]))
    res[:M_GroBad] = sum(skipmissing(xdf[:GroBad]))
    res[:M_HMLGood] = mean(skipmissing(xdf[:HML_Good]))
    res[:M_HMLBad] = mean(skipmissing(xdf[:HML_Bad]))
    res[:M_disp_SENT_ALL] = mean(skipmissing(xdf[:disp_SENT_ALL]))
    res[:M_disp_SENT_RES] = mean(skipmissing(xdf[:disp_SENT_RES]))
    res[:M_disp_SENT_RESF] = mean(skipmissing(xdf[:disp_SENT_RESF]))
    res[:M_disp_SENT_OTHER] = mean(skipmissing(xdf[:disp_SENT_OTHER]))
    res[:M_disp_POS_ALL] = mean(skipmissing(xdf[:disp_POS_ALL]))
    res[:M_disp_POS_RES] = mean(skipmissing(xdf[:disp_POS_RES]))
    res[:M_disp_POS_RESF] = mean(skipmissing(xdf[:disp_POS_RESF]))
    res[:M_disp_POS_OTHER] = mean(skipmissing(xdf[:disp_POS_OTHER]))
    res[:M_disp_NEG_ALL] = mean(skipmissing(xdf[:disp_NEG_ALL]))
    res[:M_disp_NEG_RES] = mean(skipmissing(xdf[:disp_NEG_RES]))
    res[:M_disp_NEG_RESF] = mean(skipmissing(xdf[:disp_NEG_RESF]))
    res[:M_disp_NEG_OTHER] = mean(skipmissing(xdf[:disp_NEG_OTHER]))
    DataFrame(res)
end
a[:M_SENT_ALL] = replace(a[:M_SENT_ALL], NaN=>missing); a[:M_SENT_RES] = replace(a[:M_SENT_RES], NaN=>missing)
a[:M_SENT_RESF] = replace(a[:M_SENT_RESF], NaN=>missing); a[:M_SENT_OTHER] = replace(a[:M_SENT_OTHER], NaN=>missing)
@time b = by(a, :ymonth) do xdf
    res = Dict()
    valdf = xdf[replace(xdf[:VAL], missing=>NaN).==1,:]
    grodf = xdf[replace(xdf[:GRO], missing=>NaN).==1,:]
    res[:HML_M_] = mean(skipmissing(xdf[:HML_M]))
    res[:M_SENT_ALL_VAL] = mean(skipmissing(valdf[:M_SENT_ALL]))
    res[:M_SENT_ALL_GRO] = mean(skipmissing(grodf[:M_SENT_ALL]))
    res[:M_SENT_RES_VAL] = mean(skipmissing(valdf[:M_SENT_RES]))
    res[:M_SENT_RES_GRO] = mean(skipmissing(grodf[:M_SENT_RES]))
    res[:M_SENT_RESF_VAL] = mean(skipmissing(valdf[:M_SENT_RESF]))
    res[:M_SENT_RESF_GRO] = mean(skipmissing(grodf[:M_SENT_RESF]))
    res[:M_SENT_OTHER_VAL] = mean(skipmissing(valdf[:M_SENT_OTHER]))
    res[:M_SENT_OTHER_GRO] = mean(skipmissing(grodf[:M_SENT_OTHER]))
    # Val and GRO return
    res[:retM_VAL] = mean(skipmissing(valdf[:retM]))
    res[:retM_GRO] = mean(skipmissing(grodf[:retM]))
    res[:covM_VAL] = mean(skipmissing(valdf[:covM]))
    res[:covM_GRO] = mean(skipmissing(grodf[:covM]))
    DataFrame(res)
end
@time c = by(a, :permno) do xdf
    res = Dict()
    # lagged monthly return
    res[:f1_retM] = lead(xdf[:retM])
    res[:f2_retM] = lead(xdf[:retM], 2)
    res[:f3_retM] = lead(xdf[:retM], 3)
    res[:f4_retM] = lead(xdf[:retM], 4)
    res[:f5_retM] = lead(xdf[:retM], 5)
    res[:f6_retM] = lead(xdf[:retM], 6)
    res[:l1_retM] = lag(xdf[:retM])
    res[:l2_retM] = lag(xdf[:retM], 2)
    res[:l3_retM] = lag(xdf[:retM], 3)
    res[:l4_retM] = lag(xdf[:retM], 4)
    res[:l5_retM] = lag(xdf[:retM], 5)
    res[:l6_retM] = lag(xdf[:retM], 6)
    res[:ymonth] = xdf[:ymonth]
    DataFrame(res)
end
sort!(c, [:permno, :ymonth])
sort!(a, [:permno, :ymonth])
deletecols!(c, [:permno, :ymonth])
a = hcat(a, c)

a = join(a, b, on=:ymonth, kind=:left)
a[:M_SENT_ALL_HML] = a[:M_SENT_ALL_VAL] .- a[:M_SENT_ALL_GRO]
a[:M_SENT_RES_HML] = a[:M_SENT_RES_VAL] .- a[:M_SENT_RES_GRO]
a[:M_SENT_RESF_HML] = a[:M_SENT_RESF_VAL] .- a[:M_SENT_RESF_GRO]
a[:M_SENT_OTHER_HML] = a[:M_SENT_OTHER_VAL] .- a[:M_SENT_OTHER_GRO]
a[:retM_HML] = a[:retM_VAL] .- a[:retM_GRO]
a[:covM_HML] = a[:covM_VAL] .- a[:covM_GRO]
# X = join(X, a, on=[:ymonth], kind=:left)

function my_latex_estim_decoration(s::String, pval::Float64)
  if pval<0.0
      error("p value needs to be nonnegative.")
  end
  if (pval > 0.1)
      return "$s"
  elseif (pval > 0.05)
      return "$s*"
  elseif (pval > 0.01)
      return "$s**"
  elseif (pval > 0.001)
      return "$s***"
  else
      return "$s***"
  end
end


using FixedEffectModels, RegressionTables
X[:DateCategorical] = categorical(X[:date])
X[:SENT_ALL_] = (replace(X[:SENT_ALL], missing=>0) .- mean(skipmissing(X[:SENT_ALL]))) ./ std(skipmissing(X[:SENT_ALL]))
X[:POS_ALL_] = (replace(X[:POS_ALL], missing=>0) .- mean(skipmissing(X[:POS_ALL]))) ./ std(skipmissing(X[:POS_ALL]))
X[:NEG_ALL_] = (replace(X[:NEG_ALL], missing=>0) .- mean(skipmissing(X[:NEG_ALL]))) ./ std(skipmissing(X[:NEG_ALL]))
X[:ret] = X[:retadj] .* 100

# Baseline
m1 = @time reg(X, @model(ret ~ rankbm*a_EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(ret ~ ranksize*a_EAD + ranksize*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(ret ~ BIG*a_EAD + BIG*NDay + SMALL*a_EAD + SMALL*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/baseline.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# Setiment interaction BM
# m1a = @time reg(X, @model(ret ~ VAL*EAD + VAL*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
# m1b = @time reg(X, @model(ret ~ GRO*EAD + GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m1 = @time reg(X, @model(ret ~ VAL + GRO + EAD + NDay + VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2a = @time reg(X, @model(ret ~ VAL + GRO + EAD + NDay + VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + SENT_ALL_ + SENT_ALL_&EAD + VAL&SENT_ALL_ + GRO&SENT_ALL_ + VAL&EAD&SENT_ALL_  + GRO&EAD&SENT_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2b = @time reg(X, @model(ret ~ VAL + GRO + EAD + NDay + VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + SENT_ALL_ + SENT_ALL_&EAD + VAL&SENT_ALL_ + GRO&SENT_ALL_ + VAL&EAD&SENT_ALL_  + GRO&EAD&SENT_ALL_
                                + NDayRES + NDayRES&SENT_ALL_ + NDayRES&SENT_ALL_&GRO + NDayRES&SENT_ALL_&VAL , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2c = @time reg(X, @model(ret ~ VAL + GRO + EAD + NDay + VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + SENT_ALL_ + SENT_ALL_&EAD + VAL&SENT_ALL_ + GRO&SENT_ALL_ + VAL&EAD&SENT_ALL_  + GRO&EAD&SENT_ALL_
                                + NDayRESF + NDayRESF&SENT_ALL_ + NDayRESF&SENT_ALL_&GRO + NDayRESF&SENT_ALL_&VAL , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2d = @time reg(X, @model(ret ~ VAL + GRO + EAD + NDay + VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + SENT_ALL_ + SENT_ALL_&EAD + VAL&SENT_ALL_ + GRO&SENT_ALL_ + VAL&EAD&SENT_ALL_  + GRO&EAD&SENT_ALL_
                                + NDayOTHER + NDayOTHER&SENT_ALL_ + NDayOTHER&SENT_ALL_&GRO + NDayOTHER&SENT_ALL_&VAL , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m3 = @time reg(X, @model(ret ~ VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + VAL*EAD*POS_ALL_  + GRO*EAD*POS_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m4 = @time reg(X, @model(ret ~ VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + VAL*EAD*NEG_ALL_ + GRO*EAD*NEG_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m5 = @time reg(X, @model(ret ~ VAL&EAD + GRO&EAD + VAL&NDay + GRO&NDay + VAL*EAD*NEG_ALL_ + GRO*EAD*NEG_ALL_ + VAL*EAD*POS_ALL_  + GRO*EAD*POS_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2a, m2b, m2c, m2d; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/sentimentBM.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# Sentiment interaction Size
# m1b = @time reg(X, @model(ret ~ BIG*EAD + BIG*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m1 = @time reg(X, @model(ret ~ SMALL + BIG + EAD + NDay + SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2a = @time reg(X, @model(ret ~ SMALL + BIG + EAD + NDay + SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SENT_ALL_ + SENT_ALL_&EAD + SMALL&SENT_ALL_ + BIG&SENT_ALL_ + SMALL&EAD&SENT_ALL_  + BIG&EAD&SENT_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2b = @time reg(X, @model(ret ~ SMALL + BIG + EAD + NDay + SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SENT_ALL_ + SENT_ALL_&EAD + SMALL&SENT_ALL_ + BIG&SENT_ALL_ + SMALL&EAD&SENT_ALL_  + BIG&EAD&SENT_ALL_
                                + NDayRES + NDayRES&SENT_ALL_ + NDayRES&SENT_ALL_&BIG + NDayRES&SENT_ALL_&SMALL , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2c = @time reg(X, @model(ret ~ SMALL + BIG + EAD + NDay + SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SENT_ALL_ + SENT_ALL_&EAD + SMALL&SENT_ALL_ + BIG&SENT_ALL_ + SMALL&EAD&SENT_ALL_  + BIG&EAD&SENT_ALL_
                                + NDayRESF + NDayRESF&SENT_ALL_ + NDayRESF&SENT_ALL_&BIG + NDayRESF&SENT_ALL_&SMALL , fe = DateCategorical, vcov = cluster(DateCategorical)))
m2d = @time reg(X, @model(ret ~ SMALL + BIG + EAD + NDay + SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SENT_ALL_ + SENT_ALL_&EAD + SMALL&SENT_ALL_ + BIG&SENT_ALL_ + SMALL&EAD&SENT_ALL_  + BIG&EAD&SENT_ALL_
                                + NDayOTHER + NDayOTHER&SENT_ALL_ + NDayOTHER&SENT_ALL_&BIG + NDayOTHER&SENT_ALL_&SMALL , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m3 = @time reg(X, @model(ret ~ SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SMALL*EAD*POS_ALL_  + BIG*EAD*POS_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m4 = @time reg(X, @model(ret ~ SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SMALL*EAD*NEG_ALL_ + BIG*EAD*NEG_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
# m5 = @time reg(X, @model(ret ~ SMALL&EAD + BIG&EAD + SMALL&NDay + BIG&NDay + SMALL*EAD*NEG_ALL_ + BIG*EAD*NEG_ALL_ + SMALL*EAD*POS_ALL_  + BIG*EAD*POS_ALL_ , fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2a, m2b, m2c, m2d; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/sentimentSIZE.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# HML daily sent
m1 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2a = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_ALL*VAL*a_EAD + HML_SENT_ALL*VAL*NDay + HML_SENT_ALL*GRO*a_EAD + HML_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2b = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + Mkt_SENT_ALL*VAL*a_EAD + Mkt_SENT_ALL*VAL*NDay + Mkt_SENT_ALL*GRO*a_EAD + Mkt_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2bb = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + Mkt_RF*VAL*a_EAD + Mkt_RF*VAL*NDay + Mkt_RF*GRO*a_EAD + Mkt_RF*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2c = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + VAL_SENT_ALL*VAL*a_EAD + VAL_SENT_ALL*VAL*NDay + VAL_SENT_ALL*GRO*a_EAD + VAL_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2d = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + GRO_SENT_ALL*VAL*a_EAD + GRO_SENT_ALL*VAL*NDay + GRO_SENT_ALL*GRO*a_EAD + GRO_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2a, m2b, m2bb, m2c, m2d; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/HMLsentALL.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# Daily dispersion
m1 = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2a = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL + HML_SENT_ALL*VAL*a_EAD + HML_SENT_ALL*VAL*NDay + HML_SENT_ALL*GRO*a_EAD + HML_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2b = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL + Mkt_SENT_ALL*VAL*a_EAD + Mkt_SENT_ALL*VAL*NDay + Mkt_SENT_ALL*GRO*a_EAD + Mkt_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2bb = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL + Mkt_RF*VAL*a_EAD + Mkt_RF*VAL*NDay + Mkt_RF*GRO*a_EAD + Mkt_RF*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2c = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL + VAL_SENT_ALL*VAL*a_EAD + VAL_SENT_ALL*VAL*NDay + VAL_SENT_ALL*GRO*a_EAD + VAL_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2d = @time reg(X, @model(ret ~ VAL*a_EAD*disp_SENT_ALL + VAL*NDay*disp_SENT_ALL + GRO*a_EAD*disp_SENT_ALL + GRO*NDay*disp_SENT_ALL + GRO_SENT_ALL*VAL*a_EAD + GRO_SENT_ALL*VAL*NDay + GRO_SENT_ALL*GRO*a_EAD + GRO_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2a, m2b, m2bb, m2c, m2d; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/HMLsentALLdispersion.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# HML daily RES
m1 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2a = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_RES*VAL*a_EAD + HML_SENT_RES*VAL*NDay + HML_SENT_RES*GRO*a_EAD + HML_SENT_RES*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2b = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + Mkt_SENT_RES*VAL*a_EAD + Mkt_SENT_RES*VAL*NDay + Mkt_SENT_RES*GRO*a_EAD + Mkt_SENT_RES*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2bb = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + Mkt_RF*VAL*a_EAD + Mkt_RF*VAL*NDay + Mkt_RF*GRO*a_EAD + Mkt_RF*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2c = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + VAL_SENT_RES*VAL*a_EAD + VAL_SENT_RES*VAL*NDay + VAL_SENT_RES*GRO*a_EAD + VAL_SENT_RES*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2d = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + GRO_SENT_RES*VAL*a_EAD + GRO_SENT_RES*VAL*NDay + GRO_SENT_RES*GRO*a_EAD + GRO_SENT_RES*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2a, m2b, m2bb, m2c, m2d; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/HMLsentRES.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")
# HML topic
m1 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_ALL*VAL*a_EAD + HML_SENT_ALL*VAL*NDay + HML_SENT_ALL*GRO*a_EAD + HML_SENT_ALL*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_RES*VAL*a_EAD + HML_SENT_RES*VAL*NDay + HML_SENT_RES*GRO*a_EAD + HML_SENT_RES*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_RESF*VAL*a_EAD + HML_SENT_RESF*VAL*NDay + HML_SENT_RESF*GRO*a_EAD + HML_SENT_RESF*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(ret ~ VAL*a_EAD + VAL*NDay + GRO*a_EAD + GRO*NDay + HML_SENT_OTHER*VAL*a_EAD + HML_SENT_OTHER*VAL*NDay + HML_SENT_OTHER*GRO*a_EAD + HML_SENT_OTHER*GRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/HMLsentTopics.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# Coverage (standardized)

# Surprise

# Dispersion

# Monthly
a[:MonthCategorical] = categorical(a[:ymonth])
a[:M_ret] = 100 .* a[:retM]
a[:M_ret_f1] = 100 .* a[:f1_retM]
a[:M_ret_f2] = 100 .* a[:f2_retM]
a[:M_ret_f3] = 100 .* a[:f3_retM]
a[:M_ret_f4] = 100 .* a[:f4_retM]
a[:M_ret_f5] = 100 .* a[:f5_retM]
a[:M_ret_f6] = 100 .* a[:f6_retM]
a[:M_ret_l1] = 100 .* a[:l1_retM]
a[:M_ret_l2] = 100 .* a[:l2_retM]
a[:M_ret_l3] = 100 .* a[:l3_retM]
a[:M_ret_l4] = 100 .* a[:l4_retM]
a[:M_ret_l5] = 100 .* a[:l5_retM]
a[:M_ret_l6] = 100 .* a[:l6_retM]
a[:M_SENT_ALL_] = (replace(a[:M_SENT_ALL], missing=>0) .- mean(skipmissing(a[:M_SENT_ALL]))) ./ std(skipmissing(a[:M_SENT_ALL]))
a[:M_SENT_ALL_HML_] = (replace(a[:M_SENT_ALL_HML], missing=>0) .- mean(skipmissing(a[:M_SENT_ALL_HML]))) ./ std(skipmissing(a[:M_SENT_ALL_HML]))
a[:M_SENT_RES_HML_] = (replace(a[:M_SENT_RES_HML], missing=>0) .- mean(skipmissing(a[:M_SENT_RES_HML]))) ./ std(skipmissing(a[:M_SENT_RES_HML]))
a[:M_SENT_RESF_HML_] = (replace(a[:M_SENT_RESF_HML], missing=>0) .- mean(skipmissing(a[:M_SENT_RESF_HML]))) ./ std(skipmissing(a[:M_SENT_RESF_HML]))
a[:M_SENT_OTHER_HML_] = (replace(a[:M_SENT_OTHER_HML], missing=>0) .- mean(skipmissing(a[:M_SENT_OTHER_HML]))) ./ std(skipmissing(a[:M_SENT_OTHER_HML]))
# a[:covM_] = (replace(a[:covM], missing=>0) .- mean(skipmissing(a[:covM]))) ./ std(skipmissing(a[:covM]))
a[:covM_] = standardizePerPeriod(a, :covM)
a[:covM] = replace(a[:covM], missing=>0)
a[:covM_HML_] = standardizePerPeriod(a, :covM)
a[:covM_HML] = replace(a[:covM_HML], missing=>0)


# Own news
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_ALL_ + GRO*M_SENT_ALL_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyownNews_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# RES topic
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_RES_HML_ + GRO*M_SENT_RES_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsentRES_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# ALL topic
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_ALL_HML_ + GRO*M_SENT_ALL_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsentALL_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# RESF topic
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_RESF_HML_ + GRO*M_SENT_RESF_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsentRESF_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# OTHER topic
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_OTHER_HML_ + GRO*M_SENT_OTHER_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsentOTHER_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# HML factor
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*HML_M_ + GRO*HML_M_, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLfactor.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# Coverage HML
# HML factor
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*covM_HML_ + GRO*covM_HML_, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLcoverage_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")


# M_disp_SENT_RES
# M_HMLBad
# M_HMLGood
# Dispersion effect
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_HMLBad + GRO*M_HMLBad, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsuperBad_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# Very good/bad effect
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_HMLGood + GRO*M_HMLGood, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsuperGood_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")

# RES with dispersion
# RES topic M_disp_SENT_ALL
a[:M_disp_SENT_RES] = replace(a[:M_disp_SENT_RES], NaN=>missing)
a[:M_disp_SENT_RES] =(a[:M_disp_SENT_RES] .- mean(skipmissing(a[:M_disp_SENT_RES]))) ./ std(skipmissing(a[:M_disp_SENT_RES]))
l6 = @time reg(a, @model(M_ret_l6 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l5 = @time reg(a, @model(M_ret_l5 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l4 = @time reg(a, @model(M_ret_l4 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l3 = @time reg(a, @model(M_ret_l3 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l2 = @time reg(a, @model(M_ret_l2 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
l1 = @time reg(a, @model(M_ret_l1 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m0 = @time reg(a, @model(M_ret ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f1 = @time reg(a, @model(M_ret_f1 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f2 = @time reg(a, @model(M_ret_f2 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f3 = @time reg(a, @model(M_ret_f3 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f4 = @time reg(a, @model(M_ret_f4 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f5 = @time reg(a, @model(M_ret_f5 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
f6 = @time reg(a, @model(M_ret_f6 ~ VAL*M_SENT_RES_HML_*M_disp_SENT_RES + GRO*M_SENT_RES_HML_*M_disp_SENT_RES, fe = MonthCategorical, vcov = cluster(MonthCategorical)))

regtable(l6,l5,l4,l3,l2,l1,m0,f1,f2,f3,f4,f5,f6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/MonthlyHMLsentRESdispersion_fe.txt"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.3f")
