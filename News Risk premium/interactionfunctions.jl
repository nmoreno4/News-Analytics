function siminteractionptfs(nbSim, R2FitnessOverTime, interactionFitnessOverTime, permnoranksovertime, permnolist, split_ranges, nbBuckets;  interactionvar = :rawnewsstrength_v, WS = "VW", control = :rawnewsstrength_lom, relcoveragetype = 1)
    for sim in 1:nbSim

        print("$(Dates.format(now(), "HH:MM:SS")) - $sim \n")

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

        permnoranksovertime = assignranktopermno(smalltohighinteractionptf, permnoranksovertime, crtptfcomposition)

        crtAVGrankings = bestrankingstocks(permnoranksovertime, nbBuckets)

        resptfranks, stocksToShuffle = keepXpercOfArrays(crtAVGrankings, shufflerate)
        stocksToShuffle = stocksToShuffle[randperm(length(stocksToShuffle))]

        crtptfcomposition = pushmixedstocks(resptfranks, stocksToShuffle)
        assignmentDict = crtCompositiontoAssignment(crtptfcomposition)

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
        push!(regres["ret_tstat"], res[:coefficients][2,3])
        push!(regres["ret_tstat_simple"], res1[:coefficients][2,3])
        push!(regres["interaction_tstat"], res[:coefficients][4,3])
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
    stockranks = Dict()
    for (permno, ranks) in permnoranksovertime
        push!(allAVGranks, mean(ranks))
        stockranks[permno] = mean(ranks)
    end

    splits = percentile(allAVGranks,collect(0.1:100/nbBuckets:100))
    crtbestrankers = Dict()
    for crtThresh in splits
        crtbestrankers[crtThresh] = []
        stocksIcanRemove = []
        for (permno, meanrank) in stockranks
            if meanrank <= crtThresh
                push!(stocksIcanRemove, permno)
                push!(crtbestrankers[crtThresh], permno)
            end
        end
        for i in stocksIcanRemove
            delete!(stockranks, i)
        end
    end

    return crtbestrankers
end



function keepXpercOfArrays(crtAVGrankings, keepPerc)
    # Cut the arrays to keep x% and create a pool with all the non-selected ones
    stocksToShuffle = []
    for (rank, StockArray) in crtAVGrankings
        idkeep = Int(ceil(length(StockArray)*keepPerc))
        StockArray = StockArray[randperm(length(StockArray))]
        crtAVGrankings[rank] = StockArray[1:idkeep]
        append!(stocksToShuffle, StockArray[(idkeep+1):end])
    end

    return crtAVGrankings, stocksToShuffle
end


function pushmixedstocks(resptfranks, stocksToShuffle)
    for (rank, StockArray) in resptfranks
        usid = length(StockArray)+1
        if usid<length(stocksToShuffle)
            append!(resptfranks[rank], stocksToShuffle[1:length(StockArray)])
            stocksToShuffle = stocksToShuffle[usid:end]
        else
            append!(resptfranks[rank], stocksToShuffle)
        end
    end
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
