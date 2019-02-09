using DataFrames, Statistics, CSV, StatsBase, Dates, TSmanip, RollingFunctions,
      ShiftedArrays, LoadFF

using PyCall
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")

topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRT", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CMPNY",
          "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "PRES1",
          "REORG", "RES", "RESF", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND"]

retVars = ["permno", "date","retadj", "ranksize", "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100"]
for topic in topics
    push!(retVars,"nS_$(topic)_inc_nov24H_0_rel100")
end
retTypes = [Int64, DateTime, Float64, UInt8, UInt8, Float64, Float64,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8]
retDic = Dict(zip(retVars, [1 for i in retVars]))
nbItems = @time collection[:find](Dict("td"=> Dict("\$gte"=> 1), "gsector"=>Dict("\$ne"=> "40")))[:count]()
cursor = collection[:find](Dict("td"=> Dict("\$gte"=> 1), "gsector"=>Dict("\$ne"=> "40")), retDic)
retDic = Dict(zip(retVars, [Array{Union{T,Missing}}(undef,nbItems) for T in retTypes]))
cc = [0]
sTime = now()
@time for doc in cursor
    cc[1]+=1
    if cc[1] in 1:50000:nbItems
        print("Advancement: $(round(100*cc[1]/nbItems, digits=2))%  -  $(Dates.canonicalize(Dates.CompoundPeriod(now()-sTime))) \n")
    end
    el = Dict(doc)
    for var in retVars
        try
            retDic[var][cc[1]] = el[var]
        catch x
            if typeof(x)==KeyError
                retDic[var][cc[1]] = missing
            else
                print(var)
                print(el[var])
                print(typeof(retDic[var]))
                error(x)
            end
        end
    end
end


retDic[:sent] = (retDic[:posSum_nov24H_0_rel100] .- retDic[:negSum_nov24H_0_rel100]) ./ retDic[:nS_nov24H_0_rel100]

# for k in keys(retDic)
#     print("$k \n")
#     if k in ["permno", "date", "retadj", "sent", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100", "nS_nov24H_0_rel100", "ranksize", "rankbm"]
#         print("=== safe ==== \n")
#     else
#         retDic[k] = (retDic[k] .* 0) .+ 1
#         retDic[k] = convert(Array{Int}, replace(retDic[k], missing=>0))
#     end
# end

# for k in names(retDic)
#     print("$k \n")
#     if k in [:permno]
#         retDic[:permno] = convert(Array{Int}, retDic[:permno])
#     elseif k in [:date]
#         retDic[:date] = convert(Array{DateTime}, retDic[:date])
#     elseif k in [:sent, :posSum_nov24H_0_rel100, :negSum_nov24H_0_rel100, :retadj]
#         retDic[k] = convert(Array{Union{Float64,Missing}}, retDic[k])
#     elseif k in [:nS_nov24H_0_rel100]
#         retDic[k] = convert(Array{Union{Int,Missing}}, retDic[k])
#     else
#         retDic[k] = convert(Array{Int8}, retDic[k])
#     end
# end

sort!(retDic, [:permno, :date])
retDic[:nS_nov24H_0_rel100] = replace(retDic[:nS_nov24H_0_rel100], missing=>0)


using GLM, RegressionTables, CovarianceMatrices, FixedEffectModels, ShiftedArrays
# ols = lm(@formula(retadj ~ sent), retDic)
# vcov(ols, CRHC1(convert(Array{Float64}, retDic[:permno])))
# regtable(ols)


# It doesn't handle negative lags properly as for now
function windowRet(X, win; removeMissing=true, missShortWindows=true)
    X = replace(X,NaN=>missing)
    l = win[1]
    f = win[2]
    res = Union{Missing,Float64}[]
    for i in 1:length(X)
        if i+l<=0 #if the lag puts me too far back
            if missShortWindows
                push!(res,missing)
            elseif i+f<=length(X) && i+f>=1
                push!(res,cumret(X[1:i+f]))
            else
                push!(res,missing)
            end
        elseif i+f>length(X) #forward goes outside range
            if missShortWindows
                push!(res,missing)
            elseif i+l>=0
                if i+l<length(X) && i+l>=1
                    push!(res,cumret(X[i+l:end]))
                else
                    push!(res,missing)
                end
            end
        else
            push!(res,cumret(X[i+l:i+f]))
        end
    end
    return replace(res, NaN=>missing)
end

function windowNS(nsV, sentV, l, f)
    sent = lag(running(sum, replace(sentV, missing=>0), minimum([l, length(sentV)])), f)
    NS = lag(running(sum, replace(nsV, missing=>0), minimum([l, length(nsV)])), f)
    return replace(sent ./ NS, NaN=>missing)
end

function windowSent(nsV, pos, neg, l, f)
    pos = lag(running(sum, replace(pos, missing=>0), minimum([l, length(pos)])), f)
    neg = lag(running(sum, replace(neg, missing=>0), minimum([l, length(neg)])), f)
    NS = lag(running(sum, replace(nsV, missing=>0), minimum([l, length(nsV)])), f)
    return replace((pos .+ neg) ./ NS, NaN=>missing)
end

