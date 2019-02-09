using DataFrames, Statistics, StatsBase, Dates, TSmanip, ShiftedArrays,
      Wfcts, LoadFF, DataStructures

using PyCall
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")

startDate, endDate = DateTime(2003,1,1), DateTime(2018,1,1)

retVars = ["permno", "date","retadj", "ranksize", "rankbm", "EAD", "volume", "prc", "me",
           "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
           "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100",
           "nS_RES_excl_RESF_excl_nov24H_0_rel100", "posSum_RES_excl_RESF_excl_nov24H_0_rel100", "negSum_RES_excl_RESF_excl_nov24H_0_rel100",
           "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100", "nS_nov24H_0_rel100"]
retTypes = [Int128, DateTime, Float64, Int8, Int8, Int8, Float64, Float64, Float64,
            Float64, Float64, Float64,
            Float64, Float64, Float64,
            Float64, Float64, Float64,
            Float64, Float64, Float64]

retDic = Dict(zip(retVars, [1 for i in retVars]))
nbItems = @time collection[:find](Dict("date"=> Dict("\$gte"=> startDate, "\$lte"=> endDate)))[:count]()
cursor = collection[:find](Dict("date"=> Dict("\$gte"=> startDate, "\$lte"=> endDate)), retDic)
retDic = Dict(zip(retVars, [Array{Union{T,Missing}}(undef,nbItems) for T in retTypes]))
cc = [0]
sTime = now()
@time for doc in cursor
    cc[1]+=1
    if cc[1] in 1:50000:nbItems
        print("Advancement: $(round(100*cc[1]/nbItems, 2))%  -  $(Dates.canonicalize(Dates.CompoundPeriod(now()-sTime))) \n")
    end
    el = Dict(doc)
    for var in retVars
        try
            retDic[var][cc[1]] = el[var]
        catch x
            if typeof(x)==KeyError
                retDic[var][cc[1]] = missing
            else
                error(x)
            end
        end
    end
end

X = DataFrame(retDic)
X = X[replace(X[:prc], missing=>0).>5,:]
sort!(X, [:permno,:date])
deletecols!(X, :prc)
@time a = by(X, :permno) do xdf
    res = Dict()
    res[:r_l1] = lag(xdf[:retadj],1)
    res[:r_l2] = lag(xdf[:retadj],2)
    res[:r_l3] = lag(xdf[:retadj],3)
    res[:r_l4] = lag(xdf[:retadj],4)
    res[:r_l5] = lag(xdf[:retadj],5)
    res[:r_l6] = lag(xdf[:retadj],6)
    res[:r_l7] = lag(xdf[:retadj],7)
    res[:r_l8] = lag(xdf[:retadj],8)
    res[:r_l9] = lag(xdf[:retadj],9)
    res[:r_l10] = lag(xdf[:retadj],10)
    res[:r2_l1] = lag(xdf[:retadj],1) .^ 2
    res[:r2_l2] = lag(xdf[:retadj],2) .^ 2
    res[:r2_l3] = lag(xdf[:retadj],3) .^ 2
    res[:r2_l4] = lag(xdf[:retadj],4) .^ 2
    res[:r2_l5] = lag(xdf[:retadj],5) .^ 2
    res[:r2_l6] = lag(xdf[:retadj],6) .^ 2
    res[:r2_l7] = lag(xdf[:retadj],7) .^ 2
    res[:r2_l8] = lag(xdf[:retadj],8) .^ 2
    res[:r2_l9] = lag(xdf[:retadj],9) .^ 2
    res[:r2_l10] = lag(xdf[:retadj],10) .^ 2
    res[:v_l1] = lag(xdf[:volume],1)
    res[:v_l2] = lag(xdf[:volume],2)
    res[:v_l3] = lag(xdf[:volume],3)
    res[:v_l4] = lag(xdf[:volume],4)
    res[:v_l5] = lag(xdf[:volume],5)
    res[:v_l6] = lag(xdf[:volume],6)
    res[:v_l7] = lag(xdf[:volume],7)
    res[:v_l8] = lag(xdf[:volume],8)
    res[:v_l9] = lag(xdf[:volume],9)
    res[:v_l10] = lag(xdf[:volume],10)
    res[:date] = xdf[:date]
    DataFrame(res)
