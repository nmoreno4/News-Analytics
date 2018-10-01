using PyCall, Statistics, StatsBase
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")

#####################################################################################
########################## User defined variables####################################
#####################################################################################
chosenVars = ["wt", "dailyretadj", "dzielinski_rel50nov24H", "nbStories_rel50nov24H"]
dbname = :Dzielinski
collname = :daily_CRSP_CS_TRNA
#####################################################################################


# Add a function to cumulate sentiment and another to cumulate returns

# Connect to the database
@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]

# Name and define which portfolios to look-up in the Database
ptfs = [["BL", [(1,3), (6,10)]],
        ["BH", [(8,10), (6,10)]],
        ["SL", [(1,3), (1,5)]],
        ["SH", [(8,10), (1,5)]],
        ["M", [(4,7), (1,10)]]]

ptfDic = Dict()
for x in ptfs
    ptfDic[x[1]] = Dict("valR"=>x[2][1], "sizeR"=>x[2][2])
end

resDic = Dict()
@time for spec in ptfDic
    resDic[spec[1]] = queryDB((1,300), chosenVars, spec[2]["valR"], spec[2]["sizeR"], mongo_collection)
    break
end


@time for ptf in ptfDic
    ptfDic[ptf[1]] = merge(ptfDic[ptf[1]], fillptf(ptf[2]["valR"], ptf[2]["sizeR"], "pos_m", "nbStories", 500))
end


@time for ptfPair in [("SH", "BH"), ("SL", "BL"), ("BL", "BH"), ("SL", "SH")]
    ptfDic["$(findFreqCharac(ptfPair))_retVW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "VWret")
    ptfDic["$(findFreqCharac(ptfPair))_sentVW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "VWsent")
    ptfDic["$(findFreqCharac(ptfPair))_retEW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "EWret")
    ptfDic["$(findFreqCharac(ptfPair))_sentEW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "EWsent")
end


ptfDic["VWret"] = marketptf(ptfDic, "VWret")
ptfDic["VWsent"] = marketptf(ptfDic, "VWsent")

using PyPlot
plot(foo["rel_sentClas_m_(1, 2)(3, 4)"])
plot(ret2tick(ptfDic["VWret"]))


using RCall, DataFrames

@rput mydata
R"mod = lm(Mktret~HMLret+SMBret+HMLsent+SMBsent, mydata)"
R"summary(mod)"
