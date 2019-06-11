using JLD2, Statistics, DataFrames, Plots, TSmap, RetManip, PtfPerf, StatsBase, NaNMath

@time JLD2.@load "/run/media/nicolas/Research/GAdataRES.jld2"
TSfreqs = TSfreq()

ptfBreakpoints = [(0,10), (10,35), (35,65), (65,80), (90,100), (0,100)]
########### GA Parameters ###############
nbBuckets = 20
onlynewsdays = false
LeftOverMarket = true
fitnessvar = "interaction_tstat"
decayrate = 2
nbGenerations = 6000
mutRate = 0.01
rankmem = 350
WS="EW"
sizefilter = 2
freq = :qy
#########################################
@time data = data[data[:sizedecile].>sizefilter,:]
####################

########## Time filter ##################
TSfreqs = TSfreq()
data[:timefilter] = "(0,0)"
##### Chosen freq param #####
periods = TSfreqs[freq]
#############################
@time for row in 1:size(data,1)
    data[row,:timefilter] = periods[Int(data[row,:perid])]
end
dataTofilterFrom = deepcopy(data)
periods = sort(collect(Set(TSfreqs[freq])))



Res = Dict()
for (low, high) in ptfBreakpoints
    Res[(low, high)] = Float64[]
end

for periodID in 1:length(periods)
    filepathname = "/run/media/nicolas/Research/GAoptims/G$(nbGenerations)_P$(periodID)_F$(freq)_B$(nbBuckets)_D$(decayrate)_Mu$(mutRate)_on$(onlynewsdays)_lom$(LeftOverMarket)_WS$(WS).jld2"
    JLD2.@load filepathname AAA

    print(periods[periodID])
    stockRanks = AAA[3]
    stockVec, meanrankVec = [], Float64[]
    for (stock, ranks) in stockRanks
        push!(stockVec, stock)
        push!(meanrankVec, mean(ranks))
    end
    rankDF = DataFrame(Dict("stock"=>stockVec, "meanrank"=>meanrankVec))
    sort!(rankDF, :meanrank)
    rankDF[:meanrank] = replace(rankDF[:meanrank], NaN=>NaNMath.mean(rankDF[:meanrank]))
    crtDF = dataTofilterFrom[dataTofilterFrom[:timefilter].==periods[periodID],:]
    for (low, high) in ptfBreakpoints
        plow = percentile(rankDF[:meanrank], low)
        phigh = percentile(rankDF[:meanrank], high)
        SensStocks = convert(Array{Float64}, rankDF[(rankDF[:meanrank].>=plow) .& (rankDF[:meanrank].<=phigh), :stock])
        append!(Res[(low, high)], ptfRet(crtDF, SensStocks, VWeight))
    end
    display(plot(ret2tick(Res[ptfBreakpoints[1]]), title = "High"))
    display(plot(ret2tick(Res[ptfBreakpoints[5]]), title = "Low"))
    display(plot(ret2tick(Res[ptfBreakpoints[6]]), color = :black, title = "Mkt"))
    # display(plot(ret2tick(Res[ptfBreakpoints[1]].-Res[ptfBreakpoints[5]]), title = "Spread SMI 1"))
end

plot(ret2tick(Res[ptfBreakpoints[1]]))
plot!(ret2tick(Res[ptfBreakpoints[5]]))
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
