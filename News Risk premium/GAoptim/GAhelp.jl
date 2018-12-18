using Distributed, RCall, GLM


@everywhere function VWeight(v, namestoVW)
    # res = Dict()
    # v = v[isnotmissing.(v[:cumret]),:]
    # v = v[isnotmissing.(v[:wt]),:]
    totweight = sum(v[:wt])
    stockweight = v[:wt] ./ totweight
    return sum(v[namestoVW] .* stockweight)
end

@everywhere function EWeight(v, namestoVW)
    res = Dict()
    # v = v[isnotmissing.(v[:cumret]),:]
    # v = v[isnotmissing.(v[:wt]),:]
    totweight = custom_sum(v[:wt])
    stockweight = custom_mean(v[:wt]) ./ totweight
    return custom_sum(v[namestoVW] .* stockweight)
end

function custom_mean(X, retval=1)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==1
        return retval
    else
        return mean(collect(skipmissing(X)))
    end
end

function isnotmissing(x)
    return !ismissing(x)
end

function custom_sum(X, retval=0)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==0
        return retval
    else
        return sum(collect(skipmissing(X)))
    end
end


function mysimdiff(X,Y)
    b = zeros(length(X))
    b[Y] .= 1
    a = ones(length(X)) .- b
    return convert(Array{Bool}, a)
end


@everywhere function submatrixIdx(stocklist, permnosIDs)
    idxstokeep = Int[]
    for stock in stocklist
        if stock in keys(permnosIDs)
            append!(idxstokeep, permnosIDs[stock])
        end
    end
    return idxstokeep
end



"""
Sometimes I'd want to have just all the stock's IDs, for instance when I filter by period for example.
I can also filter to get all observations of a stock where it gets news.
"""
function valueFilterIdxs(valtofilt, filternewsdays, data)

    permnolist = sort(collect(Set(data[valtofilt])))
    permnoIDs = Dict()

    for permno in permnolist
        permnoIDs[permno] = Int[]
    end

    for row in 1:size(data, 1)
        if filternewsdays
            if data[row,:sum_perNbStories_]>0
                push!(permnoIDs[data[row,valtofilt]], row)
            end
        else
            push!(permnoIDs[data[row,valtofilt]], row)
        end
    end

    return permnoIDs
end



"""
returns ranges (i.e. indices to split the data).
"""
function partition_array_indices(nb_data::Int, nb_data_per_chunk::Int)
    nb_chunks = ceil(Int, nb_data / nb_data_per_chunk)
    ids = UnitRange{Int}[]
    for which_chunk = 1:nb_chunks
        id_start::Int = 1 + nb_data_per_chunk * (which_chunk - 1)
        id_end::Int = id_start - 1 + nb_data_per_chunk
        if id_end > nb_data
            id_end = nb_data
        end
        push!(ids, id_start:id_end)
    end
    return ids
end




function initialPopulation(permnosIDs, nBuckets)
    allstocks = collect(keys(permnosIDs))
    allstocks = allstocks[randperm(length(allstocks))]
    split_ranges = partition_array_indices(length(allstocks),Int(ceil(length(allstocks)/nBuckets)))
    Population = Dict()
    for i in 1:length(split_ranges)
        Population[i] = allstocks[split_ranges[i]]
    end
    return Population
end




@everywhere function filtercrtDF(crtstocks, permnosIDs, dataDF, LeftOverMarket)
    ptfidxs = submatrixIdx(crtstocks, permnosIDs);
    ptfdf = dataDF[ptfidxs,:];
    if LeftOverMarket
        complementaryidxs = symdiff(1:size(dataDF,1), ptfidxs);
        mktdf = dataDF[complementaryidxs,:];
    else
        mktdf = dataDF
    end;
    return ptfdf, mktdf
end