end
sort!(a, [:permno, :date])
deletecols!(a, [:permno, :date])
X = hcat(X,a)

X[:EAD] = replace(X[:EAD], missing=>0)
###
#!!! Add around EAD [-1,+1]
###
X[:nS_nov24H_0_rel100] = replace(X[:nS_nov24H_0_rel100], missing=>0)
X[:NDay] = 0
for row in 1:size(X,1)
    if X[row,:nS_nov24H_0_rel100] > 0
        X[row,:NDay] = 1
    end
end

X = X[replace(X[:rankbm], missing=>0).!=0,:]
X = X[replace(X[:ranksize], missing=>0).!=0,:]

X[:scaledNeg] = X[:negSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:scaledPos] = X[:posSum_nov24H_0_rel100] ./ X[:nS_nov24H_0_rel100]
X[:sent] = (X[:posSum_nov24H_0_rel100] .- X[:negSum_nov24H_0_rel100]) ./ X[:nS_nov24H_0_rel100]
X[:neg2] = replace(X[:scaledNeg], missing=>0)
X[:pos2] = replace(X[:scaledPos], missing=>0)
X[:sent2] = replace(X[:sent], missing=>0)

X[:Val] = 0
X[:Gro] = 0
for row in 1:size(X,1)
    if X[row,:rankbm] >= 9
        X[row,:Val] = 1
    elseif X[row,:rankbm] <= 2
        X[row,:Gro] = 1
    end
end

X[:Big] = 0
X[:Small] = 0
for row in 1:size(X,1)
    if X[row,:ranksize] >= 9
        X[row,:Big] = 1
    elseif X[row,:ranksize] <= 2
        X[row,:Small] = 1
    end
end



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

varDict = OrderedDict(:sentALL=>:sent, :negALL=>:scaledNeg, :posALL=>:scaledPos)
ALL=weightVar(X,varDict; WS="VW")
varDict = OrderedDict(:sentVAL=>:sent, :negVAL=>:scaledNeg, :posVAL=>:scaledPos)
VAL=weightVar(X[X[:Val].==1,:],varDict; WS="VW")
varDict = OrderedDict(:sentGRO=>:sent, :negGRO=>:scaledNeg, :posGRO=>:scaledPos)
GRO=weightVar(X[X[:Gro].==1,:],varDict; WS="VW")
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:date, :sentHML, :negHML, :posHML])
FF = FFfactors()
Tdata = hcat(ALL, HML, VAL, GRO, FF, makeunique=true)
X = join(X, Tdata, on=:date, kind=:left)


using RegressionTables, FixedEffectModels
X[:DateCategorical] = categorical(X[:date])
X[:sentALL] = convert(Array{Float64}, X[:sentALL])
X[:posALL] = convert(Array{Float64}, X[:posALL])
X[:negALL] = convert(Array{Float64}, X[:negALL])

# try wit lag and lead HML
@time a = by(X, :permno) do xdf
    res = Dict()
    res[:f1] = windowRet(xdf[:retadj], (1,1); missShortWindows=false)
    res[:l1] = windowRet(xdf[:retadj], (-1,-1); missShortWindows=false)
    res[:l_sHML_1] = windowRet(xdf[:retadj], (-1,-1); missShortWindows=false)
    res[:f_sHML_1] = windowRet(xdf[:retadj], (1,1); missShortWindows=false)
    res[:date] = xdf[:date]
    DataFrame(res)
end
sort!(a, [:permno, :date])
deletecols!(a, [:permno, :date])
X = hcat(X, a)


# Lead and lag HML sent
@time a = by(X, :permno) do xdf
    res = Dict()
    res[:l1_ALLsent] = lag(xdf[:sentALL])
    res[:f1_ALLsent] = lead(xdf[:sentALL])
    res[:l1_VALsent] = lag(xdf[:sentVAL])
    res[:f1_VALsent] = lead(xdf[:sentVAL])
    res[:l1_GROsent] = lag(xdf[:sentGRO])
    res[:f1_GROsent] = lead(xdf[:sentGRO])
    res[:l1_HMLsent] = lag(xdf[:sentHML])
    res[:f1_HMLsent] = lead(xdf[:sentHML])
    res[:date] = xdf[:date]
    DataFrame(res)
end
sort!(a, [:permno, :date])
deletecols!(a, [:permno, :date])
X = hcat(X, a)



