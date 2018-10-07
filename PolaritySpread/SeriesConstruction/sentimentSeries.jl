using PyCall, Statistics, StatsBase, DataFramesMeta, NaNMath
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")

#####################################################################################
########################## User defined variables####################################
#####################################################################################
chosenVars = ["wt", "dailyretadj", "dzielinski_rel50nov24H", "nbStories_rel50nov24H",
              "dzielinski_rel50nov24H_RES", "nbStories_rel50nov24HRES",
              "dzielinski_rel50nov24H_MRG", "nbStories_rel50nov24HMRG",
              "dzielinski_rel50", "nbStories_rel50",
              "dzielinski_simple", "nbStories_total"]
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
    resDic[spec[1]] = queryDB((1,50), chosenVars, spec[2]["valR"], spec[2]["sizeR"], mongo_collection)
    break
end

dziescore = resDic["M"]["dzielinski_rel50nov24H"];
dzieNbstories = resDic["M"]["nbStories_rel50nov24H"];
dzieProper = @time convert(Array, dziescore[:,:]) ./ convert(Array, dzieNbstories[:,:])

countNaN(resDic["M"]["nbStories_rel50nov24HMRG"], true)
countNaN(resDic["M"]["dzielinski_rel50nov24H_RES"], true)
countNaN(resDic["M"]["dzielinski_rel50nov24H"], true)


a = replace_nan(subperiodCol(dziescore, 10));
# use a sum that ignores missing!!
b = aggregate(a, :subperiod, [sum])
a = replace_nan(subperiodCol(dzieNbstories, 50));
c = aggregate(a, :subperiod, [sum]);


function dfColSum(crtDF)
    res = Array{Union{Missing,Float64},1}(missing, size(crtDF, 2))
    for col in 1:size(crtDF, 2)
        res[col] = sum(skipmissing(crtDF[:,col]))
    end
    return res
end



# using PyPlot
# plot(foo["rel_sentClas_m_(1, 2)(3, 4)"])
# plot(ret2tick(ptfDic["VWret"]))
#
#
# using RCall, DataFrames
#
# @rput mydata
# R"mod = lm(Mktret~HMLret+SMBret+HMLsent+SMBsent, mydata)"
# R"summary(mod)"
