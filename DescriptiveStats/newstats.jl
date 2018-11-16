using JLD2, DataFrames, Dates, CSV
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

freq = Dates.quarterofyear
tdperiods = (1,3776)
# "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintiles_Dates.quarterofyear_(1, 3776).jld"

include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
quintileids = [x*10+y for x in 1:5 for y in 1:5]

varsformeans = [:aggSent_RES, :aggSent_, :cumret, :sum_perNbStories_, :sum_perNbStories_RES]
resmats = Dict()
for i in varsformeans
    resmats[i] = ones(Float64, 5,5)
    resmats["sz_timmerman_$(i)"] = Dict()
    resmats["val_timmerman_$(i)"] = Dict()
end
for id in quintileids
    val, sz = parse(Int, "$id"[1]), parse(Int, "$id"[2])
    ptfDF = copy(aggDicFreq[id])
    ptfDF = keepgoodcolumns(ptfDF, ["", "RES"])
    for i in varsformeans
        means_stock_sent = by_means(ptfDF, [i], :permno)
        resmats[i][val,sz] = colmeans_to_dic(means_stock_sent)[Symbol("mean_$(i)")]

        means_td_sent = by_means(ptfDF, [i], :perid)
        if val in keys(resmats["val_timmerman_$(i)"])
            resmats["val_timmerman_$(i)"][val] = Dict()
        end
        if sz in keys(resmats["sz_timmerman_$(i)"])
            resmats["sz_timmerman_$(i)"][val] = Dict()
        end

        resmats["sz_timmerman_$(i)"][sz] = concat_ts_timmerman!(means_td_sent, sz_timmerman, sz, Symbol("mean_$(i)"))
        resmats["val_timmerman_$(i)"][val] = concat_ts_timmerman!(means_td_sent, val_timmerman, val, Symbol("mean_$(i)"))
    end
end
timmermanns = Dict()
for result in resmats
    if typeof(result[1])==Symbol
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/simplemean_$(result[1])_$(freq).csv", DataFrame(result[2]))
    else
        X = ptfEWmean(result[2])
        MR = timmerman(X)
        timmermanns["$(result[1])"] = MR
    end
end
X = ptfEWmean(sz_timmerman)
MR = timmerman(X)


a = @time EW_VW_series(ptfDF, [:w_aggSent_, :w_cumret], [Symbol("aggSent_-120_-60"), :ret_0_120])