@everywhere function filteredVariablesParallel(crtPop, idx=2, WS="VW")
    crtGenerationTS = Dict()
    nbDays = length(keys(tdIDs))
    firstday = minimum(keys(tdIDs))
    variablestocompute = [:VWsent_ptf, :VWret_ptf, :EWsent_ptf, :EWret_ptf, :coverage_ptf, :rawnewsstrength_ptf,
                          :VWsent_mkt, :VWret_mkt, :EWsent_mkt, :EWret_mkt, :coverage_mkt, :rawnewsstrength_mkt]
    for var in variablestocompute
        crtGenerationTS[var] = Array{Float64}(undef, nbDays)
    end
    for (td, subdf) in tdIDs
        mattd = Int(td)
        td = Int(td-firstday+1)
        ptfdf, mktdf = filtercrtDF(crtPop, td_permno_IDs[mattd], subdf, LeftOverMarket)
        # print("hey")
        # break
        if WS=="VW"
            crtGenerationTS[:VWret_ptf][td] = VWeight(ptfdf, :cumret)
            crtGenerationTS[:VWret_mkt][td] = VWeight(mktdf, :cumret)
            # crtGenerationTS[:VWsent_ptf][td] = VWeight(ptfdf, :aggSent_)
            # crtGenerationTS[:VWsent_mkt][td] = VWeight(mktdf, :aggSent_)
        elseif WS=="EW"
            crtGenerationTS[:EWret_ptf][td] = EWeight(ptfdf, :cumret)
            crtGenerationTS[:EWret_mkt][td] = EWeight(mktdf, :cumret)
            # crtGenerationTS[:EWsent_ptf][td] = EWeight(ptfdf, :aggSent_)
            # crtGenerationTS[:EWsent_mkt][td] = EWeight(mktdf, :aggSent_)
        end
        # crtGenerationTS[:coverage_ptf][td] = sum(ptfdf[:sum_perNbStories_])
        # crtGenerationTS[:coverage_mkt][td] = sum(mktdf[:sum_perNbStories_])
        crtGenerationTS[:rawnewsstrength_ptf][td] = sum(ptfdf[:rawnewsstrength])
        crtGenerationTS[:rawnewsstrength_mkt][td] = sum(mktdf[:rawnewsstrength])
    end
    crtGenerationTS[:idx] = idx
    return crtGenerationTS
end






function regptfspill1(allptfs, nbBuckets, newsShockVar, WS ; control = :rawnewsstrength_mkt, relcoveragetype = 1)
    print("First")
    regres = Dict("ret_tstat_simple" => Float64[], "R2_1" => Float64[], "R2_2" => Float64[], "ret_tstat" => Float64[], "interaction_tstat" => Float64[])
    for i in 1:nbBuckets
        byday = allptfs[i]

        if relcoveragetype==1
            byday[:relcoverage] = byday[:rawnewsstrength_ptf] ./ byday[:rawnewsstrength_mkt]
        elseif relcoveragetype==2
            byday[:relcoverage] = byday[:coverage_ptf] ./ byday[:coverage_mkt]
        end

        byday[:newsShock] = byday[newsShockVar]
        byday[:controlShock] = byday[control]
        @rput byday
        if WS == "VW"
            R"mod = lm(VWret_mkt ~ VWret_ptf + VWret_ptf:newsShock + VWret_ptf:controlShock, data=byday)"
            R"mod1 = lm(VWret_mkt ~ VWret_ptf, data=byday)"
        elseif WS=="EW"
            R"mod = lm(EWret_mkt ~ EWret_ptf + EWret_ptf:newsShock + EWret_ptf:controlShock, data=byday)"
            R"mod1 = lm(EWret_mkt ~ EWret_ptf, data=byday)"
        end
        R"res = summary(mod)";
        R"res1 = summary(mod1)";
        @rget res; @rget res1;
        push!(regres["R2_1"], res[:adj_r_squared])
        push!(regres["R2_2"], res1[:adj_r_squared])
        try
            push!(regres["ret_tstat"], res[:coefficients][2,3])
            push!(regres["ret_tstat_simple"], res1[:coefficients][2,3])
            push!(regres["interaction_tstat"], res[:coefficients][4,3])
        catch
            print(byday[:VWret_mkt])
            print(byday[:VWret_ptf])
            error(res[:coefficients])
        end
    end
    return regres