df = retDic
df[:scaledNeg] = retDic[:negSum_nov24H_0_rel100] ./ retDic[:nS_nov24H_0_rel100]
df[:scaledPos] = retDic[:posSum_nov24H_0_rel100] ./ retDic[:nS_nov24H_0_rel100]
@time a = by(df, :permno) do xdf
    res = Dict()
    # res[:lscaledNeg1] = lag(xdf[:scaledNeg])
    # res[:lscaledNeg2] = lag(xdf[:scaledNeg],2)
    # res[:lscaledNeg3] = lag(xdf[:scaledNeg],3)
    # res[:lscaledNeg4] = lag(xdf[:scaledNeg],4)
    # res[:lscaledNeg5] = lag(xdf[:scaledNeg],5)
    # res[:lscaledNeg6] = lag(xdf[:scaledNeg],6)
    # res[:lretadj1] = lag(xdf[:retadj])
    # res[:lretadj2] = lag(xdf[:retadj],2)
    # res[:lretadj3] = lag(xdf[:retadj],3)
    # res[:lretadj4] = lag(xdf[:retadj],4)
    # res[:lretadj5] = lag(xdf[:retadj],5)
    # res[:lretadj6] = lag(xdf[:retadj],6)
    # res[:fretadj1] = lead(xdf[:retadj])
    # res[:fretadj2] = lead(xdf[:retadj],2)
    # res[:fretadj3] = lead(xdf[:retadj],3)
    # res[:fretadj4] = lead(xdf[:retadj],4)
    # res[:fretadj5] = lead(xdf[:retadj],5)
    # res[:fretadj6] = lead(xdf[:retadj],6)
    # res[:f1_HML] = windowRet(xdf[:HML], (1,1); missShortWindows=false)
    # res[:f1_SMB] = windowRet(xdf[:SMB], (1,1); missShortWindows=false)
    # res[:f1_Mom] = windowRet(xdf[:Mom], (1,1); missShortWindows=false)
    # res[:f1_Mkt_RF] = windowRet(xdf[:Mkt_RF], (1,1); missShortWindows=false)
    # res[:f1_f5_HML] = windowRet(xdf[:HML], (1,5); missShortWindows=false)
    # res[:f1_f5_SMB] = windowRet(xdf[:SMB], (1,5); missShortWindows=false)
    # res[:f1_f5_Mom] = windowRet(xdf[:Mom], (1,5); missShortWindows=false)
    # res[:f1_f5_Mkt_RF] = windowRet(xdf[:Mkt_RF], (1,5); missShortWindows=false)
    # res[:f5_f10_HML] = windowRet(xdf[:HML], (5,10); missShortWindows=false)
    # res[:f5_f10_SMB] = windowRet(xdf[:SMB], (5,10); missShortWindows=false)
    # res[:f5_f10_Mom] = windowRet(xdf[:Mom], (5,10); missShortWindows=false)
    # res[:f5_f10_Mkt_RF] = windowRet(xdf[:Mkt_RF], (5,10); missShortWindows=false)
    # res[:f10_f20_HML] = windowRet(xdf[:HML], (10,20); missShortWindows=false)
    # res[:f10_f20_SMB] = windowRet(xdf[:SMB], (10,20); missShortWindows=false)
    # res[:f10_f20_Mom] = windowRet(xdf[:Mom], (10,20); missShortWindows=false)
    # res[:f10_f20_Mkt_RF] = windowRet(xdf[:Mkt_RF], (10,20); missShortWindows=false)
    # res[:f20_f60_HML] = windowRet(xdf[:HML], (20,60); missShortWindows=false)
    # res[:f20_f60_SMB] = windowRet(xdf[:SMB], (20,60); missShortWindows=false)
    # res[:f20_f60_Mom] = windowRet(xdf[:Mom], (20,60); missShortWindows=false)
    # res[:f20_f60_Mkt_RF] = windowRet(xdf[:Mkt_RF], (20,60); missShortWindows=false)
    # res[:f60_f120_HML] = windowRet(xdf[:HML], (60,120); missShortWindows=false)
    # res[:f60_f120_SMB] = windowRet(xdf[:SMB], (60,120); missShortWindows=false)
    # res[:f60_f120_Mom] = windowRet(xdf[:Mom], (60,120); missShortWindows=false)
    # res[:f60_f120_Mkt_RF] = windowRet(xdf[:Mkt_RF], (60,120); missShortWindows=false)
    # res[:f120_f240_HML] = windowRet(xdf[:HML], (120,240); missShortWindows=false)
    # res[:f120_f240_SMB] = windowRet(xdf[:SMB], (120,240); missShortWindows=false)
    # res[:f120_f240_Mom] = windowRet(xdf[:Mom], (120,240); missShortWindows=false)
    # res[:f120_f240_Mkt_RF] = windowRet(xdf[:Mkt_RF], (120,240); missShortWindows=false)
    # res[:l1_f0] = windowRet(xdf[:retadj], (-1,0); missShortWindows=false)
    # res[:l1_f1] = windowRet(xdf[:retadj], (-1,1); missShortWindows=false)
    # res[:l0_f2] = windowRet(xdf[:retadj], (0,2); missShortWindows=false)
    # res[:f1_f2] = windowRet(xdf[:retadj], (1,2); missShortWindows=false)
    # res[:f1_f3] = windowRet(xdf[:retadj], (1,3); missShortWindows=false)
    # res[:f1_f4] = windowRet(xdf[:retadj], (1,4); missShortWindows=false)
    # res[:f1_f5] = windowRet(xdf[:retadj], (1,5); missShortWindows=false)
    # res[:f2_f5] = windowRet(xdf[:retadj], (2,5); missShortWindows=false)
    # res[:f3_f5] = windowRet(xdf[:retadj], (3,5); missShortWindows=false)
    # res[:f5_f10] = windowRet(xdf[:retadj], (5,10); missShortWindows=false)
    # res[:f10_f20] = windowRet(xdf[:retadj], (10,20); missShortWindows=false)
    # res[:f1_f20] = windowRet(xdf[:retadj], (1,20); missShortWindows=false)
    # res[:f1_f40] = windowRet(xdf[:retadj], (1,40); missShortWindows=false)
    # res[:f20_f40] = windowRet(xdf[:retadj], (20,40); missShortWindows=false)
    # res[:f1_f60] = windowRet(xdf[:retadj], (1,60); missShortWindows=false)
    # res[:f40_f60] = windowRet(xdf[:retadj], (40,60); missShortWindows=false)
    # res[:f20_f60] = windowRet(xdf[:retadj], (20,60); missShortWindows=false)
    # res[:f60_f80] = windowRet(xdf[:retadj], (60,80); missShortWindows=false)
    # res[:f60_f120] = windowRet(xdf[:retadj], (60,120); missShortWindows=false)
    # res[:f120_f240] = windowRet(xdf[:retadj], (120,240); missShortWindows=false)
    # res[:f240_f480] = windowRet(xdf[:retadj], (240,480); missShortWindows=false)
    # res[:f0_f1] = windowRet(xdf[:retadj], (0,1); missShortWindows=false)
    # res[:f1] = windowRet(xdf[:retadj], (1,1); missShortWindows=false)
    # res[:f2] = windowRet(xdf[:retadj], (2,2); missShortWindows=false)
    # res[:l2] = windowRet(xdf[:retadj], (-2,-2); missShortWindows=false)
    # res[:l1] = windowRet(xdf[:retadj], (-1,-1); missShortWindows=false)
    # res[:l2_l1] = windowRet(xdf[:retadj], (-2,-1); missShortWindows=false)
    # res[:l5_l1] = windowRet(xdf[:retadj], (-5,-1); missShortWindows=false)
    # res[:l5_l3] = windowRet(xdf[:retadj], (-5,-3); missShortWindows=false)
    # res[:l10_l1] = windowRet(xdf[:retadj], (-10,-1); missShortWindows=false)
    # res[:l10_l5] = windowRet(xdf[:retadj], (-10,-5); missShortWindows=false)
    # res[:neg_f1] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,1)
    # res[:neg_f2] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,2)
    # res[:neg_f3] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,3)
    # res[:neg_f1_f5] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 4,5)
    # res[:neg_f1_f20] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 19,20)
    # res[:neg_f5_f20] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 15,20)
    # res[:neg_f20_f40] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 20,40)# Focus on neg/pos
    #
    # res[:neg_f40_60] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 20,60)
    # res[:neg_f60_120] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 60,120)
    # res[:neg_f120_240] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 120,240)
    # res[:pos_f1] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 1,1)
    # res[:pos_f2] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 1,2)
    # res[:pos_f3] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 1,3)
    # res[:pos_f1_f5] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 4,5)
    # res[:pos_f1_f20] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 19,20)
    # res[:pos_f5_f20] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 15,20)
    # res[:pos_f20_f40] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 20,40)
    # res[:pos_f40_60] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 20,60)
    # res[:pos_f60_120] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 60,120)
    # res[:pos_f120_240] = windowNS(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], 120,240)
    # res[:sent_f1] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,1)
    # res[:sent_f2] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,2)
    # res[:sent_f3] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 1,3)
    # res[:sent_f1_f5] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 4,5)
    # res[:sent_f1_f20] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 19,20)
    # res[:sent_f5_f20] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 15,20)
    # res[:sent_f20_f40] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 20,40)
    # res[:sent_f40_60] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 20,60)
    # res[:sent_f60_120] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 60,120)
    # res[:sent_f120_240] = windowSent(xdf[:nS_nov24H_0_rel100], xdf[:posSum_nov24H_0_rel100], xdf[:negSum_nov24H_0_rel100], 120,240)
    res[:date] = xdf[:date]
    DataFrame(res)