X[:Valret] = Array{Union{Float64,Missing}}(missing, size(X,1))
X[:Groret] = Array{Union{Float64,Missing}}(missing, size(X,1))
for row in 1:size(X,1)
    if X[row,:rankbm] >= 9
        X[row,:Valret] = X[row,:retadj]
    elseif X[row,:rankbm] <= 2
        X[row,:Groret] = X[row,:retadj]
    end
end


# Count of very good days
X[:SuperGood] = 0
X[:SuperBad] = 0
for row in 1:size(X,1)
    if !ismissing(X[row,:posSum_nov24H_0_rel100]) && X[row,:posSum_nov24H_0_rel100] >= 0.5
        X[row,:SuperGood] = 1
    elseif !ismissing(X[row,:negSum_nov24H_0_rel100]) && X[row,:negSum_nov24H_0_rel100] <= 0.5
        X[row,:SuperBad] = 1
    end
end

# Topic dummies
X[:RES] = 0
X[:RESF] = 0
X[:NO_RES] = 0
X[:RES_RESF] = 0
for row in 1:size(X,1)
    if !ismissing(X[row,:nS_RES_inc_RESF_excl_nov24H_0_rel100])
        X[row,:RES] = 1
    end
    if !ismissing(X[row,:negSum_RESF_inc_nov24H_0_rel100])
        X[row,:RESF] = 1
    end
    if !ismissing(X[row,:negSum_RESF_inc_nov24H_0_rel100]) && !ismissing(X[row,:nS_RES_inc_RESF_excl_nov24H_0_rel100])
        X[row,:RES_RESF] = 1
    end
    if !ismissing(X[row,:nS_RES_excl_RESF_excl_nov24H_0_rel100])
        X[row,:NO_RES] = 1
    end
end

#Sum of coverage (and good/bad news) for VAL/GRO/ALL
varDict = OrderedDict(:covALL=>:nS_nov24H_0_rel100, :covRES_ALL=>:nS_RES_inc_RESF_excl_nov24H_0_rel100, :cov_GoodALL=>:SuperGood, :cov_BadALL=>:SuperBad)
ALL=sumVar(X,varDict)
varDict = OrderedDict(:covVAL=>:nS_nov24H_0_rel100, :covRES_VAL=>:nS_RES_inc_RESF_excl_nov24H_0_rel100, :cov_GoodVAL=>:SuperGood, :cov_BadVAL=>:SuperBad)
VAL=sumVar(X[X[:Val].==1,:],varDict)
varDict = OrderedDict(:covGRO=>:nS_nov24H_0_rel100, :covRES_GRO=>:nS_RES_inc_RESF_excl_nov24H_0_rel100, :cov_GoodGRO=>:SuperGood, :cov_BadGRO=>:SuperBad)
GRO=sumVar(X[X[:Gro].==1,:],varDict)
HML = DataFrame(convert(Matrix, VAL) .- convert(Matrix, GRO))
names!(HML, [:date, :covHML, :covRESHML, :covGoodHML, :covBadHML])
deletecols!(VAL, :date);deletecols!(GRO, :date);deletecols!(HML, :date)
Tdata = hcat(ALL, HML, VAL, GRO)
X = join(X, Tdata, on=:date, kind=:left)
for i in names(X)
    if String(i)[1:2]=="co"
        X[i] = convert(Array{Int64}, X[i])
    end
end

#Surprise

#Monthly aggreg
X[:ymonth] = yearmonth.(X[:date])
@time a = by(X, [:permno, :ymonth]) do xdf
    res = Dict()
    pos = sum(skipmissing(xdf[:posSum_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_nov24H_0_rel100]))
    res[:sentM] = (pos-neg)/totnews
    pos = sum(skipmissing(xdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100]))
    neg = sum(skipmissing(xdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]))
    totnews = sum(skipmissing(xdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]))
    res[:sentRESM] = (pos-neg)/totnews
    res[:rankbm] = xdf[:rankbm][end]
    res[:retM] = cumret(xdf[:retadj])
    # Sum of EAD and news
    res[:EADM] = sum(skipmissing(xdf[:EAD]))
    res[:covM] = totnews
    DataFrame(res)
