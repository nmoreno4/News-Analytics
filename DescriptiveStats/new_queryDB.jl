
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
for id in quintileids
    quintileDFs[id] = queryDic_to_df(quintileDic[id], [chosenVars; "permno"; "td"])
end

around_EAD = -1:1:1
for ptf in quintileids
    quintileDFs[ptf] = add_aroundEAD!(quintileDFs[ptf], around_EAD)
end
#Symbol("aroundEAD$(around_EAD)")

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

# weeklys = Dict()
# monthlys = Dict()
# quarterlys = Dict()
# dailys = Dict()
include("$(laptop)/DescriptiveStats/helpfcts.jl")
# for freq in [Dates.quarterofyear,Dates.month,Dates.week, Dates.day]#[Dates.month, Dates.week, Dates.day]##Dates.quarterofyear,
#     print(freq)
#     aggDicFreq = Dict()
#     @time for ptf in quintileids
#         print(ptf)
#         print(Dates.now())
#         aggDF = aggperiod(quintileDFs[ptf], operationsDic, newstopics, freq, tdperiods[1], tdperiods[2])
#
#         tdper = maptd_per(freq, tdperiods[1], tdperiods[2])
#
#         ranges = Dict()
#         if freq == Dates.day
#             eventwindows = ([-5,-1],[1,5])
#         elseif freq==Dates.month
#             eventwindows = ([-40,-20],[1,20])
#         elseif freq==Dates.quarterofyear
#             eventwindows = ([-120,-60],[1,60])
#         elseif freq==Dates.week
#             eventwindows = ([-10,-5],[1,5])
#         end
#
#         #empty mat with only the columns
#         cleanaggDF = aggDF[1,:]
#         deleterows!(cleanaggDF,1)
#
#         for eventwindow in eventwindows
#             for i in aggDF[:perid]
#                 ranges[i] = tdper[i]+eventwindow[1]:tdper[i]+eventwindow[2]
#             end
#             aggDF[Symbol(eventwindow)] = Array{Union{Missing, Float64},1}(missing, length(aggDF[:perid]))
#             cleanaggDF[Symbol(eventwindow)] = Array{Union{Missing, Float64},1}(missing, length(cleanaggDF[:perid]))
#             sort!(aggDF, [:permno, :perid])
#             # foo[:lol] = 0
#             # emptied = foo[1,:]
#             # deleterows!(emptied,1)
#             # for permno in Set(foo[:permno])
#             #     a = @where(foo, :permno .== permno)
#             #     emptied = vcat(emptied, a)
#             # end
#             for crtpermno in Set(quintileDFs[ptf][:permno])
#                 res = Dict()
#                 b = @where(quintileDFs[ptf], :permno .== crtpermno)
#                 for crange in ranges
#                     res[crange[1]] = cumret(@where(b, map(x->x in crange[2], :td))[:dailyretadj])
#                 end
#                 b = @where(aggDF, :permno .== crtpermno)
#                 for eventagg in res
#                     c = @where(b, :perid.==eventagg[1])
#                     c[Symbol(eventwindow)] = eventagg[2]
#                     vcat(cleanaggDF, c)
#                     # aggDF[(aggDF[:perid].==eventagg[1]) .& (aggDF[:permno].==crtpermno), Symbol(eventwindow)] = eventagg[2]
#                 end
#             end
#         end
#         print(Dates.now())
#         aggDicFreq[ptf] = cleanaggDF
#         # if freq==Dates.week
#         #     weeklys[ptf] = aggDF
#         # elseif freq==Dates.month
#         #     monthlys[ptf] = aggDF
#         # elseif freq==Dates.quarterofyear
#         #     quarterlys[ptf] = aggDF
#         # elseif freq==Dates.day
#         #     dailys[ptf] = aggDF
#         # end
#     end
#     JLD2.@save "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld" aggDicFreq
# end


include("$(laptop)/DescriptiveStats/helpfcts.jl")
for freq in [Dates.month, Dates.week]##Dates.quarterofyear,
    aggDicFreq = Dict()
    @time for ptf in quintileids
        print(ptf)
        print(Dates.now())
        aggDF = aggperiod(quintileDFs[ptf], operationsDic, newstopics, freq, tdperiods[1], tdperiods[2])

        tdper = maptd_per(freq, tdperiods[1], tdperiods[2])

        ranges = Dict()
        if freq == Dates.day
            eventwindows = ([-5,-1],[1,5])
        elseif freq==Dates.month
            eventwindows = ([-40,-20],[1,20])
        elseif freq==Dates.quarterofyear
            eventwindows = ([-120,-60],[1,60])
        elseif freq==Dates.week
            eventwindows = ([-10,-5],[1,5])
        end
        for eventwindow in eventwindows
            for i in aggDF[:perid]
                ranges[i] = tdper[i]+eventwindow[1]:tdper[i]+eventwindow[2]
            end
            aggDF[Symbol(eventwindow)] = Array{Union{Missing, Float64},1}(missing, length(aggDF[:perid]))
            sort!(aggDF, [:permno, :perid])
            for crtpermno in Set(quintileDFs[ptf][:permno])
                res = Dict()
                b = @where(quintileDFs[ptf], :permno .== crtpermno)
                for crange in ranges
                    res[crange[1]] = cumret(@where(b, map(x->x in crange[2], :td))[:dailyretadj])
                end
                for eventagg in res
                    # @where(aggDF, (:perid.==eventagg[1]) .& (:permno.==crtpermno))[Symbol(eventwindow)] = eventagg[2]
                    aggDF[(aggDF[:perid].==eventagg[1]) .& (aggDF[:permno].==crtpermno), Symbol(eventwindow)] = eventagg[2]
                end
            end
        end
        print(Dates.now())
        aggDicFreq[ptf] = aggDF
        # if freq==Dates.week
        #     weeklys[ptf] = aggDF
        # elseif freq==Dates.month
        #     monthlys[ptf] = aggDF
        # elseif freq==Dates.quarterofyear
        #     quarterlys[ptf] = aggDF
        # elseif freq==Dates.day
        #     dailys[ptf] = aggDF
        # end
    end
    JLD2.@save "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld" aggDicFreq
end






JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_daily_300.jld" dailys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_weekly_300.jld" weeklys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_monthly_300.jld" monthlys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_quarterly_300.jld" quarterlys

JLD2.@load "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_monthly_300.jld"
monthlys[54][:EAD] = replace(monthlys[54][:EAD], missing=>0)
custom_mean(monthlys[54][(monthlys[54][:EAD].==1), :aggSent_])

include("$(laptop)/DescriptiveStats/helpfcts.jl")
a = @time EW_VW_series(monthlys[43], [:w_aggSent_, :w_cumret, :w_aggCov], [:aggSent_, :cumret, :sum_perNbStories_])

using RCall
X = a[:VWsent]
@rput X
R"plot(X)"

for (i,j) in zip([1,1,1], [2,3,4])
    print("$i - $j")
end
