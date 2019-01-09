using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2,
      TSmap, Plots, CSV, TrendCycle, Misc, FindFcts

iArrays = [Int[], DateTime[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
vars = ["permno", "date", "me", "nS_nov12H_0", "posSum_nov12H_0", "negSum_nov12H_0",
        "nS_RES_inc_RESF_excl_nov12H_0", "posSum_RES_inc_RESF_excl_nov12H_0", "negSum_RES_inc_RESF_excl_nov12H_0",
        "nS_RESF_inc_nov12H_0", "posSum_RESF_inc_nov12H_0", "negSum_RESF_inc_nov12H_0"]
NSMat = @time gatherData((1,3776), vars, iArrays)

# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/NS_FF_all_3.jld2" NSMat
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_FF_all_3.jld2" NSMat


#####################################################
# Compute NS based on drifted weights (second step) #
#####################################################
NS_TS = Dict()
portfolios = ["BV", "SV", "BG", "SG", "ALL"]
for ptf in portfolios
    print("Current portfolio: $ptf \n")
    crtdf = NSMat[ptf]
    newsTopics = ([:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0],
                   [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0],
                   [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0])
    t = 0
    tops = ["all", "RES", "RESF"]

    for nTopic in newsTopics
        t+=1
        print("Current topic: $(tops[t]) \n")
        dayNS = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)
        weekNS = aggNewsByPeriod(weekID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)
        monthNS = aggNewsByPeriod(monthID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)
        quarterNS = aggNewsByPeriod(quarterID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)

        dayNS[:dailyRebal] = @time rebalPeriods(dayNS, :perID; rebalPer=(dayofmonth, 1:32) )
        weekNS[:dailyRebal] = rebalPeriods(weekNS, :perID; rebalPer=(dayofmonth, 1:32) )
        monthNS[:dailyRebal] = rebalPeriods(monthNS, :perID; rebalPer=(dayofmonth, 1:32) )
        quarterNS[:dailyRebal] = rebalPeriods(quarterNS, :perID; rebalPer=(dayofmonth, 1:32) )

        for WS in ["EW", "VW"]
            dayNS[:driftW] = @time driftWeights(dayNS, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)
            weekNS[:driftW] = driftWeights(weekNS, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)
            monthNS[:driftW] = driftWeights(monthNS, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)
            quarterNS[:driftW] = driftWeights(quarterNS, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)

            NS1 = sort(varWeighter(dayNS, :NS, :perID, :driftW), :perID)
            NS2 = sort(varWeighter(weekNS, :NS, :perID, :driftW), :perID)
            NS3 = sort(varWeighter(monthNS, :NS, :perID, :driftW), :perID)
            NS4 = sort(varWeighter(quarterNS, :NS, :perID, :driftW), :perID)

            CSV.write("/home/nicolas/Data/TS/NS/$(ptf)_$(tops[t])_$(WS)_day.csv", NS1)
            CSV.write("/home/nicolas/Data/TS/NS/$(ptf)_$(tops[t])_$(WS)_week.csv", NS2)
            CSV.write("/home/nicolas/Data/TS/NS/$(ptf)_$(tops[t])_$(WS)_month.csv", NS3)
            CSV.write("/home/nicolas/Data/TS/NS/$(ptf)_$(tops[t])_$(WS)_quarter.csv", NS4)

            NS_TS["$(ptf)_$(tops[t])_$(WS)_day"] = NS1
            NS_TS["$(ptf)_$(tops[t])_$(WS)_week"] = NS2
            NS_TS["$(ptf)_$(tops[t])_$(WS)_month"] = NS3
            NS_TS["$(ptf)_$(tops[t])_$(WS)_quarter"] = NS4
        end
    end
end

# JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/NS_TS.jld2" NS_TS
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_TS.jld2"

crtDF = deleteMissingRows(NS_TS["ALL_RES_VW_week"], :NS)
H = 2:20
P = 2:12
Res = Array{Float64}(undef, H[end], P[end]).*NaN
for h in H
    print(h)
    for p in P
        if h>p
            Hfilter, reg = neverHPfilter(crtDF, h, p)
            Res[h,p] = reg[:aic]
        end
    end
end
heatmap(Res)
Hfilter, reg  = neverHPfilter(crtDF, 12, 8)
reg[:aic]
Hfilter = deleteMissingRows(Hfilter, :x_trend)
plot(Hfilter[:date], [Hfilter[:x_cycle],Hfilter[:x_trend]], ylims=(minimum(convert(Matrix,Hfilter[:,[:x, :x_trend, :x_cycle]])),maximum(convert(Matrix,Hfilter[:,[:x, :x_trend, :x_cycle]]))), linewidth = 2)


hpFilter = HPfilter(convert(Array{Float64}, crtDF[:,:NS]), 14400)
plot(hpFilter)
Hfilter, reg = neverHPfilter(DataFrame(Dict(:NS=>hpFilter,:perID=>crtDF[:,:perID])), 48, 36)
plot(collect(skipmissing(Hfilter[:,:x])), ylims=(minimum(skipmissing(Hfilter[:,:x])),maximum(skipmissing(Hfilter[:,:x]))))
plot(collect(skipmissing(Hfilter[:,:x_trend])), ylims=(minimum(skipmissing(Hfilter[:,:x])),maximum(skipmissing(Hfilter[:,:x]))))
plot!(collect(skipmissing(Hfilter[:,:x_cycle])), ylims=(minimum(skipmissing(Hfilter[:,:x])),maximum(skipmissing(Hfilter[:,:x]))))
plot!(collect(skipmissing(Hfilter[:,:x_random])), ylims=(minimum(skipmissing(Hfilter[:,:x])),maximum(skipmissing(Hfilter[:,:x]))), color=:black)


reg[:aic]
for i in keys(reg)
    print("$i \n")
end



































crtdf = raw["BG"]
crtdf2 = oldDf["BV"]
@time sort!(crtdf, [:permno, :date])

foo = aggRetByPeriod(quarterID, crtdf, :retadj, meCol=:wt)
bar1 = FFweighting(foo, :perID, :me, :aggRet)
sort!(bar1, :perID)
bar2 = simpleEW(crtdf2, :date, :me, :retadj)
sort!(bar2, :date)

plot(HPfilter((ret2tick(bar1[:x1])), 1440))
plot!((ret2tick(bar1[:x1])))
plot(HPfilter((ret2tick(bar2[:x1])), 1440000))
plot!((ret2tick(bar2[:x1])))

NS = @time aggNewsByPeriod(dayID, crtdf, :nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0, :me)
length(collect(skipmissing(NS[:NS])))



rebalDays = @time rebalPeriods(crtdf, :date; rebalPer=(dayofmonth, [1]) )
sort(collect(Set(rebalDays)))


crtdf = copy(NS)







crtdf = oldDf["ALL"]

# Compute returns based on drifted weights (first step)
crtdf[:dailyRebal] = @time rebalPeriods(crtdf, :date; rebalPer=(dayofmonth, 1:32) )
crtdf[:monthyRebal] = @time rebalPeriods(crtdf, :date; rebalPer=(dayofquarter, [1]) )

crtdf[:monthlyW] = @time driftWeights(crtdf, "VW", rebalCol=:monthyRebal, meCol=:me, stockCol=:permno, dateCol=:date)
crtdf[:dailyW] = @time driftWeights(crtdf, "VW", rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date)

res1 = varWeighter(crtdf, :retadj, :date, :monthlyW)
sort!(res1, :date)
res2 = varWeighter(crtdf, :retadj, :date, :dailyW)
sort!(res2, :date)

plot(ret2tick(res1[:retadj]))
plot!(ret2tick(res2[:retadj]))
plot!(ret2tick(bar2[:x1]))

weekFreq = aggRetByPeriod(quarterID, res2, :retadj, stockCol=false)
plot(ret2tick(weekFreq[:aggRet]))





# NS1 = sort(deleteMissingRows(NS1, :NS), :perID)
# NS2 = sort(deleteMissingRows(NS2, :NS), :perID)
# NS3 = sort(deleteMissingRows(NS3, :NS), :perID)
# NS4 = sort(deleteMissingRows(NS4, :NS), :perID)
# plot(NS1[:perID], NS1[:NS])
# plot(NS2[:perID], NS2[:NS])
# plot(NS3[:perID], NS3[:NS])
# plot(NS4[:perID], NS4[:NS])



HPfilter(y::Vector{Float64}, lambda::Float64)
#######################
# Compute NS surprise #
#######################
portfolios = ["BV", "SV", "BG", "SG", "ALL"]
ptf = portfolios[1]
newsTopics = ([:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0],
               [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0],
               [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0])
crtdf = NSMat[ptf]
nTopic = newsTopics[1]
crtdf[:NS_all] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
nTopic = newsTopics[2]
crtdf[:NS_RES] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
nTopic = newsTopics[3]
crtdf[:NS_RESF] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]