end
a[:sentM] = replace(a[:sentM], NaN=>missing); a[:sentRESM] = replace(a[:sentRESM], NaN=>missing)
@time b = by(a, :ymonth) do xdf
    res = Dict()
    valdf = xdf[replace(xdf[:rankbm], missing=>NaN).>=9,:]
    grodf = xdf[replace(xdf[:rankbm], missing=>NaN).<=2,:]
    res[:sentM_VAL] = mean(skipmissing(valdf[:sentM]))
    res[:sentM_GRO] = mean(skipmissing(grodf[:sentM]))
    res[:sentRESM_VAL] = mean(skipmissing(valdf[:sentRESM]))
    res[:sentRESM_GRO] = mean(skipmissing(grodf[:sentRESM]))
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
    res[:ymonth] = xdf[:ymonth]
    DataFrame(res)
end
sort!(c, [:permno, :ymonth])
sort!(a, [:permno, :ymonth])
deletecols!(c, [:permno, :ymonth])
a = hcat(a, c)

a = join(a, b, on=:ymonth, kind=:left)
a[:sentM_HML] = a[:sentM_VAL] .- a[:sentM_GRO]
a[:sentRESM_HML] = a[:sentRESM_VAL] .- a[:sentRESM_GRO]
a[:covM_HML] = a[:covM_VAL] .- a[:covM_GRO]

X = join(X, a, on=[:ymonth], kind=:left)


function my_latex_estim_decoration(s::String, pval::Float64)
  if pval<0.0
      error("p value needs to be nonnegative.")
  end
  if (pval > 0.1)
      return "$s"
  elseif (pval > 0.05)
      return "$s\$^{***}\$"
  elseif (pval > 0.01)
      return "$s\$^{***}\$"
  elseif (pval > 0.001)
      return "$s\$^{***}\$"
  else
      return "$s\$^{***}\$"
  end
end

# Baseline Engelberg
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ Val*EAD + Val*NDay + Gro*EAD + Gro*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ ranksize*EAD + ranksize*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ Big*EAD + Big*NDay + Small*EAD + Small*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/baseline.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")

# coverage
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covHML + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covHML + rankbm*covALL + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covGoodHML + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covBadHML + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m5 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covGoodHML + rankbm*covBadHML + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m6 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covVAL + rankbm*covGRO + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m7 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*covRESHML + rankbm*covRES_ALL + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4, m5, m6, m7; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/coverage.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")


# topics
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*RES + NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*RESF + NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NO_RES + NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/topics.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")





# sentiment A
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*sent2, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*neg2, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*pos2, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/sentimentA.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")

#Sentiment B
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*sent, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*scaledNeg, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*scaledPos, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/sentimentB.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")


# Super Good/Bad
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*SuperBad, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*SuperGood, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/superGoodBad.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")



# HML sent + lag ==> NB: it doesn't work any better with neg or pos alone for HML/VAL/GRO
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*sentHML*NDay + rankbm*sentALL*NDay + rankbm*sentVAL*NDay + rankbm*sentGRO*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*f1_HMLsent*NDay + rankbm*f1_ALLsent*NDay + rankbm*f1_VALsent*NDay + rankbm*f1_GROsent*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*l1_HMLsent*NDay + rankbm*l1_ALLsent*NDay + rankbm*l1_VALsent*NDay + rankbm*l1_GROsent*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/HMLsent.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")


# Risk setting like Engelberg
m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*Mkt_RF*EAD + rankbm*Mkt_RF*NDay + rankbm*Mkt_RF*RES, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*HML*EAD + rankbm*HML*NDay + rankbm*HML*RES, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/Risk.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")

