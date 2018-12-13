using JLD2, CSV, Random
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")
include("$(laptop)/DescriptiveStats/helpfcts.jl")
include("$(laptop)/News Risk premium/interactionfunctions.jl")
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"

nbSim, nbBuckets = 200, 10
shufflerate = 0.9
data = aggDicFreq[1]
sort!(data, [:permno, :perid])
data[:rawnewsstrength] = abs.(data[:sum_perSent_])
data[:rawnewsstrength] = replace(data[:rawnewsstrength], NaN=>0)
data = data[data[:sizedecile].>1,:]
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



FFfactors = CSV.read("/run/media/nicolas/Research/FF/dailyFactors.csv")[1:3776,:]
todate = x -> Date(string(x),"yyyymmdd")
dates = todate.(FFfactors[:Date])
ymonth = Dates.yearmonth.(dates)
months = Dates.month.(dates)
weekdays = Dates.dayname.(dates)
ys = Dates.year.(dates)
my = []
for (i,j,k) in zip(Dates.week.(dates), ys,months)
    push!(my, "$j $k")
end
tokeep = findall(x->x.=="2003 1", my)

cdata = data[data[:perid].>=minimum(tokeep),:]
cdata = data[data[:perid].<=maximum(tokeep),:]

Results = siminteractionptfs(shufflerate, data, nbSim, R2FitnessOverTime, interactionFitnessOverTime, permnoranksovertime, permnolist, split_ranges, nbBuckets,  interactionvar = :rawnewsstrength_v, WS = "VW", control = :rawnewsstrength_lom, relcoveragetype = 1)


Rplot(convert(Array{Float64}, Results[3][20]))