crtdf[:dailyRebal] = @time rebalPeriods(crtdf, :perID; rebalPer=(dayofmonth, 1:32) )

WS = "VW"
crtdf[:driftW] = @time driftWeights(crtdf, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)

# News surprise
LTspan = 60
STspan = 5
iS = 1 # interval span for rolling window (default 1 = every day)
a = @time NSsuprise2(crtdf, LTspan, STspan, iS, newsTopics)
b = @time NSsuprise2(crtdf, LTspan, STspan, 4, newsTopics)

Nsurp = sort(varWeighter(b, :NSsurp, :date, :driftW), :date)
Nsurp = deleteMissingRows(Nsurp, :NSsurp)
plot(Nsurp[:date], Nsurp[:NSsurp])

using RCall
TS, X = Nsurp[:date], Nsurp[:NSsurp]
@rput TS; @rput X
R"""
library(xts)
M = xts(X, order.by = TS)
plot(M)
"""


for (j,k) in zip(1:iS:(T-(LTspan+STspan)+1), (LTspan+1):iS:T)
    print("\n $j $k \n")
end

"""
TO-DO: Implement a version where instead of looking x observations back I look x "DAYS" back
"""
function NSsuprise2(crtdf, LTspan, STspan, iS, newsTopics, wCol=:driftW, dateCol=:date)
    topicLT = newsTopics[1]
    topicST = newsTopics[2]
    keyDates = sort(collect(Set(crtdf[:date])))[1:iS:end]
    res = by(crtdf, [:permno]) do xdf
        res = Dict()
        T = size(xdf,1) #Total number of observations
        nbObs = length(1:iS:(T-(LTspan+STspan)+1))
        if nbObs>0
            NSsurp = zeros(nbObs)
            cc=0
            for (j,k) in zip(1:iS:(T-(LTspan+STspan)+1), (LTspan+1):iS:T)
                cc+=1
                LTdf = xdf[(j:(k-1)), :]
                LTNS = computeNS(LTdf, topicLT[1], topicLT[2], topicLT[3])
                STdf = xdf[(k:(k+STspan-1)), :]
                STNS = computeNS(STdf, topicST[1], topicST[2], topicST[3])
                NSsurp[cc] = LTNS-STNS
            end
            res[:NSsurp] = replace(NSsurp, NaN=>missing)
            res[:date] = xdf[(LTspan+STspan):iS:T, :date]
            res[wCol] = xdf[(LTspan+STspan):iS:T, wCol]
        else
            res[:NSsurp] = missing
            res[:date] = missing
            res[wCol] = missing
        end
        DataFrame(res)
    end
    return deleteMissingRows(res, :date)
end
