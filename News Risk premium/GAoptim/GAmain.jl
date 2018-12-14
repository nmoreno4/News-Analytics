using JLD2, CSV, Random, DataFrames, StatsBase, Statistics, DataStructures
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/GAoptim/GAhelp.jl")

@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2" aggDicFreq
data = aggDicFreq[1]
@time sort!(data, [:permno, :perid])

data[:sum_perNbStories_] = replace(data[:sum_perNbStories_], NaN=>0)
data[:sum_perNbStories_] = replace(data[:sum_perNbStories_], missing=>0)
data[:rawnewsstrength] = abs.(data[:sum_perSent_])
data[:rawnewsstrength] = replace(data[:rawnewsstrength], NaN=>0)


@time data = data[isnotmissing.(data[:cumret]),:];
@time data = data[isnotmissing.(data[:wt]),:];

# datab = data[1:12000000,:]

########### GA Parameters ###############
nbBuckets = 20
onlynewsdays = true
LeftOverMarket = false
#########################################


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

Pop = initialPopulation(permnoIDs, nbBuckets);


crtGenerationTS = Dict()
variablestocompute = [:VWsent_ptf, :VWret_ptf, :EWsent_ptf, :EWret_ptf, :coverage_ptf, :rawnewsstrength_ptf,
                      :VWsent_mkt, :VWret_mkt, :EWsent_mkt, :EWret_mkt, :coverage_mkt, :rawnewsstrength_mkt]
for var in variablestocompute
    crtGenerationTS[var] = Array{Float64}(undef, 3776)
end


@time for (td, subdf) in tdIDs
    td = Int(td)
    ptfdf, mktdf = filtercrtDF(Pop[1], td_permno_IDs[td], subdf, LeftOverMarket)
    # print("hey")
    # break
    crtGenerationTS[:VWret_ptf][td] = VWeight(ptfdf, :cumret)
    crtGenerationTS[:VWret_mkt][td] = VWeight(mktdf, :cumret)
    # crtGenerationTS[:EWret_ptf][td] = EWeight(ptfdf, :cumret)
    # crtGenerationTS[:EWret_mkt][td] = EWeight(mktdf, :cumret)
    # crtGenerationTS[:VWsent_ptf][td] = VWeight(ptfdf, :aggSent_)
    # crtGenerationTS[:VWsent_mkt][td] = VWeight(mktdf, :aggSent_)
    # crtGenerationTS[:EWsent_ptf][td] = EWeight(ptfdf, :aggSent_)
    # crtGenerationTS[:EWsent_mkt][td] = EWeight(mktdf, :aggSent_)

    # crtGenerationTS[:coverage_ptf][td] = sum(ptfdf[:sum_perNbStories_])
    # crtGenerationTS[:coverage_mkt][td] = sum(mktdf[:sum_perNbStories_])
    crtGenerationTS[:rawnewsstrength_ptf][td] = sum(ptfdf[:rawnewsstrength])
    crtGenerationTS[:rawnewsstrength_mkt][td] = sum(mktdf[:rawnewsstrength])
end



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
