using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2,
      TSmap, Plots, CSV, TrendCycle, Misc, FindFcts, DataStructures

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




#######################
# Compute NS surprise #
#######################

Nsurp_TS = Dict()
portfolios = ["BV", "SV", "BG", "SG", "ALL"]

ALL = [:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0]
RES = [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0]
RESF = [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0]
#### The below specs must NOT change for accountability of filename!! ######
newsTopics = [(RESF,RES), (ALL,RES), (RESF,RES), (ALL,RES), (ALL,RES), (RESF,RES)]
LTspan = [Dates.Month(3), Dates.Month(3), Dates.Month(1), Dates.Month(1), Dates.Month(6), Dates.Month(6)]
STspan = [Dates.Week(1), Dates.Week(1), Dates.Day(1), Dates.Day(1), Dates.Month(1), Dates.Week(2)]
minLT, minST, iS = [20, 20,10,10,20,20],[1,1,1,1,10,3],[1,1,1,1,20,1]
specs = 6:length(LTspan) # change here if you want to add further specs

@time for ptf in portfolios
    print("Crt ptf: $ptf \n")
    crtdf = NSMat[ptf]
    nTopic = ALL
    crtdf[:NS_all] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
    nTopic = RES
    crtdf[:NS_RES] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
    nTopic = RESF
    crtdf[:NS_RESF] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]

    crtdf[:dailyRebal] = @time rebalPeriods(crtdf, :perID; rebalPer=(dayofmonth, 1:32) )

    @time for WS in ["VW"]
        crtdf[:driftW] = @time driftWeights(crtdf, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)

        @time for spec in specs
            print("Crt spec: $spec \n")
            b = @time NSsuprise(crtdf, LTspan[spec],  STspan[spec], minLT[spec], minST[spec], iS[spec], newsTopics[spec])
            Nsurp = sort(varWeighter(b, :Nsurp, :date, :driftW), :date)
            Nsurp = deleteMissingRows(Nsurp, :Nsurp)
            CSV.write("/home/nicolas/Data/TS/Nsurp/$(ptf)_$(spec)_$(WS).csv", Nsurp)

            Nsurp_TS["$(ptf)_$(spec)_$(WS)"] = Nsurp
        end
    end
end
Nsurp_TS6 = copy(Nsurp_TS)
JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/Nsurp_TS6.jld2" Nsurp_TS6



























########################
###### FIltering #######
########################
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
LTspan = Dates.Month(3)
STspan = Dates.Day(3)
minLT, minST, iS = 20,1,1
portfolios = ["BV", "SV", "BG", "SG", "ALL"]
ptf = portfolios[1]
ALL = [:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0]
RES = [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0]
RESF = [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0]
newsTopics = [RESF,RES]

crtdf = NSMat[ptf]
nTopic = ALL
crtdf[:NS_all] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
nTopic = RES
crtdf[:NS_RES] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
nTopic = RESF
crtdf[:NS_RESF] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]

crtdf[:dailyRebal] = @time rebalPeriods(crtdf, :perID; rebalPer=(dayofmonth, 1:32) )

WS = "VW"
crtdf[:driftW] = @time driftWeights(crtdf, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)

b = @time NSsuprise(crtdf, Dates.Month(3),  Dates.Week(2), 10, 3, 10, newsTopics)
Nsurp = sort(varWeighter(b, :Nsurp, :date, :driftW), :date)
Nsurp = deleteMissingRows(Nsurp, :Nsurp)
CSV.write("/home/nicolas/Data/TS/Nsurp/$(ptf)_$(tops[t])_$(WS)_quarter.csv", Nsurp)


# News surprise

a = @time NSsuprise2(crtdf, LTspan, STspan, iS, newsTopics)

b = @time NSsuprise2(crtdf, Dates.Month(3),  Dates.Week(2), 10, 3, 10, newsTopics)

Nsurp = sort(varWeighter(b, :Nsurp, :date, :driftW), :date)
Nsurp = deleteMissingRows(Nsurp, :Nsurp)
plot(Nsurp[:date], Nsurp[:NSsurp])

using RCall
TS, X = Nsurp[:date], Nsurp[:Nsurp]
@rput TS; @rput X; @rput Y
R"""
library(xts)
M = xts(Y, order.by = TS)
plot(M)
"""

Y = HPfilter(collect(skipmissing(X)), 1400)