end

function regptfspill2(crtptf, newsShockVar, WS ; control = :rawnewsstrength_mkt, relcoveragetype = 1)
    print("second")
    fitness = Dict("ret_tstat_simple" => Float64[], "R2_1" => Float64[], "R2_2" => Float64[],
                   "ret_tstat" => Float64[], "interaction_tstat" => Float64[], "R2_gain"=>Float64[])

    if relcoveragetype==1
        crtptf[:relcoverage] = crtptf[:rawnewsstrength_ptf] ./ crtptf[:rawnewsstrength_mkt]
    elseif relcoveragetype==2
        crtptf[:relcoverage] = crtptf[:coverage_ptf] ./ crtptf[:coverage_mkt]
    end

    crtptf[:newsShock] = crtptf[newsShockVar]
    crtptf[:controlShock] = crtptf[control]
    @rput crtptf
    try
        if WS == "VW"
            R"mod = lm(VWret_mkt ~ VWret_ptf + VWret_ptf:newsShock + VWret_ptf:controlShock, data=crtptf)"
            R"mod1 = lm(VWret_mkt ~ VWret_ptf, data=crtptf)"
        elseif WS=="EW"
            R"mod = lm(EWret_mkt ~ EWret_ptf + EWret_ptf:newsShock + EWret_ptf:controlShock, data=crtptf)"
            R"mod1 = lm(EWret_mkt ~ EWret_ptf, data=crtptf)"
        end
    catch
        error(crtptf[:relcoverage])
    end
    R"res = summary(mod)";
    R"res1 = summary(mod1)";
    @rget res; @rget res1;
    push!(fitness["R2_1"], res[:adj_r_squared])
    push!(fitness["R2_2"], res1[:adj_r_squared])
    push!(fitness["R2_gain"], res[:adj_r_squared]-res1[:adj_r_squared])
    try
        push!(fitness["ret_tstat"], res[:coefficients][2,3])
        push!(fitness["ret_tstat_simple"], res1[:coefficients][2,3])
        push!(fitness["interaction_tstat"], res[:coefficients][4,3])
    catch
        print(crtptf[:VWret_mkt])
        print(crtptf[:VWret_ptf])
        error(res[:coefficients])
    end
    return fitness
end


function splitdecay(nbBuckets, decay, bucketID, wStart)
    missingmass = 0
    after = Float64[decay^-1 / (wStart^-1)]
    for i in 1:(nbBuckets-bucketID)
        push!(after, after[end]/decay)
    end
    after = after[2:end]
    missingmass += (decay^-1 / (wStart^-1)) - sum(after)
    # after = after[2:end] .+ (missingmass/(nbBuckets-bucketID))
    before = Float64[decay^-1 / (wStart^-1)]
    for i in 1:bucketID-1
        push!(before, before[end]/decay)
    end
    missingmass += (decay^-1 / (wStart^-1)) - sum(before[2:end])
    before = before[end:-1:2]

    # ASSIGN LEFTOVER MASS WITH DECAYING WEIGHTS!
    afterbefore = vcat(before, after)
    wafterbefore = afterbefore ./ sum(afterbefore)
    for i in 1:length(wafterbefore)
        afterbefore[i] += wafterbefore[i]*missingmass
    end
    before = afterbefore[1:(bucketID-1)]
    after = afterbefore[bucketID:end]

    # before = before[2:end] .+ (missingmass/bucketID)
    res = vcat(before, decay^-1, after)
    return res
end


