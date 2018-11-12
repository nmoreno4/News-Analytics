
#Allow for RES and other types of news
#Allow for around EAD

chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,300) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)

using PyCall, StatsBase, Statistics, NaNMath, RCall, DataFrames, JLD, Dates, DataFramesMeta, JLD2

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

id = 41
around_EAD = -2:1:2
quintileDFs[52] = add_aroundEAD!(quintileDFs[52], around_EAD)

operationsDic = Dict()
colnames = Symbol[:retmean, :sentmean]
varnames = Symbol[:dailyretadj, :sent_rel100_nov24H]
operationsDic["means"] = [custom_mean, colnames, varnames]
operationsDic["means"] = [custom_mean, colnames, varnames]
aggper = by(quintileDFs[52], :permno) do df
    # colIDs = Dict()
    res = Dict()
    for i in 1:length(operationsDic["means"][2])
        res[operationsDic["means"][2][i]] = operationsDic["means"][1](df[operationsDic["means"][3][i]])
    end
    DataFrame(res)
end
d = Dict{Symbol,Any}(:a=>5.0,:b=>2,:c=>"Hi!")
@unpack a, c = d

weeklys = Dict()
monthlys = Dict()
quarterlys = Dict()
dailys = Dict()
for freq in [Dates.month, Dates.week, Dates.day]#Dates.quarterofyear,
    @time for ptf in quintileids
        aggDF = aggperiod(quintileDFs[ptf], freq, tdperiods[1], tdperiods[2])

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
        if freq==Dates.week
            weeklys[ptf] = aggDF
        elseif freq==Dates.month
            monthlys[ptf] = aggDF
        elseif freq==Dates.quarterofyear
            quarterlys[ptf] = aggDF
        elseif freq==Dates.day
            dailys[ptf] = aggDF
        end
    end
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_weekly.jld" weeklys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_monthly.jld" monthlys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_quarterly.jld" quarterlys
JLD2.@save "/run/media/nicolas/Research/SummaryStats/Prov/test_quintiles_df_daily.jld" dailys


a = @time EW_VW_series(bar)

using RCall
X = a[:VWsent]
@rput X
R"plot(X)"
