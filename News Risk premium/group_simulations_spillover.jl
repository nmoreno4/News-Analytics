using JLD2, CSV, Random
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")
include("$(laptop)/DescriptiveStats/helpfcts.jl")
include("$(laptop)/News Risk premium/interactionfunctions.jl")
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"

nbSim, nbBuckets = 50, 20
shufflerate = 0.9
data = aggDicFreq[1]
sort!(data, [:permno, :perid])
data[:rawnewsstrength] = abs.(data[:sum_perSent_])
data[:rawnewsstrength] = replace(data[:rawnewsstrength], NaN=>0)
# data = data[data[:sizedecile].>8,:]
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

Results1 = siminteractionptfs(shufflerate, data, nbSim, R2FitnessOverTime, interactionFitnessOverTime, permnoranksovertime, permnolist, split_ranges, nbBuckets,  interactionvar = :rawnewsstrength_v, WS = "VW", control = :rawnewsstrength_lom, relcoveragetype = 1)


Rplot(convert(Array{Float64}, Results[3][20]))

JLD2.@load "/run/media/nicolas/Research/decileheuristicinteraction.jld2"
JLD2.@load "/run/media/nicolas/Research/decileheuristicinteraction2.jld2"


stockclassifications = Results1[1]

meanforpercentile = Float64[]
for (stock, ranks) in stockclassifications
    push!(meanforpercentile, mean(ranks))
end
percstocks = Dict()
for i in 10:10:100
    percstocks[i] = []
end
for (stock, ranks) in stockclassifications
    for i in 10:10:100
        if mean(ranks) < percentile(meanforpercentile, i)
            push!(percstocks[i], stock)
            break
        end
    end
end
@rput meanforpercentile
R"hist(meanforpercentile)"

ptfDict = Dict()
for i in [10,50,100]
    foo = isin(data[:permno],percstocks[i])
    ptfDict[i] = data[convert(Array{Bool},foo),:]
end

chosenvars = [:cumret]
newcols = [Symbol("w_$(x)") for x in chosenvars]
high = EW_VW_series(ptfDict[100], newcols, chosenvars)
low = EW_VW_series(ptfDict[10], newcols, chosenvars)
medium = EW_VW_series(ptfDict[50], newcols, chosenvars)

print("high -- VW : $(mean(high[:VW_cumret])*sqrt(252))  -  EW : $(mean(high[:EW_cumret])*sqrt(252)) \n")
print("medium -- VW : $(mean(medium[:VW_cumret])*sqrt(252))  -  EW : $(mean(medium[:EW_cumret])*sqrt(252)) \n")
print("low -- VW : $(mean(low[:VW_cumret])*sqrt(252))  -  EW : $(mean(low[:EW_cumret])*sqrt(252)) \n")

function isin(X, Y)
    boolvec = zeros(length(X))
    i=0
    for x in X
        i+=1
        if i == 1000000
            print(i)
        end
        if x in Y
            boolvec[i] = 1
        else
            boolvec[i] = 0
        end
    end
    return boolvec
end
