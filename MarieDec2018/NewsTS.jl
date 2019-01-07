using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2,
      TSmap, Plots, CSV, TrendCycle, Misc

iArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
RetMat = gatherData((1,3776), ["permno", "date", "retadj", "me"], iArrays)



szvar = "ranksize" #sizedecile ranksize
bmvar = "rankbm" #bmdecile rankbm
wt = :wt
filters = Dict( "tdF" => ["td", tdrange],
                "BigF" => [szvar, (6,10)],
                "SmallF" => [szvar, (1,5)],
                "GrowthF" => [bmvar, (1,3)],
                "ValueF" => [bmvar, (8,10)],
                "SizeA" => [szvar, (1,10)],
                "ValueA" => [bmvar, (1,10)] )

raw = Dict()
VWts = Dict()
cc = [1]
ptfnames = ["BG", "BV", "SG", "SV", "ALL"]
ptfs = [("tdF", "BigF", "GrowthF")]#, ("tdF", "BigF", "ValueF"), ("tdF", "SmallF", "GrowthF"), ("tdF", "SmallF", "ValueF"), ("tdF", "SizeA", "ValueA")]
testQuery()
@time for ptf in ptfs
    # retvals = ["permno", "date", "me", "negSum_nov12H_0", "posSum_nov12H_0", "nS_nov12H_0", "retadj",
    #             "negSum_RES_inc_RESF_excl_nov12H_0", "posSum_RES_inc_RESF_excl_nov12H_0",
    #             "nS_RES_inc_RESF_excl_nov12H_0", "negSum_RESF_inc_nov12H_0", "posSum_RESF_inc_nov12H_0",
    #             "nS_RESF_inc_nov12H_0"]
    # iniArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
    #               Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
    #               Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
    #               Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
    retvals = ["permno", "date", "me", "wt", "retadj"]
    iniArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[]]

    if length(ptf)==3
        f1 = deepcopy(filters[ptf[1]])
        f2 = deepcopy(filters[ptf[2]])
        f3 = deepcopy(filters[ptf[3]])
        raw[ptfnames[cc[1]]] = @time queryDF(retvals, iniArrays, f1, f2, f3)
    elseif length(ptf)==1
        f1 = deepcopy(filters[ptf[1]])
        raw[ptfnames[cc[1]]] = @time queryDF(retvals, iniArrays, f1)
    end
    # VWts[ptfnames[cc[1]]] = @time FFweighting(raw[ptfnames[cc[1]]], :date, wt, :retadj)
    cc[1]+=1
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



#####################################################
# Compute NS based on drifted weights (second step) #
#####################################################
portfolios = ["BV", "SV", "BG", "SG", "ALL"]
for ptf in portfolios
    print("Current portfolio: $ptf \n")
    crtdf = raw[ptf]
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
        end
    end
end

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
crtdf = raw[ptf]
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
a = @time NSsuprise(LTspan, STspan, iS, newsTopics)
b = a[a[:permno].==93422,:NSsurp]
plot(collect(skipmissing(b)))