end
sort!(a, [:permno,:date])
deletecols!(a, [:permno, :date])
df = hcat(df, a)

for k in names(df)
    if occursin("_inc_nov24H_0_rel100", String(k))
        rename!(df, k=>Symbol(split(String(k), "_")[2]))
    end
end



#### Pos days vs neg days
df[:scaledNeut] = 1 .- df[:scaledPos] .- df[:scaledNeg]
df[:negDay] = 0
df[:neutDay] = 0
df[:posDay] = 0
for row in 1:size(df,1)
    if !ismissing(df[row, :scaledPos])
        if df[row, :scaledNeut] > df[row, :scaledPos] && df[row, :scaledNeut] > df[row, :scaledNeg]
            df[row, :neutDay] = 1
        elseif df[row, :scaledPos] > df[row, :scaledNeut] && df[row, :scaledPos] > df[row, :scaledNeg]
            df[row, :posDay] = 1
        elseif df[row, :scaledNeg] > df[row, :scaledNeut] && df[row, :scaledNeg] > df[row, :scaledPos]
            df[row, :negDay] = 1
        end
    end
end

df[:newNeg] = Array{Union{Float64,Missing}}(undef,size(df,1))
df[:newPos] = Array{Union{Float64,Missing}}(undef,size(df,1))
for row in 1:size(df,1)
    if df[row, :posDay]==1
        df[row, :newPos] = df[row, :scaledPos]
    elseif df[row, :negDay]==1
        df[row, :newNeg] = df[row, :scaledNeg]
    end
end


#### Standardize variables
df[:year] = Dates.year.(df[:date])
@time a = by(df, :year) do xdf
    res = Dict()
    res[:yearmean_scaledPos] = mean(skipmissing(xdf[:scaledPos]))
    res[:yearstd_scaledPos] = std(skipmissing(xdf[:scaledPos]))
    res[:yearmean_scaledNeg] = mean(skipmissing(xdf[:scaledNeg]))
    res[:yearstd_scaledNeg] = std(skipmissing(xdf[:scaledNeg]))
    res[:yearmean_newPos] = mean(skipmissing(xdf[:newPos]))
    res[:yearstd_newPos] = std(skipmissing(xdf[:newPos]))
    res[:yearmean_newNeg] = mean(skipmissing(xdf[:newNeg]))
    res[:yearstd_newNeg] = std(skipmissing(xdf[:newNeg]))
    res[:yeargoodnews] = sum(xdf[:posDay])
    res[:yearbadnews] = sum(xdf[:negDay])
    DataFrame(res)
