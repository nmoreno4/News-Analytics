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
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100",
             "nS_RES_excl_RESF_excl_nov24H_0_rel100", "posSum_RES_excl_RESF_excl_nov24H_0_rel100", "negSum_RES_excl_RESF_excl_nov24H_0_rel100"]
X = @time queryStepWise(myquery, retvalues)
@time sort!(X, [:permno, :date])

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
X[:NDayRES] = 0X[:nS_RES_inc_RESF_excl_nov24H_0_rel100] = replace(X[:nS_RES_inc_RESF_excl_nov24H_0_rel100], missing=>0)
X[:NDayRES] = 0
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
Tdata = hcat(ALL, HML, VAL, GRO, FF)
# X = join(X, Tdata, on=:date, kind=:left)

mean(skipmissing(X[:NEG_ALL]))
# Dispersion of sentiment
@time a = by(X, [:date]) do xdf
    res = Dict()
    res[:disp_SENT_ALL] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_ALL]))))
    res[:disp_SENT_RES] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_RES]))))
    res[:disp_SENT_RESF] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_RESF]))))
    res[:disp_SENT_OTHER] = std(collect(skipmissing(convert(Array{Union{Float64,Missing}}, xdf[:POS_OTHER]))))
    DataFrame(res)
end

# Surprise
@time a = by(X, [:date]) do xdf
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

# Standardized coverage



# Val vs Gro positive





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
    res[:retM] = cumret(xdf[:retadj])
    # Sum of EAD and news
    res[:EADM] = sum(skipmissing(xdf[:EAD]))
    res[:covM] = totnews
    DataFrame(res)
end
