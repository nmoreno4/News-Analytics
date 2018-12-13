using Distributed


function siminteractionptfs(shufflerate, data, nbSim, R2FitnessOverTime, interactionFitnessOverTime, permnoranksovertime, permnolist, split_ranges, nbBuckets;  interactionvar = :rawnewsstrength_v, WS = "VW", control = :rawnewsstrength_lom, relcoveragetype = 1)
    crtptfcomposition = Dict()
    assignmentDict = Dict()
    dcr = shufflerate/nbSim
    for sim in 1:nbSim

        if sim != nbSim
            shufflerate -= dcr
        end


        print("$(Dates.format(now(), "HH:MM:SS")) - Sim: $sim \n")

        if sim==1
            crtptfcomposition = Dict()
            for i in 1:nbBuckets
                crtptfcomposition[i] = []
            end
            assignmentDict = permno_rand_ptf_assignemnt(permnolist, split_ranges)
            for row in 1:size(data,1)
                data[row, :provptf] = assignmentDict[Int(data[row,:permno])]
            end
            for (permno,ptf) in assignmentDict
                push!(crtptfcomposition[ptf], permno)
            end
        end

        allptfs = ptf_TS(nbBuckets, data, :provptf, focusonNewsdaysonly = true)

        regres = regptfspill(allptfs, nbBuckets, interactionvar, WS, control = control, relcoveragetype = relcoveragetype)

        R2gain = regres["R2_1"] .- regres["R2_2"]
        smalltohighR2gainptf = sortperm(R2gain)
        R2FitnessOverTime = addcrtfitness(R2FitnessOverTime, smalltohighR2gainptf, R2gain)

        smalltohighinteractionptf = sortperm(regres["interaction_tstat"])
        interactionFitnessOverTime = addcrtfitness(interactionFitnessOverTime, smalltohighinteractionptf, regres["interaction_tstat"])

        Rplot(interactionFitnessOverTime[nbBuckets] .- interactionFitnessOverTime[1])
        # R2l_plot(convert(Array{Float64}, interactionFitnessOverTime[nbBuckets]), convert(Array{Float64}, interactionFitnessOverTime[1]))

        permnoranksovertime = assignranktopermno(smalltohighR2gainptf, permnoranksovertime, crtptfcomposition)

        crtAVGrankings = bestrankingstocks(permnoranksovertime, nbBuckets)

        resptfranks, stocksToShuffle = keepXpercOfArrays(crtAVGrankings, shufflerate)

        stocksToShuffle = stocksToShuffle[randperm(length(stocksToShuffle))]

        crtptfcomposition = pushmixedstocks(resptfranks, stocksToShuffle)

        assignmentDict = crtCompositiontoAssignment(crtptfcomposition)

        for row in 1:size(data,1)
            data[row, :provptf] = assignmentDict[Int(data[row,:permno])]
        end



    end
    return permnoranksovertime, R2FitnessOverTime, interactionFitnessOverTime
end


function permno_rand_ptf_assignemnt(permnolist, split_ranges)
    crtsort = randperm(length(permnolist))
    assignmentDict = Dict()
    rank = 0
    for crtrange in split_ranges
        rank += 1
        for randid in crtrange
            assignmentDict[permnolist[crtsort[randid]]] = rank
        end
    end
    return assignmentDict
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







function ptf_TS(nbBuckets, data, anomaly; focusonNewsdaysonly = true)
    allptfs = Dict()
    for thresh in 1:nbBuckets
        @time byday = by(data, :perid) do df
            df = df[isnotmissing.(df[anomaly]), :]
            res = Dict()

            v = df[df[anomaly].==thresh,:]

            if focusonNewsdaysonly
                v = v[isnotmissing.(v[:sum_perNbStories_]),:]
                vwithoutnews = v[ismissing.(v[:sum_perNbStories_]),:]
            end
            res[:VWret_v] = VWeight(v, :cumret)
            res[:VWsent_v] = VWeight(v, :aggSent_)
            res[:EWret_v] = EWeight(v, :cumret)
            res[:EWsent_v] = EWeight(v, :aggSent_)
            res[:coverage_v] = sum(v[:sum_perNbStories_])
            res[:rawnewsstrength_v] = custom_sum(v[:rawnewsstrength])
            res[:VWnewsstrength_v] = VWeight(v, :rawnewsstrength)
            res[:EWnewsstrength_v] = EWeight(v, :rawnewsstrength)

            lom = df[df[anomaly].!=thresh,:]

            if focusonNewsdaysonly
                lom = vcat(lom, vwithoutnews)
            end

            res[:VWret_lom] = VWeight(lom, :cumret)
            res[:VWsent_lom] = VWeight(lom, :aggSent_)
            res[:EWret_lom] = EWeight(lom, :cumret)
            res[:EWsent_lom] = EWeight(lom, :aggSent_)
            res[:coverage_lom] = custom_sum(lom[:sum_perNbStories_])
            res[:rawnewsstrength_lom] = custom_sum(lom[:rawnewsstrength])
            res[:VWnewsstrength_lom] = VWeight(lom, :rawnewsstrength)
            res[:EWnewsstrength_lom] = EWeight(lom, :rawnewsstrength)
            DataFrame(res)
        end
        allptfs[thresh] = byday
    end
    return allptfs
end