end

df = join(df, a, on=:year, kind=:left)
df[:stand_scaledNeg] = (df[:scaledNeg] .- df[:yearmean_scaledNeg]) ./ df[:yearstd_scaledNeg]
df[:stand_scaledPos] = (df[:scaledPos] .- df[:yearmean_scaledPos]) ./ df[:yearstd_scaledPos]
df[:stand_newNeg] = (df[:newNeg] .- df[:yearmean_newNeg]) ./ df[:yearstd_newNeg]
df[:stand_newPos] = (df[:newPos] .- df[:yearmean_newPos]) ./ df[:yearstd_newPos]

#### Add risk factors
FF = FFfactors()
df[:Date] = Date.(df[:date])
df = join(df, FF[[:Date, :SMB, :HML, :Mom, :Mkt_RF]], on=:Date, kind=:left)

#### Pos /neg days by topic
resdic = [Dict(x=>[0,0]) for x in Symbol.(topics)]
for row in 1:size(df,1)
    if df[row,:posDay]==1
        for i in 1:length(resdic)
            k = collect(keys(resdic[i]))[1]
            if df[row,k]>1
                resdic[i][k][1]+=1
            end
        end
    elseif df[row,:negDay]==1
        for i in 1:length(resdic)
            k = collect(keys(resdic[i]))[1]
            if df[row,k]>1
                resdic[i][k][2]+=1
            end
        end
    end
end

poscounts = []
for dic in resdic
    print(collect(values(dic)))
    push!(poscounts, collect(values(dic))[1][1])
end
negcounts = []
for dic in resdic
    print(values(dic))
    push!(negcounts, collect(values(dic))[1][2])
end
topcounts = DataFrame(hcat(poscounts, negcounts))
topcounts[:topic] = Symbol.(topics)
names!(topcounts, [:poscount, :negcount, :topic])
using CSV
CSV.write("/home/nicolas/Documents/Paper Denada/posnegtopiccounts.csv", topcounts)

#### topic zeros
for col in names(df)
    if col in [Symbol(x) for x in topics]
        df[col] = replace(df[col], missing=>0)
    end
end

####

df[:DateCategorical] = categorical(df[:date])
df[:StockCategorical] = categorical(df[:permno])

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

# copydf = copy(df)
# df = copydf[replace(copydf[:ranksize], missing=>NaN).<=8,:]
# df = copydf
# subdata = "ALL"
# df[:DateCategorical] = categorical(df[:date])
# df[:StockCategorical] = categorical(df[:permno])




# Replicate simple Ahmad et al
# Add lagged returns (+news?)
# Forecast news the same way I forecast returns
# Focus on neg/pos
# Anterior returns impact


m1 = @time reg(df, @model(f1_f2 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ sent + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_interact_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)











#
m1 = @time reg(df, @model(f1_f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_interact_permnoFE_clusterDate_onlyinter.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ sent + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent&RES + sent&RESF + sent&CMPNY + sent&BACT + sent&MRG + sent&DEAL1 + sent&MNGISS + sent&DIV
                                  + sent&AAA + sent&FINE1 + sent&BOSS1 + sent&IPO + sent&STAT + sent&BUYB + sent&ALLCE + sent&DVST
                                  + sent&SISU + sent&REORG + sent&CPROD + sent&STK + sent&CASE1 + sent&BKRT + sent&MONOP + sent&CLASS
                                  + sent&CFO1 + sent&MEET1 + sent&CEO1 + sent&SHRACT + sent&LIST1 + sent&LAYOFS + sent&DBTR + sent&FIND1
                                  + sent&DDEAL + sent&SPLITB + sent&CHAIR1 + sent&ACCI + sent&HOSAL + sent&XPAND + sent&PRES1 + sent&RECLL
                                  + sent&SL1 + sent&PRIV + sent&NAMEC + sent&CORGOV + sent&CNSL + sent&BONS + sent&BKRFIG + sent&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_interact_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)








































####### interact * level ##############
m1 = @time reg(df, @model(f1_f2 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ sent + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_levelinteract_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)















#
m1 = @time reg(df, @model(f1_f2 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ sent + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_levelinteract_permnoFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ sent + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ sent + retadj + lretadj1 + lretadj2 + lretadj3 +  sent*RES + sent*RESF + sent*CMPNY + sent*BACT + sent*MRG + sent*DEAL1 + sent*MNGISS + sent*DIV
                                  + sent*AAA + sent*FINE1 + sent*BOSS1 + sent*IPO + sent*STAT + sent*BUYB + sent*ALLCE + sent*DVST
                                  + sent*SISU + sent*REORG + sent*CPROD + sent*STK + sent*CASE1 + sent*BKRT + sent*MONOP + sent*CLASS
                                  + sent*CFO1 + sent*MEET1 + sent*CEO1 + sent*SHRACT + sent*LIST1 + sent*LAYOFS + sent*DBTR + sent*FIND1
                                  + sent*DDEAL + sent*SPLITB + sent*CHAIR1 + sent*ACCI + sent*HOSAL + sent*XPAND + sent*PRES1 + sent*RECLL
                                  + sent*SL1 + sent*PRIV + sent*NAMEC + sent*CORGOV + sent*CNSL + sent*BONS + sent*BKRFIG + sent*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_levelinteract_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)






























































####################### Scaled neg #######################
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_interact_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)














#
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_interact_permnoFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg&RES + scaledNeg&RESF + scaledNeg&CMPNY + scaledNeg&BACT + scaledNeg&MRG + scaledNeg&DEAL1 + scaledNeg&MNGISS + scaledNeg&DIV
                                  + scaledNeg&AAA + scaledNeg&FINE1 + scaledNeg&BOSS1 + scaledNeg&IPO + scaledNeg&STAT + scaledNeg&BUYB + scaledNeg&ALLCE + scaledNeg&DVST
                                  + scaledNeg&SISU + scaledNeg&REORG + scaledNeg&CPROD + scaledNeg&STK + scaledNeg&CASE1 + scaledNeg&BKRT + scaledNeg&MONOP + scaledNeg&CLASS
                                  + scaledNeg&CFO1 + scaledNeg&MEET1 + scaledNeg&CEO1 + scaledNeg&SHRACT + scaledNeg&LIST1 + scaledNeg&LAYOFS + scaledNeg&DBTR + scaledNeg&FIND1
                                  + scaledNeg&DDEAL + scaledNeg&SPLITB + scaledNeg&CHAIR1 + scaledNeg&ACCI + scaledNeg&HOSAL + scaledNeg&XPAND + scaledNeg&PRES1 + scaledNeg&RECLL
                                  + scaledNeg&SL1 + scaledNeg&PRIV + scaledNeg&NAMEC + scaledNeg&CORGOV + scaledNeg&CNSL + scaledNeg&BONS + scaledNeg&BKRFIG + scaledNeg&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_interact_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)








































####### interact * level ##############
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_levelinteract_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)















#
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_levelinteract_permnoFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledNeg + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  + scaledNeg*SL1 + scaledNeg*PRIV + scaledNeg*NAMEC + scaledNeg*CORGOV + scaledNeg*CNSL + scaledNeg*BONS + scaledNeg*BKRFIG + scaledNeg*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_neg_levelinteract_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)



















































































