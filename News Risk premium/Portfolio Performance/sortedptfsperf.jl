using JLD2, Statistics, DataFrames, Plots, TSmap, FindFcts, RetManip, PtfPerf, StatsBase, NaNMath

@time JLD2.@load "/run/media/nicolas/Research/GAdata.jld2"
TSfreqs = TSfreq()

ptfBreakpoints = [(0,5), (0,10), (10,20), (20,50), (50,80), (80,100), (90,100), (0,100)]
########### GA Parameters ###############
nbBuckets = 50
onlynewsdays = false
LeftOverMarket = true
fitnessvar = "interaction_tstat"
decayrate = 2
nbGenerations = 250
mutRate = 0.01
rankmem = 999
WS="VW"
freq = TSfreqs[:qy]
#########################################
data[:timefilter] = "(0,0)"
@time for row in 1:size(data,1)
    data[row,:timefilter] = freq[Int(data[row,:perid])]
end
freq = sort(collect(Set(TSfreqs[:qy])))
dataTofilterFrom = deepcopy(data)


Res = Dict()
for (low, high) in ptfBreakpoints
    Res[(low, high)] = Float64[]
end

for periodID in 1:length(freq)
    if onlynewsdays
        on = "t"
    else
        on = "f"
    end
    if LeftOverMarket
        lOm = "t"
    else
        lOm = "f"
    end
    filepathname = "/run/media/nicolas/Research/GAoptims/G$(nbGenerations)_P$(periodID)_F$(length(freq))_B$(nbBuckets)_D$(decayrate)_Mu$(mutRate)_on$(on)_lom$(lOm)_WS$(WS).jld2"
    JLD2.@load filepathname AAA

    print(freq[periodID])
    stockRanks = AAA[3]
    stockVec, meanrankVec = [], Float64[]
    for (stock, ranks) in stockRanks
        push!(stockVec, stock)
        push!(meanrankVec, mean(ranks))
    end
    rankDF = DataFrame(Dict("stock"=>stockVec, "meanrank"=>meanrankVec))
    sort!(rankDF, :meanrank)
    rankDF[:meanrank] = replace(rankDF[:meanrank], NaN=>NaNMath.mean(rankDF[:meanrank]))

    crtDF = dataTofilterFrom[dataTofilterFrom[:timefilter].==freq[periodID],:]
    for (low, high) in ptfBreakpoints
        print((low,high))
        plow = percentile(rankDF[:meanrank], low)
        phigh = percentile(rankDF[:meanrank], high)
        SensStocks = rankDF[(rankDF[:meanrank].>=plow) .& (rankDF[:meanrank].<=phigh), :stock]
        append!(Res[(low, high)], ptfRet(crtDF, SensStocks, VWeight))
    end
    display(plot(ret2tick(Res[ptfBreakpoints[1]]), title = "Portfolio value over time"))
    display(plot!(ret2tick(Res[ptfBreakpoints[3]])))
    display(plot!(ret2tick(Res[ptfBreakpoints[7]]), color = :black))
    display(plot!(ret2tick(Res[ptfBreakpoints[8]]), color = :yellow))
    display(plot(ret2tick(Res[ptfBreakpoints[1]].-Res[ptfBreakpoints[7]]), title = "Spread SMI 1"))
    display(plot(ret2tick(Res[ptfBreakpoints[2]].-Res[ptfBreakpoints[7]]), title = "Spread SMI 2"))
    display(plot(ret2tick(Res[ptfBreakpoints[3]].-Res[ptfBreakpoints[7]]), title = "Spread SMI 3"))
end

plot(ret2tick(Res[ptfBreakpoints[1]]))
plot!(ret2tick(Res[ptfBreakpoints[7]]))
plot!(ret2tick(Res[ptfBreakpoints[7]]))
res = Float64[]
for i in 1:length(ptfBreakpoints)
    push!(res, mean(Res[ptfBreakpoints[i]]))
end
plot(res)

res = Float64[]
for i in 1:60
    crtDF = dataTofilterFrom[dataTofilterFrom[:timefilter].==freq[5],:]
    push!(res, ptfRet(crtDF))
end
plot(ret2tick(res))


JLD2.@save "/run/media/nicolas/Research/GAoptims/sameperResEW.jld2" samperRes
# Measure persistence level of stock ranking over time
