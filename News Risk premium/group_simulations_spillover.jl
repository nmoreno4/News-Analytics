using JLD2, CSV, Random
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")
include("$(laptop)/DescriptiveStats/helpfcts.jl")
include("$(laptop)/News Risk premium/interactionfunctions.jl")
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"

nbSim, nbBuckets = 10, 10
shufflerate = 0.5
data = aggDicFreq[1]
sort!(data, [:permno, :perid])
data[:rawnewsstrength] = abs.(data[:sum_perSent_])
data[:rawnewsstrength] = replace(data[:rawnewsstrength], NaN=>0)
data = data[data[:sizedecile].>8,:]
data[:provptf] = 0
permnolist = sort(collect(Set(data[:permno])))
split_ranges = partition_array_indices(length(permnolist),Int(ceil(length(permnolist)/nbBuckets)))

permnoranksovertime = Dict()
for i in permnolist
    permnoranksovertime[i] = []
end

interactionFitnessOverTime = Dict()
R2FitnessOverTime = Dict()
for i in 1:nbBuckets
    interactionFitnessOverTime[i] = []
    R2FitnessOverTime[i] = []
end

Results = siminteractionptfs(data, nbSim, R2FitnessOverTime, interactionFitnessOverTime, permnoranksovertime, permnolist, split_ranges, nbBuckets,  interactionvar = :rawnewsstrength_v, WS = "VW", control = :rawnewsstrength_lom, relcoveragetype = 1)
