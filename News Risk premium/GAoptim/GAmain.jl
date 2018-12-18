using JLD2, CSV, Random, StatsBase, Statistics, Distributed, Plots, Dates
addprocs(4)
@everywhere using ParallelDataTransfer, DataStructures, DataFrames
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/GAoptim/GAhelp.jl")

@time JLD2.@load "/run/media/nicolas/Research/GAdata.jld2"
@time sort!(data, [:permno, :perid])

data[:sum_perNbStories_] = replace(data[:sum_perNbStories_], NaN=>0)
data[:sum_perNbStories_] = replace(data[:sum_perNbStories_], missing=>0)
data[:rawnewsstrength] = abs.(data[:sum_perSent_])
data[:rawnewsstrength] = replace(data[:rawnewsstrength], NaN=>0)
data[:rawnewsstrength] = replace(data[:rawnewsstrength], missing=>0)

@time data = data[isnotmissing.(data[:cumret]),:];
@time data = data[isnotmissing.(data[:wt]),:];

# datab = data[1:12000000,:]

########### GA Parameters ###############
nbBuckets = 80
onlynewsdays = false
LeftOverMarket = true
fitnessvar = "interaction_tstat"
decayrate = 1.5
nbGenerations = 500
mutRate = 0.01
rankmem = 1000
WS="VW"
#########################################

########## Time filter ##################
FFfactors = CSV.read("/run/media/nicolas/Research/FF/dailyFactors.csv")[1:3776,:]
todate = x -> Date(string(x),"yyyymmdd")
dates = todate.(FFfactors[:Date])
ymonth = convert(Array{Any}, Dates.yearmonth.(dates))
for i in 1:length(ymonth)
    ymonth[i] = "$(ymonth[i])"
end
months = Dates.month.(dates)
weekdays = Dates.dayname.(dates)
ys = Dates.year.(dates)
wmy = []
for (i,j,k) in zip(Dates.week.(dates), ys,months)
    push!(wmy, "$i $j $k")
end
qy = []
for (i,j) in zip(Dates.quarterofyear.(dates), ys)
    push!(qy, "$i $j")
end
data[:timefilter] = "(0,0)"
@time for row in 1:size(data,1)
    data[row,:timefilter] = ymonth[Int(data[row,:perid])]
end
dataTofilterFrom = deepcopy(data)

###147 didn't work out!
for periodID in 149:180

    print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n CURRENT DATE : $periodID \n\n\n\n\n\n\n\n $(Dates.format(now(), "HH:MM:SS")) \n\n\n\n\n\n\n\n\n\n\n\n")

    data = dataTofilterFrom[dataTofilterFrom[:timefilter].==ymonth[periodID],:]
    ###############################################


    # Create a Dict where each entry contains a list of all rows where a stock/td/... appears
    @time permnoIDs = valueFilterIdxs(:permno, onlynewsdays, data);
    @time tdIDs = valueFilterIdxs(:perid, false, data);
    @time for (td, idxs) in tdIDs
        tdIDs[td] = data[idxs,:]
    end
    # Instead of just keeping the IDs, keep the whole dataframes for reference!!

    tdIDs = SortedDict(tdIDs)
    td_permno_IDs = Dict()
    @time for (td, subdf) in tdIDs
        td_permno_IDs[td] = valueFilterIdxs(:permno, onlynewsdays, subdf);
    end
    td_permno_IDs = SortedDict(td_permno_IDs)

    #data to send on other workers
    print("Sending data to other workers")
    @time sendto(workers(), LeftOverMarket=LeftOverMarket)
    @time sendto(workers(), tdIDs=tdIDs)
    @time sendto(workers(), td_permno_IDs=td_permno_IDs)
    @time sendto(workers(), data=data)

    include("$(laptop)/News Risk premium/GAoptim/GAhelp.jl")
    AAA = iterateGenerations(permnoIDs, nbBuckets, fitnessvar, decayrate, nbGenerations, mutRate, rankmem, WS)

    filepathname = "/run/media/nicolas/Research/GAoptims/G$(nbGenerations)_P$(periodID)_B$(nbBuckets)_D$(decayrate)_Mu$(mutRate)_Me$(rankmem)_on$(onlynewsdays)_lom$(LeftOverMarket)_WS$(WS).jld2"
    JLD2.@save filepathname AAA
end #for periodID

# I AM NOT COMPLETELY SURE THE CROSSOVER LOOKS FOR THE RIGHT PARENTS
# IMPLEMENT VARYING DECAY AND MUTATION RATES (based on volatility of fitness , fitness level, etc...)
#