function crossoverMat(nbBuckets, decay, wStart=0.5)
    bID = 1
    test = splitdecay(nbBuckets, decay, bID, wStart) .* (decay*wStart)
    for bID in 2:nbBuckets
        test = hcat(test ,splitdecay(nbBuckets, decay, bID, wStart).* (decay*wStart))
    end
    return test
end



function addStocksToShuffle(newptff, maxStocksf, stocksToShufflef)
    stocksToShufflef = stocksToShufflef[randperm(length(stocksToShufflef))]
    for (key, ptf) in newptff
        key = Int(key)
        if length(ptf)<maxStocksf
            nbstocksToAdd = Int(minimum([maxStocksf-length(ptf), length(stocksToShufflef)]))
            append!(newptff[key],stocksToShufflef[1:nbstocksToAdd])
            stocksToShufflef = stocksToShufflef[nbstocksToAdd+1:end]
        end
    end
    return newptff
end



function crtscore(X)
    X = abs.(diff(X))
    res = sum(X.^(0.5))
    return res
end



function nbStocksPop(crtpop)
    res = 0
    for (key,val) in crtpop
        res+=length(Set(val))
    end
    return res
end



function iterateGenerations(permnoIDs, nbBuckets, fitnessvar, decayrate, nbGenerations, mutationRate, rankmemory, WS)
    ScoresOverTime = Float64[]
    intersect1OverTime = Float64[]
    Pop = initialPopulation(permnoIDs, nbBuckets);
    initialPop = deepcopy(Pop)
    Popold = deepcopy(Pop)
    dcr = (1-mutationRate)/nbGenerations

    stocksRanksOverTime = initRankOverTime(permnoIDs)

    # Loop over all generations
    for generation in 1:nbGenerations
        if generation != nbGenerations
            mutationRate += dcr
        end
        print("Current generation: $generation \n Current mutation rate : $mutationRate \n")

        Popold = deepcopy(Pop)

        # Compute the TS of returns and news coverage for ptfs and market
        ptfTS = pmap(filteredVariablesParallel, [Pop[i] for i in 1:nbBuckets], 1:nbBuckets, repeat([WS],nbBuckets));

        ptfTS = assignGoodKeys(nbBuckets, ptfTS)

        fitnessDict = crtFitnessDict(nbBuckets, ptfTS, WS)

        sortbyfitness = assignFitness(nbBuckets, fitnessDict)

        sort!(sortbyfitness, :fitnessScore, rev=true)
        push!(ScoresOverTime, crtscore(sortbyfitness[:fitnessScore]))
        if generation in 10:50:nbGenerations
            display(plot(sortbyfitness[:fitnessScore], title = "Fitness Score"))
            display(plot(sortbyfitness[:ptf], title = "Sorted ptf ranks"))
            display(plot!(1:nbBuckets))
            display(plot(sortbyfitness[:R2_gain], title = "R2 Gains"))
            display(plot(sortbyfitness[:R2_1], title = "R2 1"))
            display(plot(ScoresOverTime, title = "Scores over generations : $generation"))
        end

        # I confirm that Pop[1] has the highest score, Pop[20] the lowest and inbetween is correctly ordered
        Pop = reOrderDictKeys(sortbyfitness[:ptf], Pop)

        # print("Number of stocks that stayed in winning portfolio: $(length(intersect(Popold[1], Pop[1]))) \n")
        # print("Number of stocks that stayed in top-2 portfolio: $(length(intersect([Popold[1];Popold[2]],[Pop[1];Pop[2]]))) \n")
        # print("Number of stocks that stayed in top-3 portfolio: $(length(intersect([Popold[1];Popold[2];Popold[3]],[Pop[1];Pop[2];Pop[3]]))) \n")

        stocksRanksOverTime = stockRanks(stocksRanksOverTime, Pop)

        COmat = crossoverMat(nbBuckets, decayrate)
        newptf = Dict()
        laststocks = zeros(nbBuckets,nbBuckets)

        #Shuffle the population for random splits
        for (key,val) in Pop
            Pop[key] = val[randperm(length(val))]
        end

        PopToEmpty = deepcopy(Pop)
        # Loop over portfolio of stocks
        for ptf in 1:nbBuckets
            newptf[ptf] = []
            # Loop over proportions for each portfolio
            for i in 1:nbBuckets
                # In portfolio i where I look for stocks, get a proportion as defined by COmat
                laststock = Int(ceil(length(Pop[i]) * COmat[i,ptf]))
                laststocks[ptf, i] = laststock
                #Check if inR2_gain that portfolio i I still have enough stocks for this
                if length(PopToEmpty[i])>=laststock
                    # Add to portfolio of rank ptf the stocks from prtfolio i
                    append!(newptf[ptf], PopToEmpty[i][1:laststock])
                    if 1+laststock>length(PopToEmpty[i])
                        PopToEmpty[i] = []
                    else
                        PopToEmpty[i] = PopToEmpty[i][1+laststock:end]
                    end
                end
            end
        end

        # print("newptf intersect with Pop : $(length(intersect(newptf[1], Pop[1])))\n")
        # print("newptf intersect with Popold :  $(length(intersect(newptf[1], Popold[3])))\n")

        # Shuffle excess stocks to make sure all ptfs have the same nb of stocks
        # Find out (from old Pop with all stocks) how many stocks max a ptf can contain
        csum = [0]
        for (key, val) in initialPop
            csum[1]+=length(val)
        end
        maxStocks = Int(ceil(csum[1]/nbBuckets))
        # Add leftover stocks from Pop
        stocksToShuffle = []
        for (key, vals) in PopToEmpty
            append!(stocksToShuffle, vals)
        end

        # Add stocks that exceed limit of nb of stocks in ptf
        for (key, vals) in newptf
            if length(vals)>maxStocks
                append!(stocksToShuffle, vals[maxStocks+1:end])
                try
                    newptf[key] = vals[1:maxStocks]
                catch
                    error(maxStocks)
                end
            end
        end

        # print("newptf intersect AAA $(length(intersect(newptf[1], Pop[1])))\n")
        # Assume those leftover stocks shuffled randomly act a bit like a mutation

        newptf  = addStocksToShuffle(newptf, maxStocks, stocksToShuffle)
        # print("Nb stocks newptf: $(nbStocksPop(newptf)) \n")
        # print("newptf intersect Pop BBB $(length(intersect(newptf[1], Popold[1])))\n")
        # print("newptf intersect Popold BBB $(length(intersect(newptf[1], Pop[1])))\n")


        ## Mutate towards best
        stocksToShuffle = []
        #Shuffle the population for random splits

        splitMutationIDX = 0
        for (key,val) in newptf
            newptf[key] = val[randperm(length(val))]
            splitMutationIDX = Int(ceil(length(val)*mutationRate))
            append!(stocksToShuffle, val[1:splitMutationIDX])
            newptf[key] = val[(splitMutationIDX+1):end]
        end


        crtstockRanks = ones(length(stocksToShuffle),2)
        for i in 1:length(stocksToShuffle)
            crtstockRanks[i,1] = stocksToShuffle[i]
            crtstockRanks[i,2] = mean(stocksRanksOverTime[stocksToShuffle[i]])
        end
        stockRanksDF = DataFrame(crtstockRanks); names!(stockRanksDF, [:stock, :meanrank])
        sort!(stockRanksDF, :meanrank, rev=false)

        orderedStocks = stockRanksDF[:stock]
        # print("Before adding reshuffle intercept: $(length(intersect(newptf[1], Pop[1]))) \n")
        # print("Size of chunks: $splitMutationIDX \n")
        for i in 1:nbBuckets
            if i < nbBuckets
                if splitMutationIDX>length(orderedStocks)
                    append!(newptf[i], orderedStocks[1:Int(ceil(splitMutationIDX/2))])
                    orderedStocks = orderedStocks[Int(ceil(splitMutationIDX/2))+1:end]
                else
                    append!(newptf[i], orderedStocks[1:splitMutationIDX])
                    orderedStocks = orderedStocks[splitMutationIDX+1:end]
                end
            else
                append!(newptf[i], orderedStocks[1:end])
            end
        end
        # print("IIII Nb stocks Pop: $(nbStocksPop(newptf)) \n")
        # print("After adding reshuffle intercept Pop: $(length(intersect(newptf[1], Pop[1]))) \n")
        # print("After adding reshuffle intercept Popold: $(length(intersect(newptf[1], Popold[1]))) \n")

        # print("BPs: $BPs")
        # @time for stock in stocksToShuffle
        #     # print(BPs)
        #     # print("\n stock : $stock\n")
        #     # print("\n stocksRanksOverTime[stock] : $(stocksRanksOverTime[stock]) \n")
        #     firstPoint = minimum([length(stocksRanksOverTime[stock]), rankmemory])
        #     # print("\n firstPoint : $firstPoint\n")
        #     crtRank = mean(stocksRanksOverTime[stock][firstPoint:end])
        #     # print("\n crtRank : $crtRank\n")
        #     meanptf = findRank(crtRank, BPs)
        #     # print("\n meanptf : $meanptf\n")
        #     push!(Pop[meanptf], stock)
        # end

        # print("Final Nb stocks Pop: $(nbStocksPop(Pop)) \n")
        # print(length(intersect(Pop[1], Popold[1])))
        #
        # for (key, val) in Pop
        #     print("\n $(length(val))")
        # end

        push!(intersect1OverTime, length(intersect(Pop[1], newptf[1])))
        Pop = deepcopy(newptf)
        # display(plot(intersect1OverTime, title = "intersect1OverTime"))
        # print("Number of stocks in Pop before new generation: $(nbStocksPop(Pop)) \n")
    end
    return Pop, ScoresOverTime, stocksRanksOverTime
