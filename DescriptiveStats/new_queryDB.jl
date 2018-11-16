
#Allow for RES and other types of news
#Allow for around EAD

chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD", "nbStories_rel100_nov24H_RES", "sent_rel100_nov24H_RES"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,3776) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)

using PyCall, StatsBase, Statistics, NaNMath, RCall, DataFrames, JLD, Dates, DataFramesMeta, JLD2, RollingFunctions

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]

quintileDic = Dict()
for val in 1:5
    @time for sz in 1:5
        quintileDic[val*10+sz] = queryDB_doublefilt_Dic(["bmdecile", "sizedecile"], tdperiods, chosenVars, (val*2-1, val*2), (sz*2-1, sz*2), mongo_collection)
    end
end
# JLD.save("/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df.jld", "quintileDic", quintileDic)
# Transform Dic to DF
quintileids = [x*10+y for x in 1:5 for y in 1:5]
quintileDFs = Dict()
@time for id in quintileids
    quintileDFs[id] = queryDic_to_df(quintileDic[id], [chosenVars; "permno"; "td"])
end

around_EAD = -1:1:1
@time for ptf in quintileids
    quintileDFs[ptf] = add_aroundEAD!(quintileDFs[ptf], around_EAD)
end

operationsDic = Dict()
operationsDic["sums"] = [custom_sum_missing,
                            [:sum_perSent_, :sum_perNbStories_, :sum_perSent_RES, :sum_perNbStories_RES],
                            [:sent_rel100_nov24H, :nbStories_rel100_nov24H, :sent_rel100_nov24H_RES, :nbStories_rel100_nov24H_RES]]
operationsDic["lastels"] = [getlast,
                            [:permno, :wt, :perid],
                            [:permno, :dailywt, :perid]]
operationsDic["cumrets"] = [cumret,
                            [:cumret],
                            [:dailyretadj]]
operationsDic["maxs"] = [custom_max,
                            [:EAD, Symbol("aroundEAD$(around_EAD)")],
                            [:EAD, Symbol("aroundEAD$(around_EAD)")]]
newstopics = ["", "RES"] #["", "RES"]

dfvars = (:dailyretadj, (:sent_rel100_nov24H, :nbStories_rel100_nov24H), (:sent_rel100_nov24H_RES, :nbStories_rel100_nov24H_RES))

include("$(laptop)/DescriptiveStats/helpfcts.jl")
aggDicFreq = Dict()
for freq in [Dates.week]##Dates.quarterofyear,Dates.quarterofyear, Dates.month, Dates.week,
    print(freq)
    if freq == Dates.day
        eventWindows = Dict([-1,0]=>dfvars,
                            [-2,-1]=>dfvars,
                            [-3,-1]=>dfvars,
                            [-4,-1]=>dfvars,
                            [-5,-1]=>dfvars,
                            [1,2]=>dfvars,
                            [1,3]=>dfvars,
                            [1,4]=>dfvars,
                            [1,5]=>dfvars)
    elseif freq==Dates.month
        eventWindows = Dict([-40,-20]=>dfvars,
                            [-60,-20]=>dfvars,
                            [1,20]=>dfvars,
                            [20,40]=>dfvars,
                            [20,60]=>dfvars)
    elseif freq==Dates.quarterofyear
        eventWindows = Dict([-120,-60]=>dfvars,
                            [0,60]=>dfvars,
                            [0,120]=>dfvars)
    elseif freq==Dates.week
        eventWindows = Dict([-10,-5]=>dfvars,
                            [-15,-5]=>dfvars,
                            [0,3]=>dfvars,
                            [0,5]=>dfvars,
                            [0,10]=>dfvars)
    end
    @time for ptf in quintileids
        print("\n $ptf - ")
        print(Dates.format(now(), "HH:MM"))
        @time aggDF = aggperiod(quintileDFs[ptf], operationsDic, newstopics, freq, tdperiods[1], tdperiods[2])

        @time aggDF = addEvents(aggDF, freq, tdperiods, eventWindows, ptf)

        print(Dates.format(now(), "HH:MM"))
        aggDicFreq[ptf] = aggDF
    end
    @time JLD2.@save "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2" aggDicFreq
end


# #Careful: order sentiment -> nbStories matters
# dfvars = (:dailyretadj, (:sent_rel100_nov24H, :nbStories_rel100_nov24H), (:sent_rel100_nov24H_RES, :nbStories_rel100_nov24H_RES))
# eventWindows = Dict([-40,-20]=>dfvars,
#                     [1,19]=>dfvars)
#
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_daily_300.jld" dailys
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_weekly_300.jld" weeklys
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_monthly_300.jld" monthlys
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_quarterly_300.jld" quarterlys
#
# JLD2.@load "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_monthly_300.jld"
# monthlys[54][:EAD] = replace(monthlys[54][:EAD], missing=>0)
# custom_mean(monthlys[54][(monthlys[54][:EAD].==1), :aggSent_])
#
# include("$(laptop)/DescriptiveStats/helpfcts.jl")
# a = @time EW_VW_series(monthlys[43], [:w_aggSent_, :w_cumret, :w_aggCov], [:aggSent_, :cumret, :sum_perNbStories_])
#
# using RCall
# X = a[:VWsent]
# @rput X
# R"plot(X)"
#
# for (i,j) in zip([1,1,1], [2,3,4])
#     print("$i - $j")
# end
#
#
#
#
# macro get(indexing)
#     indexing.head ≠ :. && error("syntax: expected: `d.[ks...]`.")
#     dict = indexing.args[1]
#     indexing.args[1] = :getindex
#     indexing.args[2].head = :tuple
#     pushfirst!(indexing.args[2].args, dict)
#     indexing
# end