for generation in 1:nbGenerations
    if generation == 1
        Pop = initialPopulation(permnoIDs, nbBuckets);
    end
    @time ptfTS = pmap(filteredVariablesParallel, [stocks for (rank,stocks) in Pop]);
    fitnessDict = Dict()
    @time for i in 1:nbBuckets
        fitnessDict[i] = regptfspill(ptfTS[i], :rawnewsstrength_ptf, "VW", control = :rawnewsstrength_mkt, relcoveragetype = 1);
    end
    sortbyfitness = ones(nbBuckets,2)
    for (key, val) in fitnessDict
        sortbyfitness[key,1] = key
        sortbyfitness[key,2] = val[fitnessvar][1]
    end
    sortbyfitness = convert(DataFrame, sortbyfitness); names!nbDays(sortbyfitness, [:ptf, :fitnessScore]);
    sort!(sortbyfitness, :fitnessScore, rev=true)
    push!(ScoresOverTime, crtscore(sortbyfitness[:fitnessScore]))
    plot(sortbyfitness[:fitnessScore])
    plot(ScoresOverTime)

    # zScore = (sortbyfitness[:fitnessScore] .- mean(sortbyfitness[:fitnessScore])) ./ std(sortbyfitness[:fitnessScore])
    # for i in 1:length(zScore)
    #     if zScore[i]>2
    #         zScore[i] = 2
    #     end
    # end
    # zScore = zScore ./ 5 .+ 0.5
    # invzScore = zScore .^-1 ./ 10
    # sample(sortbyfitness[:ptf], Weights(zScore))
    # sum(vcat(before, decay^-1, after) .+ missingmass/nbBuckets)

    COmat = crossoverMat(nbBuckets, decayrate)
    sum(COmat[:,1])
    newptf = Dict()
    laststocks = zeros(20,20)
    Popold = copy(Pop)
    # Loop over portfolio of stocks
    for ptf in 1:nbBuckets
        newptf[ptf] = []
        # Loop over proportions for each portfolio
        for i in 1:nbBuckets
            # In portfolio i where I look for stocks, get a proportion as defined by COmat
            laststock = Int(ceil(length(Popold[sortbyfitness[:ptf][i]]) * COmat[i,ptf]))
            laststocks[ptf, i] = laststock
            #Check if in that portfolio i I still have enough stocks for this
            if length(Pop[sortbyfitness[:ptf][i]])>=laststock
                # Add to portfolio of rank ptf the stocks from prtfolio i
                append!(newptf[ptf], Pop[sortbyfitness[:ptf][i]][1:laststock])
                if 1+laststock>length(Pop[sortbyfitness[:ptf][i]])
                    Pop[sortbyfitness[:ptf][i]] = []
                else
                    Pop[sortbyfitness[:ptf][i]] = Pop[sortbyfitness[:ptf][i]][1+laststock:end]
                end
            end
        end
    end

    # Shuffle excess stocks to make sure all ptfs have the same nb of stocks
    # Find out (from old Pop with all stocks) how many stocks max a ptf can contain
    csum = [0]
    for (key, val) in Popold
        csum[1]+=length(val)
    end
    maxStocks = Int(ceil(csum[1]/nbBuckets))
    # Add leftover stocks from Pop
    stocksToShuffle = []
    for (key, vals) in Pop
        append!(stocksToShuffle, vals)
    end
    # Add stocks that exceed limit of nb of stocks in ptf
    for (key, vals) in newptf
        if length(vals)>maxStocks
            append!(stocksToShuffle, vals[maxStocks+1:end])
            newptf[key] = vals[1:maxStocks]
        end
    end

    # Assume those leftover stocks shuffled randomly act a bit like a mutation
    print("hey")
    Pop  = addStocksToShuffle(newptf, maxStocks, stocksToShuffle)
end





#     for row in 1:nbBuckets
#         wvec = test[:,row] ./ sum(test[:,row])
#         missingmass = 1-sum(test[:,row])
#         print(missingmass)
#         print("\n")
#         for i in 1:length(test[row,:])
#             test[i,row] += wvec[i]*missingmass
#         end
#     end
#     print("\n")
#     print(sum(test[:,5]))
# end


sum(test)

#functions to send on other workers
# @time sendto([2], filteredVariablesParallel=filteredVariablesParallel)


# res = @time @spawnat 2 size(tdIDs[1])
# @time fetch(res)
# res = @time @spawnat 2 length(td_permno_IDs)
# @time fetch(res)
# res = @time @spawnat 2 DataFrame(Dict(1=>5))
# @time fetch(res)

@time sendto(workers(), td_permno_IDs=td_permno_IDs)



foo = filteredVariablesParallel(Pop[1])

#Adjust for risk-free rate



# compute fitness
for td in sort(collect(keys(tdIDs)))

end



@time byday = by(mktdf, :perid) do df
    res = Dict()
    res[:VWret_v] = VWeight(df, :cumret)
end;

@time ptfidxs = submatrixIdx([10001, 10225], permnoIDs);
@time complementaryidxs = symdiff(1:size(data,1), ptfidxs)
@time datab[idxs,:];