#
####################### Scaled pos #######################
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_interact_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)














#
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_interact_permnoFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos&RES + scaledPos&RESF + scaledPos&CMPNY + scaledPos&BACT + scaledPos&MRG + scaledPos&DEAL1 + scaledPos&MNGISS + scaledPos&DIV
                                  + scaledPos&AAA + scaledPos&FINE1 + scaledPos&BOSS1 + scaledPos&IPO + scaledPos&STAT + scaledPos&BUYB + scaledPos&ALLCE + scaledPos&DVST
                                  + scaledPos&SISU + scaledPos&REORG + scaledPos&CPROD + scaledPos&STK + scaledPos&CASE1 + scaledPos&BKRT + scaledPos&MONOP + scaledPos&CLASS
                                  + scaledPos&CFO1 + scaledPos&MEET1 + scaledPos&CEO1 + scaledPos&SHRACT + scaledPos&LIST1 + scaledPos&LAYOFS + scaledPos&DBTR + scaledPos&FIND1
                                  + scaledPos&DDEAL + scaledPos&SPLITB + scaledPos&CHAIR1 + scaledPos&ACCI + scaledPos&HOSAL + scaledPos&XPAND + scaledPos&PRES1 + scaledPos&RECLL
                                  + scaledPos&SL1 + scaledPos&PRIV + scaledPos&NAMEC + scaledPos&CORGOV + scaledPos&CNSL + scaledPos&BONS + scaledPos&BKRFIG + scaledPos&CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_interact_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)








































####### interact * level ##############
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical)))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_levelinteract_noFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)















#
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_levelinteract_permnoFE_clusterDate.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




