# Month forecast (NB: if I include rankbm*sentM I obtain the same coefficients for the rest)
a[:MonthCategorical] = categorical(a[:ymonth])
m0 = @time reg(a, @model(retM ~ rankbm*sentM_HML +  rankbm*covM_HML + rankbm*EADM + rankbm*covM, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m1 = @time reg(a, @model(retM ~ rankbm*sentM_HML +  rankbm*covM_HML, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m2 = @time reg(a, @model(f1_retM ~ rankbm*sentM_HML +  rankbm*covM_HML, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m3 = @time reg(a, @model(retM ~ rankbm*sentRESM_HML +  rankbm*covM_HML, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m4 = @time reg(a, @model(f1_retM ~ rankbm*sentRESM_HML +  rankbm*covM_HML, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m5 = @time reg(a, @model(retM ~ rankbm*sentM_GRO +  rankbm*covM_GRO + rankbm*sentM_VAL + rankbm*covM_VAL, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
m6 = @time reg(a, @model(f1_retM ~ rankbm*sentM_GRO +  rankbm*covM_GRO + rankbm*sentM_VAL + rankbm*covM_VAL, fe = MonthCategorical, vcov = cluster(MonthCategorical)))
regtable(m0, m1, m2, m3, m4, m5, m6, m7; renderSettings = latexOutput("/home/nicolas/Documents/Engelberg/Monthly.tex"), below_statistic=:tstat,
                         estim_decoration = my_latex_estim_decoration, estimformat="%0.5f")


regtable(m0, m1, m2, m3, m4, m5, m6; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/prov.txt"), below_statistic=:tstat, estimformat="%0.5f")














# OLD
m1 = @time reg(X, @model(Valret ~ EAD*negHML + NDay*negHML + EAD*negHML, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(Valret ~ EAD*negHML + NDay*negVAL + NDay*negGRO + EAD*negVAL + EAD*negGRO, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(Groret ~ EAD*negHML + NDay*negHML + EAD*negHML, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(Groret ~ EAD*negHML + NDay*negVAL + NDay*negGRO + EAD*negVAL + EAD*negGRO, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/prov.txt"), below_statistic=:tstat, estimformat="%0.5f")


m1 = @time reg(X, @model(f1 ~ rankbm*EAD + rankbm*NDay + rankbm*sentHML*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*sentHML*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(l1 ~ rankbm*EAD + rankbm*NDay + rankbm*sentHML*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*l_sHML_1*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m5 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*f_sHML_1*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4, m5; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/prov.txt"), below_statistic=:tstat, estimformat="%0.5f")



m1 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*Mkt_RF*NDay, vcov = cluster(DateCategorical)))
m3 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay + rankbm*Mkt_RF*EAD, fe = DateCategorical, vcov = cluster(DateCategorical)))
m1b = @time reg(X, @model(retadj ~ Val*EAD + Val*NDay + Gro*EAD + Gro*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
#
m2 = @time reg(X, @model(retadj ~ rankbm*EAD + rankbm*NDay
                            + r_l1 + r_l2 + r_l3 + r_l4 + r_l5 + r_l6 + r_l7 + r_l8 + r_l9 + r_l10
                            + r2_l1 + r2_l2 + r2_l3 + r2_l4 + r2_l5 + r2_l6 + r2_l7 + r2_l8 + r2_l9 + r2_l10
                            , fe = DateCategorical, vcov = cluster(DateCategorical)))
#
m3 = @time reg(X, @model(retadj ~ ranksize*EAD + ranksize*NDay, fe = DateCategorical, vcov = cluster(DateCategorical)))
#
m4 = @time reg(X, @model(retadj ~ ranksize*EAD + ranksize*NDay
                            + r_l1 + r_l2 + r_l3 + r_l4 + r_l5 + r_l6 + r_l7 + r_l8 + r_l9 + r_l10
                            + r2_l1 + r2_l2 + r2_l3 + r2_l4 + r2_l5 + r2_l6 + r2_l7 + r2_l8 + r2_l9 + r2_l10
                            , fe = DateCategorical, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3; renderSettings = asciiOutput("/home/nicolas/Documents/Engelberg/prov.txt"), below_statistic=:tstat, estimformat="%0.5f")
regtable(m1; renderSettings = asciiOutput(), below_statistic=:tstat, estimformat="%0.5f",estim_decoration=my_latex_estim_decoration,
                         regressors=["rankbm", "ranksize", "EAD", "NDay", "rankbm & EAD", "ranksize & EAD", "rankbm & NDay", "ranksize & NDay"])

function my_latex_estim_decoration(s::String, pval::Float64)
  if pval<0.0
      error("p value needs to be nonnegative.")
  end
  if (pval > 0.1)
      return "$s"
  elseif (pval > 0.05)
      return "$s\\sym{*}"
  elseif (pval > 0.01)
      return "$s\\sym{**}"
  elseif (pval > 0.001)
      return "$s\\sym{***}"
  else
      return "$s\\sym{***}"
  end
end
