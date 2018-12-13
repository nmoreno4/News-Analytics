using JLD2, CSV, Random, RCall
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")
include("$(laptop)/DescriptiveStats/helpfcts.jl")
include("$(laptop)/News Risk premium/interactionfunctions.jl")
include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")

freq = Dates.day
tdperiods = (1,3776)
# "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/simple_HML_Dates.day_(1, 3776).jld2"
HMLDic = deepcopy(aggDicFreq)

@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"

baker = CSV.read("/run/media/nicolas/Research/Data/baker_sentiment.csv")
names(baker)

chosenvars = [:sum_perSent_, :sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES]
HMLsuprs = HMLspreads(HMLDic, chosenvars, "VW", true)
FFfactors = CSV.read("/run/media/nicolas/Research/FF/dailyFactors.csv")[1:3776,:]
todate = x -> Date(string(x),"yyyymmdd")
dates = todate.(FFfactors[:Date])
ymonth = Dates.yearmonth.(dates)
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


dailyseries = CSV.read("/run/media/nicolas/Research/provdailyseries.csv")
dailyseries[:date] = ymonth
dailyseries = hcat(DataFrame(Dict("date"=>ymonth)), DataFrame(HMLsuprs), DataFrame(mktSurp))
a = by(dailyseries, :date) do df
    res = Dict()
    # for i in names(dailyseries)[2:end]
    #     res[i] = cumret(df[i])
    # end
    res[:HMLsent] = custom_sum(df[:HML_VW_sum_perSent_]) ./ custom_sum(df[:HML_VW_sum_perNbStories_])
    res[:surpHML] = custom_mean(df[:surpHML_ALL_RES_60_5])
    res[:surpMkt] = custom_mean(df[Symbol("LT60|aggSent__ST5|aggSent_RES")])
    DataFrame(res)
end

a = a[1:155,:]
baker[:HMLsent] = a[:HMLsent]
baker[:surpHML] = a[:surpHML]
baker[:surpMkt] = a[:surpMkt]
baker[:HMLsentDIFF] = vcat(0, baker[:HMLsent][2:end]-baker[:HMLsent][1:end-1])
baker[:sentDIFF] = vcat(0, baker[:SENT][2:end]-baker[:SENT][1:end-1])
HMLsuprs
mktSurp
stockSurp
@rput baker
R"library(lmtest)"
R"grang = grangertest(SENT ~ surpMkt, order = 4, data = baker)"
@rget grang
2+2


CSV.write("/run/media/nicolas/Research/grangtests.csv", baker)