#
#
m1 = @time reg(df, @model(f1_f2 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
m2 = @time reg(df, @model(retadj ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f3 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m4 = @time reg(df, @model(f1_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m5 = @time reg(df, @model(f3_f5 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m6 = @time reg(df, @model(f5_f10 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m7 = @time reg(df, @model(f10_f20 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m8 = @time reg(df, @model(f20_f40 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f80 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m12 = @time reg(df, @model(f60_f120 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#
m13 = @time reg(df, @model(f120_f240 ~ scaledPos + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                  + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                  + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                  + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                  + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                  + scaledPos*SL1 + scaledPos*PRIV + scaledPos*NAMEC + scaledPos*CORGOV + scaledPos*CNSL + scaledPos*BONS + scaledPos*BKRFIG + scaledPos*CM1 ,
                                    vcov = robust, fe = StockCategorical))
#



regtable(m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/$(subdata)_pos_levelinteract_permnoFE_robustErrors.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)





















# Replicate simple Ahmad et al
# Add lagged returns (+news?)
# Forecast news the same way I forecast returns
# Focus on neg/pos
# Anterior returns impact
df = copydf[replace(copydf[:ranksize], missing=>NaN).>=9,:]
subdata = "BigQuintile"
################################################################################
############################### Final Tables   #################################
################################################################################

l1 = @time reg(df, @model(l10_l5 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l2 = @time reg(df, @model(l10_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l3 = @time reg(df, @model(l5_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l4 = @time reg(df, @model(l2_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l5 = @time reg(df, @model(l2 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l6 = @time reg(df, @model(l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
####
m1 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(f1 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f1_f3 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f1_f5 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f5_f10 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f10_f20 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f40 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f120 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f120_f240 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f240_f480 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL
                                  ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#


regtable(l1,l2,l3,l4,l5,l6, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/scaledNeg_$(subdata)_interact_permnoFE_clusterDate_onlyinter.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)




###################### Sent forecast ###############################
#
l1 = @time reg(df, @model(neg_f1 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l2 = @time reg(df, @model(neg_f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l3 = @time reg(df, @model(neg_f3 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l4 = @time reg(df, @model(neg_f1_f5 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l5 = @time reg(df, @model(neg_f1_f20 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l6 = @time reg(df, @model(neg_f5_f20 ~ retadj + lretadj1 + lretadj2 + lretadj3 + scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
####
m1 = @time reg(df, @model(neg_f20_f40 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(neg_f40_60 ~  retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(neg_f60_120 ~  retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(neg_f120_240 ~  retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))

regtable(l1,l2,l3,l4,l5,l6, m1, m2, m3, m4; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/neg_forecsat_$(subdata)_interact_permnoFE_clusterDate_onlyinter.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)








#####################  Pos Neg simulatenously forecasts ########################
l1 = @time reg(df, @model(l10_l5 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l2 = @time reg(df, @model(l10_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l3 = @time reg(df, @model(l5_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l4 = @time reg(df, @model(l2_l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l5 = @time reg(df, @model(l2 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
l6 = @time reg(df, @model(l1 ~ scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
####
m1 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
m2 = @time reg(df, @model(f1 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m3 = @time reg(df, @model(f1_f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m4 = @time reg(df, @model(f2 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m5 = @time reg(df, @model(f1_f3 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m6 = @time reg(df, @model(f1_f5 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m7 = @time reg(df, @model(f5_f10 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m8 = @time reg(df, @model(f10_f20 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m9 = @time reg(df, @model(f20_f40 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m10 = @time reg(df, @model(f40_f60 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m11 = @time reg(df, @model(f60_f120 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m12 = @time reg(df, @model(f120_f240 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#
m13 = @time reg(df, @model(f240_f480 ~ retadj + lretadj1 + lretadj2 + lretadj3 +  scaledNeg*RES + scaledNeg*RESF + scaledNeg*CMPNY + scaledNeg*BACT + scaledNeg*MRG + scaledNeg*DEAL1 + scaledNeg*MNGISS + scaledNeg*DIV
                                  + scaledNeg*AAA + scaledNeg*FINE1 + scaledNeg*BOSS1 + scaledNeg*IPO + scaledNeg*STAT + scaledNeg*BUYB + scaledNeg*ALLCE + scaledNeg*DVST
                                  + scaledNeg*SISU + scaledNeg*REORG + scaledNeg*CPROD + scaledNeg*STK + scaledNeg*CASE1 + scaledNeg*BKRT + scaledNeg*MONOP + scaledNeg*CLASS
                                  + scaledNeg*CFO1 + scaledNeg*MEET1 + scaledNeg*CEO1 + scaledNeg*SHRACT + scaledNeg*LIST1 + scaledNeg*LAYOFS + scaledNeg*DBTR + scaledNeg*FIND1
                                  + scaledNeg*DDEAL + scaledNeg*SPLITB + scaledNeg*CHAIR1 + scaledNeg*ACCI + scaledNeg*HOSAL + scaledNeg*XPAND + scaledNeg*PRES1 + scaledNeg*RECLL

                                  + scaledPos*RES + scaledPos*RESF + scaledPos*CMPNY + scaledPos*BACT + scaledPos*MRG + scaledPos*DEAL1 + scaledPos*MNGISS + scaledPos*DIV
                                                                    + scaledPos*AAA + scaledPos*FINE1 + scaledPos*BOSS1 + scaledPos*IPO + scaledPos*STAT + scaledPos*BUYB + scaledPos*ALLCE + scaledPos*DVST
                                                                    + scaledPos*SISU + scaledPos*REORG + scaledPos*CPROD + scaledPos*STK + scaledPos*CASE1 + scaledPos*BKRT + scaledPos*MONOP + scaledPos*CLASS
                                                                    + scaledPos*CFO1 + scaledPos*MEET1 + scaledPos*CEO1 + scaledPos*SHRACT + scaledPos*LIST1 + scaledPos*LAYOFS + scaledPos*DBTR + scaledPos*FIND1
                                                                    + scaledPos*DDEAL + scaledPos*SPLITB + scaledPos*CHAIR1 + scaledPos*ACCI + scaledPos*HOSAL + scaledPos*XPAND + scaledPos*PRES1 + scaledPos*RECLL
                                                                    ,
                                    vcov = cluster(DateCategorical), fe = StockCategorical))
#


regtable(l1,l2,l3,l4,l5,l6, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/PosNeg_$(subdata)_interact_permnoFE_clusterDate_onlyinter.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)







#stand_newNeg, stand_scaledNeg
topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRT", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CMPNY",
          "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "PRES1",
          "REORG", "RES", "RESF", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND"]

m1 = @time reg(df, @model(f1 ~ lretadj1 + lretadj2 + lretadj3
        + stand_scaledNeg*CMPNY + stand_scaledNeg*BACT + stand_scaledNeg*RES + stand_scaledNeg*RESF
        + stand_scaledNeg*MRG + stand_scaledNeg*MNGISS + stand_scaledNeg*DEAL1 + stand_scaledNeg*DIV,
        vcov = cluster(DateCategorical), fe = StockCategorical))

#
df[:l10_l5] = df[:l10_l5] .* 100
df[:l5_l3] = df[:l5_l3] .* 100
df[:l2] = df[:l2] .* 100
df[:l1] = df[:l1] .* 100
df[:retadj] = df[:retadj] .* 100
df[:f1] = df[:f1] .* 100
df[:f1_f5] = df[:f1_f5] .* 100
df[:f2_f5] = df[:f2_f5] .* 100
df[:f5_f10] = df[:f5_f10] .* 100
df[:f10_f20] = df[:f10_f20] .* 100
df[:f20_f60] = df[:f20_f60] .* 100
df[:f60_f120] = df[:f60_f120] .* 100
df[:f120_f240] = df[:f120_f240] .* 100

l4 = @time reg(df, @model(l10_l5 ~ stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#

l3 = @time reg(df, @model(l5_l3 ~ stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))


#
l2 = @time reg(df, @model(l2 ~ lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#
l1 = @time reg(df, @model(l1 ~ lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#
m1 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m2 = @time reg(df, @model(f1 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m2bis = @time reg(df, @model(f1_f5 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#

m3 = @time reg(df, @model(f2_f5 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m4 = @time reg(df, @model(f5_f10 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m5 = @time reg(df, @model(f10_f20 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m6 = @time reg(df, @model(f20_f60 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m7 = @time reg(df, @model(f60_f120 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m8 = @time reg(df, @model(f120_f240 ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
regtable(l4, l3, l2, l1, m1, m2bis, m2, m3, m4, m5, m6, m7, m8; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/New/DayFE_Stand_PosNeg_revised.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)


#### Non -standardized ####
l4 = @time reg(df, @model(l10_l5 ~ scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#

l3 = @time reg(df, @model(l5_l3 ~ scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))


#
l2 = @time reg(df, @model(l2 ~ lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#
l1 = @time reg(df, @model(l1 ~ lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))

#
m1 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m2 = @time reg(df, @model(f1 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m3 = @time reg(df, @model(f2_f5 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m4 = @time reg(df, @model(f5_f10 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m5 = @time reg(df, @model(f10_f20 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m6 = @time reg(df, @model(f20_f60 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m7 = @time reg(df, @model(f60_f120 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
m8 = @time reg(df, @model(f120_f240 ~ lretadj1 + lretadj2 + lretadj3 + scaledPos + scaledNeg
        + CMPNY + scaledNeg&CMPNY&negDay + BACT + scaledNeg&BACT&negDay
        + RES + scaledNeg&RES&negDay + RESF + scaledNeg&RESF&negDay
        + MRG + scaledNeg&MRG&negDay + MNGISS + scaledNeg&MNGISS&negDay
        + DEAL1 + scaledNeg&DEAL1&negDay + DIV + scaledNeg&DIV&negDay
        + AAA + scaledNeg&AAA&negDay + FINE1 + scaledNeg&FINE1&negDay
        + BOSS1 + scaledNeg&BOSS1&negDay + IPO + scaledNeg&IPO&negDay
        + STAT + scaledNeg&STAT&negDay + BUYB + scaledNeg&BUYB&negDay
        + ALLCE + scaledNeg&ALLCE&negDay + DVST + scaledNeg&DVST&negDay
        + SISU + scaledNeg&SISU&negDay + REORG + scaledNeg&REORG&negDay
        + CPROD + scaledNeg&CPROD&negDay + STK + scaledNeg&STK&negDay
        + CASE1 + scaledNeg&CASE1&negDay + BKRT + scaledNeg&BKRT&negDay
        + MONOP + scaledNeg&MONOP&negDay + CLASS + scaledNeg&CLASS&negDay
        + CFO1 + scaledNeg&CFO1&negDay + MEET1 + scaledNeg&MEET1&negDay
        + CEO1 + scaledNeg&CEO1&negDay + SHRACT + scaledNeg&SHRACT&negDay
        + LIST1 + scaledNeg&LIST1&negDay + LAYOFS + scaledNeg&LAYOFS&negDay
        + DBTR + scaledNeg&DBTR&negDay
        + DDEAL + scaledNeg&DDEAL&negDay + SPLITB + scaledNeg&SPLITB&negDay
        + CHAIR1 + scaledNeg&CHAIR1&negDay + ACCI + scaledNeg&ACCI&negDay
        + HOSAL + scaledNeg&HOSAL&negDay + XPAND + scaledNeg&XPAND&negDay

        + CMPNY + scaledPos&CMPNY&posDay + BACT + scaledPos&BACT&posDay
        + RES + scaledPos&RES&posDay + RESF + scaledPos&RESF&posDay
        + MRG + scaledPos&MRG&posDay + MNGISS + scaledPos&MNGISS&posDay
        + DEAL1 + scaledPos&DEAL1&posDay + DIV + scaledPos&DIV&posDay
        + AAA + scaledPos&AAA&posDay + FINE1 + scaledPos&FINE1&posDay
        + BOSS1 + scaledPos&BOSS1&posDay + IPO + scaledPos&IPO&posDay
        + STAT + scaledPos&STAT&posDay + BUYB + scaledPos&BUYB&posDay
        + ALLCE + scaledPos&ALLCE&posDay + DVST + scaledPos&DVST&posDay
        + SISU + scaledPos&SISU&posDay + REORG + scaledPos&REORG&posDay
        + CPROD + scaledPos&CPROD&posDay + STK + scaledPos&STK&posDay
        + CASE1 + scaledPos&CASE1&posDay + BKRT + scaledPos&BKRT&posDay
        + MONOP + scaledPos&MONOP&posDay + CLASS + scaledPos&CLASS&posDay
        + CFO1 + scaledPos&CFO1&posDay + MEET1 + scaledPos&MEET1&posDay
        + CEO1 + scaledPos&CEO1&posDay + SHRACT + scaledPos&SHRACT&posDay
        + LIST1 + scaledPos&LIST1&posDay + LAYOFS + scaledPos&LAYOFS&posDay
        + DBTR + scaledPos&DBTR&posDay
        + DDEAL + scaledPos&DDEAL&posDay + SPLITB + scaledPos&SPLITB&posDay
        + CHAIR1 + scaledPos&CHAIR1&posDay + ACCI + scaledPos&ACCI&posDay
        + HOSAL + scaledPos&HOSAL&posDay + XPAND + scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical + DateCategorical))
#
regtable(l4, l3, l2, l1, m1, m2, m3, m4, m5, m6, m7, m8; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/New/DayFE_raw_PosNeg.txt"),
                below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)
sum(df[:neutDay]) + 729071 + 264615

##### Factor controls ####
m1 = @time reg(df, @model(retadj ~ lretadj1 + lretadj2 + lretadj3 + stand_scaledPos + stand_scaledNeg
        + Mkt_RF + SMB + HML + Mom
        + CMPNY + stand_scaledNeg&CMPNY&negDay + BACT + stand_scaledNeg&BACT&negDay
        + RES + stand_scaledNeg&RES&negDay + RESF + stand_scaledNeg&RESF&negDay
        + MRG + stand_scaledNeg&MRG&negDay + MNGISS + stand_scaledNeg&MNGISS&negDay
        + DEAL1 + stand_scaledNeg&DEAL1&negDay + DIV + stand_scaledNeg&DIV&negDay
        + AAA + stand_scaledNeg&AAA&negDay + FINE1 + stand_scaledNeg&FINE1&negDay
        + BOSS1 + stand_scaledNeg&BOSS1&negDay + IPO + stand_scaledNeg&IPO&negDay
        + STAT + stand_scaledNeg&STAT&negDay + BUYB + stand_scaledNeg&BUYB&negDay
        + ALLCE + stand_scaledNeg&ALLCE&negDay + DVST + stand_scaledNeg&DVST&negDay
        + SISU + stand_scaledNeg&SISU&negDay + REORG + stand_scaledNeg&REORG&negDay
        + CPROD + stand_scaledNeg&CPROD&negDay + STK + stand_scaledNeg&STK&negDay
        + CASE1 + stand_scaledNeg&CASE1&negDay + BKRT + stand_scaledNeg&BKRT&negDay
        + MONOP + stand_scaledNeg&MONOP&negDay + CLASS + stand_scaledNeg&CLASS&negDay
        + CFO1 + stand_scaledNeg&CFO1&negDay + MEET1 + stand_scaledNeg&MEET1&negDay
        + CEO1 + stand_scaledNeg&CEO1&negDay + SHRACT + stand_scaledNeg&SHRACT&negDay
        + LIST1 + stand_scaledNeg&LIST1&negDay + LAYOFS + stand_scaledNeg&LAYOFS&negDay
        + DBTR + stand_scaledNeg&DBTR&negDay
        + DDEAL + stand_scaledNeg&DDEAL&negDay + SPLITB + stand_scaledNeg&SPLITB&negDay
        + CHAIR1 + stand_scaledNeg&CHAIR1&negDay + ACCI + stand_scaledNeg&ACCI&negDay
        + HOSAL + stand_scaledNeg&HOSAL&negDay + XPAND + stand_scaledNeg&XPAND&negDay

        + CMPNY + stand_scaledPos&CMPNY&posDay + BACT + stand_scaledPos&BACT&posDay
        + RES + stand_scaledPos&RES&posDay + RESF + stand_scaledPos&RESF&posDay
        + MRG + stand_scaledPos&MRG&posDay + MNGISS + stand_scaledPos&MNGISS&posDay
        + DEAL1 + stand_scaledPos&DEAL1&posDay + DIV + stand_scaledPos&DIV&posDay
        + AAA + stand_scaledPos&AAA&posDay + FINE1 + stand_scaledPos&FINE1&posDay
        + BOSS1 + stand_scaledPos&BOSS1&posDay + IPO + stand_scaledPos&IPO&posDay
        + STAT + stand_scaledPos&STAT&posDay + BUYB + stand_scaledPos&BUYB&posDay
        + ALLCE + stand_scaledPos&ALLCE&posDay + DVST + stand_scaledPos&DVST&posDay
        + SISU + stand_scaledPos&SISU&posDay + REORG + stand_scaledPos&REORG&posDay
        + CPROD + stand_scaledPos&CPROD&posDay + STK + stand_scaledPos&STK&posDay
        + CASE1 + stand_scaledPos&CASE1&posDay + BKRT + stand_scaledPos&BKRT&posDay
        + MONOP + stand_scaledPos&MONOP&posDay + CLASS + stand_scaledPos&CLASS&posDay
        + CFO1 + stand_scaledPos&CFO1&posDay + MEET1 + stand_scaledPos&MEET1&posDay
        + CEO1 + stand_scaledPos&CEO1&posDay + SHRACT + stand_scaledPos&SHRACT&posDay
        + LIST1 + stand_scaledPos&LIST1&posDay + LAYOFS + stand_scaledPos&LAYOFS&posDay
        + DBTR + stand_scaledPos&DBTR&posDay
        + DDEAL + stand_scaledPos&DDEAL&posDay + SPLITB + stand_scaledPos&SPLITB&posDay
        + CHAIR1 + stand_scaledPos&CHAIR1&posDay + ACCI + stand_scaledPos&ACCI&posDay
        + HOSAL + stand_scaledPos&HOSAL&posDay + XPAND + stand_scaledPos&XPAND&posDay
        , vcov = cluster(DateCategorical), fe = StockCategorical))
regtable(m1; renderSettings = asciiOutput("/home/nicolas/Documents/Paper Denada/Regressions/New/Factorcontrols_stand_PosNeg.txt"),
            below_statistic=:tstat, estim_decoration = my_latex_estim_decoration)

# Compute cumulative abnormal returns