function regptfspill(allptfs, nbBuckets, newsShockVar, WS ; control = :rawnewsstrength_lom, relcoveragetype = 1)
    regres = Dict("ret_tstat_simple" => Float64[], "R2_1" => Float64[], "R2_2" => Float64[], "ret_tstat" => Float64[], "interaction_tstat" => Float64[])
    for i in 1:nbBuckets
        byday = allptfs[i]

        if relcoveragetype==1
            byday[:relcoverage] = byday[:rawnewsstrength_v] ./ byday[:rawnewsstrength_lom]
        elseif relcoveragetype==2newsShockVar
            byday[:relcoverage] = byday[:coverage_v] ./ byday[:coverage_lom]
        end

        byday[:newsShock] = byday[newsShockVar]
        byday[:controlShock] = byday[control]
        @rput byday
        if WS == "VW"
            R"mod = lm(VWret_lom ~ VWret_v + VWret_v:newsShock + controlShock, data=byday)"
            R"mod1 = lm(VWret_lom ~ VWret_v, data=byday)"
        elseif WS=="EW"
            R"mod = lm(EWret_lom ~ EWret_v + EWret_v:newsShock + controlShock, data=byday)"
            R"mod1 = lm(EWret_lom ~ EWret_v, data=byday)"
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
            print(byday[:VWret_lom])
            print(byday[:VWret_v])
            error(res[:coefficients])
        end
    end
    return regres
end



function assignranktopermno(ptfRank, permnoranksovertime, crtptfcomposition)
    rank = 0
    for j in ptfRank
        rank+=1
        for permno in crtptfcomposition[j]
            push!(permnoranksovertime[permno], rank)
        end
    end
    return permnoranksovertime
end



function bestrankingstocks(permnoranksovertime, nbBuckets)
    allAVGranks = Float64[]
    stockranks, crtbestrankers = splitEqualDicbyVal(permnoranksovertime, nbBuckets)

    for (permno, ranks) in permnoranksovertime
        push!(allAVGranks, mean(ranks))
    end
    @rput allAVGranks
    # R"hist(allAVGranks)"

    return crtbestrankers
end



function keepXpercOfArrays(crtAVGrankings, keepPerc)
    # Cut the arrays to keep x% and create a pool with all the non-selected ones
    keepPerc = 1-keepPerc
    stocksToShuffle = []
    for (rank, StockArray) in crtAVGrankings
        idkeep = Int(round(length(StockArray)*keepPerc))
        StockArray = StockArray[randperm(length(StockArray))]
        crtAVGrankings[rank] = StockArray[1:idkeep]
        append!(stocksToShuffle, StockArray[(idkeep+1):end])
    end

    return crtAVGrankings, stocksToShuffle
end


function pushmixedstocks(resptfranks, stocksToShuffle)
    piecesofstockstoshuffle = partition_array_indices(length(stocksToShuffle), Int(round(length(stocksToShuffle)/length(keys(resptfranks)))) )
    print("\n i0: $(length(piecesofstockstoshuffle))  -  $(length(keys(resptfranks))) \n")
    i = 0
    for (rank, StockArray) in resptfranks
        i+=1
        crtstockstoadd = stocksToShuffle[piecesofstockstoshuffle[i]]
        append!(resptfranks[rank], crtstockstoadd)
    end
    print("\n i: $i  -  $(length(keys(resptfranks))) \n")
    return resptfranks
end


function crtCompositiontoAssignment(crtptfcomposition)
    assignmentDict = Dict()
    for (rank, permnos) in crtptfcomposition
        for permno in permnos
            assignmentDict[permno] = Int(rank)
        end
    end
    return assignmentDict
end



function addcrtfitness(FitnessOverTime, rankerptf, crtfitness)
    i=0
    for r in rankerptf
        i+=1
        push!(FitnessOverTime[i], crtfitness[r])
    end
    return FitnessOverTime
end



function percpermnoranksovertime(permnoranksovertime)
    avgranksovertime = Float64[]
    for (permno, ranksovertime) in permnoranksovertime
        push!(avgranksovertime, mean(ranksovertime))
    end
    return avgranksovertime
end


"""
Assume that the lowest value is the END of the first bucket and the highest value is
the END of the last bucket
"""
function assignToBucket(val, splitranksA)
    Res = 0
    splitranks = copy(splitranksA)
    pushfirst!(splitranks, -999999999)
    for i in 2:length(splitranks)
        if splitranks[i-1] < val <= splitranks[i]
            Res = Int(i-1)
            break
        end
    end
    return Res
end




"""
a: permnoranksovertime Dict
"""
function splitEqualDicbyVal(a, nbSplits)
    stockranks = Dict()
    crtbestrankers = Dict()
    b = DataFrame(Dict("keys"=>collect(keys(a)), "vals"=>collect(mean.(values(a)))))
    sort!(b, :vals)
    sortedkeys = b[:keys]
    splitranges = partition_array_indices(length(sortedkeys), Int(ceil(length(sortedkeys)/nbSplits)))
    rank = 0
    for ran in splitranges
        rank+=1
        crtbestrankers[rank] = []
        crtdf = b[ran,:]
        for row in 1:size(crtdf,1)
            stockranks[crtdf[row,:keys]] = crtdf[row,:vals]
            push!(crtbestrankers[rank], crtdf[row,:keys])
        end
    end
    return stockranks, crtbestrankers
end
