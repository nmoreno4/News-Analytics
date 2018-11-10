chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD", "nbStories_rel100_nov24H_RES", "sent_rel100_nov24H_RES"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,3776) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)

using PyCall, StatsBase, Statistics, NaNMath, RCall, DataFrames, JLD2

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]

bmszdecile = Dict()
for val in 1:10
    @time for sz in 1:10
        bmszdecile[val*100+sz] = queryDB(tdperiods, chosenVars, (val, val), (sz, sz), mongo_collection)
    end
end
JLD2.@save "/home/nicolas/Data/bmszdecile.jld2" bmszdecile

chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD", "nbStories_rel100_nov24H_RES", "sent_rel100_nov24H_RES", "roa", "vol"]
HMLDic = Dict()
@time for spec in ([(1,3), (1,5)], [(1,3), (6,10)], [(8,10), (1,5)], [(8,10), (6,10)], [(4,7), (1,5)], [(4,7), (6,10)])
    print(spec)
    HMLDic[spec] = queryDB(tdperiods, chosenVars, (spec[1][1], spec[1][2]), (spec[2][1], spec[2][2]), mongo_collection)
end
JLD2.@save "/home/nicolas/Data/HMLDic.jld2" HMLDic


chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD", "nbStories_rel100_nov24H_RES", "sent_rel100_nov24H_RES"]
quintileDic = Dict()
for val in 1:5
    @time for sz in 1:5
        quintileDic[val*10+sz] = queryDB(tdperiods, chosenVars, (val*2-1, val*2), (sz*2-1, sz*2), mongo_collection)
    end
end
JLD2.@save "/home/nicolas/Data/quintileDic.jld2" quintileDic


chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "EAD", "nbStories_rel100_nov24H_RES", "sent_rel100_nov24H_RES", "roa", "vol"]
MktDic = Dict()
@time for spec in ([(1,10), (1,10)],)
    MktDic[spec] = queryDB(tdperiods, chosenVars, (spec[1][1], spec[1][2]), (spec[2][1], spec[2][2]), mongo_collection)
end
JLD2.@save "/home/nicolas/Data/MktDic.jld2" MktDic
