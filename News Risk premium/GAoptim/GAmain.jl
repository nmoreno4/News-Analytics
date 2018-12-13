using JLD2, CSV, Random, DataFrames, StatsBase
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/GAoptim/GAhelp.jl")

@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2" aggDicFreq
data = aggDicFreq[1]
@time sort!(data, [:permno, :perid])
# datab = data[1:12000000,:]

########### GA Parameters ###############
nbBuckets = 20
onlynewsdays = true
LeftOverMarket = true
#########################################


# Create a Dict where each entry contains a list of all rows where a stock/td/... appears
# @time permnoIDs = valueFilterIdxs(:permno, onlynewsdays, data);
@time tdIDs = valueFilterIdxs(:perid, false, data);
td_permno_IDs = Dict()
@time for (td, idxs) in tdIDs
    crtdf = data[idxs,:]
    td_permno_IDs[td] = valueFilterIdxs(:permno, onlynewsdays, crtdf);
end

@time Pop = initialPopulation(permnoIDs, nbBuckets);

ptfdf, mktdf = filtercrtDF(Pop[1], permnoIDs, data, LeftOverMarket)

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