end


function stockRanks(stocksRanksOverTime, crtPop)
    for (key,val) in crtPop
        for stock in val
            push!(stocksRanksOverTime[stock], key)
        end
    end
    return stocksRanksOverTime
end



function ranksBPs(stocksRanksOverTime, chosenpercs)
    allranks = Float64[]
    for (stock, ranks) in stocksRanksOverTime
        push!(allranks, mean(ranks))
    end
    return percentile(allranks, chosenpercs)
end


function findRank(crtRank, crtpercs)
    res = 0
    for thresh in sort(crtpercs)
        res+=1
        if crtRank<=thresh
            break
        end
    end
    return res
end




function reOrderDictKeys(X, crtPop)
    provDic = Dict()
    for i in 1:length(X)
        provDic[i] = crtPop[X[i]]
    end
    return provDic
end


function assignGoodKeys(nbBuckets, crtPop)
    provDic = Dict()
    for i in 1:nbBuckets
        idx = crtPop[i][:idx]
        delete!(crtPop[i], :idx)
        provDic[idx] = crtPop[i]
    end
    return provDic
end



function initRankOverTime(XDict)
    stocksRanksOverTime = Dict()
    for stock in keys(XDict)
        stocksRanksOverTime[stock] = Int[]
    end
    return stocksRanksOverTime
