using JLD2, DataFrames, Dates, CSV, StatsBase, GLM
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

freq = Dates.day
tdperiods = (1,3776)
# "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/simple_HML_Dates.day_(1, 3776).jld2"
HMLDic = deepcopy(aggDicFreq)
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintiles/quintiles_Dates.day_(1, 3776).jld2"

include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
quintileids = [x*10+y for x in 1:5 for y in 1:5]

varsformeans = [:aggSent_RES, :aggSent_, :cumret, :sum_perNbStories_, :sum_perNbStories_RES]
resmats = Dict()
for i in varsformeans
    resmats[i] = ones(Float64, 5,5)
    resmats["sz_timmerman_$(i)"] = Dict()
    resmats["val_timmerman_$(i)"] = Dict()
end
eads = [:EAD, Symbol("aroundEAD-1:1:1")]
resWead = Dict()
for i in eads
    resWead[i] = deepcopy(resmats)
end
for id in quintileids
    val, sz = parse(Int, "$id"[1]), parse(Int, "$id"[2])
    ptfDF = copy(aggDicFreq[id])
    ptfDF = keepgoodcolumns(ptfDF, ["", "RES"])
    for ead in eads
        ptfDF[ead] = replace(ptfDF[ead], missing=>0)
        ptfDF = ptfDF[ptfDF[ead].==1,:]
        for i in varsformeans
            means_stock_sent = by_means(ptfDF, [i], :permno)
            resWead[ead][i][val,sz] = colmeans_to_dic(means_stock_sent)[Symbol("mean_$(i)")]

            means_td_sent = by_means(ptfDF, [i], :perid)
            means_td_sent = daysWNOead(tdperiods, means_td_sent)
            if !(val in keys(resmats["val_timmerman_$(i)"]))
                resWead[ead]["val_timmerman_$(i)"][val] = Dict()
            end
            if !(sz in keys(resmats["sz_timmerman_$(i)"]))
                resWead[ead]["sz_timmerman_$(i)"][sz] = Dict()
            end
            resWead[ead]["sz_timmerman_$(i)"][sz] = concat_ts_timmerman!(means_td_sent, resWead[ead]["sz_timmerman_$(i)"][sz], sz, Symbol("mean_$(i)"))
            resWead[ead]["val_timmerman_$(i)"][val] = concat_ts_timmerman!(means_td_sent, resWead[ead]["val_timmerman_$(i)"][val], val, Symbol("mean_$(i)"))
        end
    end
end
timmermanns = Dict()
for ead in resWead
    for result in ead[2]
        if typeof(result[1])==Symbol
            CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/simplemean_$(result[1])_$(freq)_$(ead[1]).csv", DataFrame(result[2]))
        else
            X = ptfEWmean(result[2])
            @time MR = timmerman(X, 10)
            print(MR)
            timmermanns["$(result[1])_$(ead[1])"] = MR
        end
    end
end


cdf_variable(ptfDF, [:aggSent_, :aggSent_RES], ptf)


foo = buckets_assign(ptfDF, :aggSent_, 10:10:100)


include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")

ptfDF = aggDicFreq[55]
paneldf = @time createPanelDF(ptfDF, HMLDic, ptfvars = [:cumret, :aggSent_])


function panelReg(paneldf)
    @rput paneldf
    R"library(plm)"
    R"E <- pdata.frame(paneldf, index=c('permno', 'perid'))";
    R"mod <- plm(cumret~aggSent_+ ptf_VW_aggSent_ + HML_VW_aggSent_ + Mkt_RF + HML + SMB + Mom, data = E, model = 'within')"
    R"res = summary(mod)"
    R"coeffcols = colnames(summary(mod)$coefficients)"
    R"coeffrows = rownames(summary(mod)$coefficients)"
    @rget res; @rget coeffcols; @rget coeffrows
    res[:coefficients] = DataFrame(res[:coefficients])
    names!(res[:coefficients], Symbol.(coeffcols))
    oldcols = names(res[:coefficients])
    res[:coefficients][:depvars] = coeffrows
    res[:coefficients] = res[:coefficients][[:depvars; oldcols]]
    return res
end




for i in [x*10+y for x in 1:5 for y in 1:5]
    crtRet = EW_VW_series(aggDicFreq[i], [:w_aggSent_, :w_cumret], [Symbol("aggSent_"), :cumret])
    regDF = Dict(:RF=>FFfactors[:RF], :HMLFF=>FFfactors[:HML], :HMLnico=>HML_VW, :HMLsent=>HML_VWsent,
                 :CMA=>FFfactors[:CMA], :RMW=>FFfactors[:RMW], :Mom=>FFfactors[:Mom], :Mkt_rf=>FFfactors[:Mkt_RF],
                 :SMB=>FFfactors[:SMB], :ptfret_rf=>crtRet[:VW_cumret]-FFfactors[:RF], :ptfsent=>crtRet[:VW_aggSent_])
    regDF = DataFrame(regDF)
    print(ols)
end


@rput c
R"library(plm)"
R"E <- pdata.frame(c, index=c('permno', 'perid'))";
R"mod <- plm(cumret~aggSent_+ ptfsent + HMLsent, data = E, model = 'within')"
R"summary(mod)"


function classifynewspolarity(ptfDF, groupvar, percentiles)
    a = by(ptfDF, groupvar) do df
        res = Dict()
        res[Symbol("bp_$(groupvar)")] = percentile(collect(skipmissing(df[var])), percentiles)
        DataFrame(res)
    end
end

bpDict = Dict()
for perc in []
percentile(collect(skipmissing(df[var])), percentiles)




@rput a
R"plot(a)"
classifynewspolarity(ptfDF, [:aggSent_], [0.5])

function sensitivityHML()
end


# 0/ Compute market sentiment
# 1/ Gather Baker sentiment and map it to :perid
# 2/ Gather FF factors and map it to :perid
# 3/ Compute HML sent and map it to :perid
# 4/ Compute ptf sent, coverage, neg sent and pos and map it to :perid
# 5/ Regress ptf sent/ret to 1,2,3,4
# 6/ Conditional on EAD regress ptf sent to 1,2,3,4
# 7/ Regress future (past) sent/ret and regress it against 1,2,3,4
# 8/ Rank ptf in winner/loser high-freq/low-freq = 4 ptfs
# 9/ average (future/past) returns of ptfs in 4
# 10/ Plot cdfs
# 11/ Plot sentiment (low freq) against baker sentiment
# 12/ Plot HML sent against Volumes*price (make assumption that shares out ratio HML stays constant)
# 13/ permno-td observations with news (aggsent)