end



function crtFitnessDict(nbBuckets, ptfTS, WS)
    fitnessDict = Dict()
    for i in 1:nbBuckets
        fitnessDict[i] = regptfspill(ptfTS[i], :rawnewsstrength_ptf, WS, control = :rawnewsstrength_mkt, relcoveragetype = 1);
    end
    return fitnessDict
end




function assignFitness(nbBuckets, fitnessDict)
    sortbyfitness = ones(nbBuckets,4)
    for (key, val) in fitnessDict
        sortbyfitness[key,1] = key
        sortbyfitness[key,2] = val[fitnessvar][1]
        sortbyfitness[key,3] = val["R2_gain"][1]
        sortbyfitness[key,4] = val["R2_1"][1]
    end
    sortbyfitness = convert(DataFrame, sortbyfitness); names!(sortbyfitness, [:ptf, :fitnessScore, :R2_gain, :R2_1]);
    return sortbyfitness
end




function regptfspill(crtptf, newsShockVar, WS ; control = :rawnewsstrength_mkt, relcoveragetype = 1)
    fitness = Dict("ret_tstat_simple" => Float64[], "R2_1" => Float64[], "R2_2" => Float64[],
                   "ret_tstat" => Float64[], "interaction_tstat" => Float64[], "R2_gain"=>Float64[])
    if relcoveragetype==1
       crtptf[:relcoverage] = crtptf[:rawnewsstrength_ptf] ./ crtptf[:rawnewsstrength_mkt]
    elseif relcoveragetype==2
       crtptf[:relcoverage] = crtptf[:coverage_ptf] ./ crtptf[:coverage_mkt]
    end

    crtptf[:newsShock] = crtptf[newsShockVar]
    crtptf[:controlShock] = crtptf[control]
    crtptf = convert(DataFrame, crtptf)
    res, res1 = 0, 0
    if sum(crtptf[:newsShock])!=0
        if WS == "VW"
           res = lm(@formula(VWret_mkt ~ VWret_ptf + VWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(VWret_mkt ~ VWret_ptf + controlShock&VWret_ptf), crtptf)
        elseif WS=="EW"
           res = lm(@formula(EWret_mkt ~ EWret_ptf + EWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(EWret_mkt ~ EWret_ptf + controlShock&VWret_ptf), crtptf)
        end
    else
        show(crtptf[[:VWret_mkt, :VWret_ptf, :newsShock, :controlShock]])
        crtptf[:newsShock][1] = 0.2
        if WS == "VW"
           res = lm(@formula(VWret_mkt ~ VWret_ptf + VWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(VWret_mkt ~ VWret_ptf + controlShock&VWret_ptf), crtptf)
        elseif WS=="EW"
           res = lm(@formula(EWret_mkt ~ EWret_ptf + EWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(EWret_mkt ~ EWret_ptf + controlShock&VWret_ptf), crtptf)
        end
    end
    regDF = OLScoeftableToDF(res)
    regDF1 = OLScoeftableToDF(res1)
    push!(fitness["R2_1"], adjr2(res))
    push!(fitness["R2_2"], adjr2(res1))
    push!(fitness["R2_gain"], adjr2(res)-adjr2(res1))

    if WS == "VW"
       push!(fitness["ret_tstat"], regDF[findall(regDF[:depvar].=="VWret_ptf & newsShock")[1], Symbol("t value")])
       push!(fitness["ret_tstat_simple"], regDF[findall(regDF[:depvar].=="VWret_ptf & controlShock")[1], Symbol("t value")])
       push!(fitness["interaction_tstat"], regDF[findall(regDF[:depvar].=="VWret_ptf & newsShock")[1], Symbol("t value")])
    elseif WS=="EW"
        push!(fitness["ret_tstat"], regDF[findall(regDF[:depvar].=="EWret_ptf & newsShock")[1], Symbol("t value")])
        push!(fitness["ret_tstat_simple"], regDF[findall(regDF[:depvar].=="EWret_ptf & controlShock")[1], Symbol("t value")])
        push!(fitness["interaction_tstat"], regDF[findall(regDF[:depvar].=="EWret_ptf & newsShock")[1], Symbol("t value")])
    end
    return fitness
end




function OLScoeftableToDF(crttable)
    crttable = coeftable(crttable)
    depvars = crttable.rownms
    crtcolnames = crttable.colnms
    resDF = depvars
    for i in 1:length(crttable.cols)
        resDF = hcat(resDF, crttable.cols[i])
    end
    resDF = convert(DataFrame, resDF)
    names!(resDF, [[:depvar]; [Symbol(x) for x in crtcolnames]])
    return resDF
end
