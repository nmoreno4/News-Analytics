using PyCall, Statistics, StatsBase, DataFramesMeta, NaNMath, RCall, CSV

FFfactors = CSV.read("/home/nicolas/Data/FF/dailyFactors.csv")[1:3776,:]
for row in 1:size(FFfactors, 1)
    for col in 2:size(FFfactors, 2)
        FFfactors[row, col] = FFfactors[row, col]/100
    end
end

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")

#####################################################################################
########################## User defined variables ###################################
#####################################################################################
chosenVars = ["dailywt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,3800) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)
sentvar, nbstoriesvar, wtvar, retvar = "sent_rel100_nov24H", "nbStories_rel100_nov24H", "dailywt", "dailyretadj"
perlength = 1
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
        ["ALL", [(1,10), (1,10)]]]
        # ,
        # ["M", [(4,7), (1,10)]],
        # ["ALL", [(1,10), (1,10)]]]

ptfDic = Dict()
for x in ptfs
    ptfDic[x[1]] = Dict("valR"=>x[2][1], "sizeR"=>x[2][2])
end

resDic = Dict()
@time for spec in ptfDic
    resDic[spec[1]] = queryDB(tdperiods, chosenVars, spec[2]["valR"], spec[2]["sizeR"], mongo_collection)
end

aggseriesDic = aggSeriesToDic!(Dict(), resDic, ptfs, sentvar, nbstoriesvar, perlength, wtvar, retvar)

res = DataFrame(aggseriesDic)
res[:VWret_L] = (res[:VWret_BL].+res[:VWret_SL])/2
res[:VWret_H] = (res[:VWret_BH].+res[:VWret_SH])/2
res = hcat(res, FFfactors)

sentidx, otheridx = findSentColumns(res)


#offset before aggregation!
monthlyres = hcat(aggperiod(res[:,otheridx], "trivial", retvar, 20, cumret),
                  aggperiod(res[:,sentidx], "trivial", retvar, 20, missingsum))
monthlyresoffset5days = hcat(aggperiod(res[5:end,otheridx], "trivial", retvar, 20, cumret),
                  aggperiod(res[5:end,sentidx], "trivial", retvar, 20, missingsum))
#rename columns of offsetted dataframe

@rput monthlyres;
@rput monthlyresoffset5days;
R"res = monthlyres"
R"mod = lm(Mkt_RF_cumret ~ VWsent_ALL_missingsum, data=res)"
R"summary(mod)"
R"ret2tick <- function(vec, startprice){return(Reduce(function(x,y) {x * exp(y)}, vec, init=startprice, accumulate=T))}"
R"plot(ret2tick(res$VWret_SL, 100), type='l')"
R"lines(ret2tick(res$VWret_SH, 100), type='l', col=2)"
R"lines(ret2tick(res$VWret_BL, 100), type='l', col=3)"
R"lines(ret2tick(res$VWret_BH, 100), type='l', col=4)"
R"plot(ret2tick(res$VWret_ALL-res$RF, 100), type='l', col=5)"
R"lines(ret2tick(res$Mkt_RF, 100), type='l', col=4)"
R"plot(ret2tick(res$HML, 100), type='l', col=1)"
R"lines(ret2tick(res$VWret_H-res$VWret_L, 100), type='l', col=4)"
R"plot(ret2tick((res$VWret_BH+res$VWret_SH)/2, 100), type='l', col=1)"
R"lines(ret2tick(res$HvalVW, 100), type='l', col=4)"
R"lines(ret2tick((res$VWret_BL+res$VWret_SL)/2, 100), type='l', col=1)"
R"lines(ret2tick(res$LvalVW, 100), type='l', col=4)"
R"plot(ret2tick(res$VWret_L-res$VWret_H, 100), type='l', col=1)"
R"plot(ret2tick(res$HML, 100), type='l', col=1)"
R"plot(ret2tick(res$VWret_H, 100), type='l', col=1)"
R"lines(ret2tick(res$HvalVW, 100), type='l', col=2)"

cor(monthlyres[:Mkt_RF_cumret], monthlyres[:VWret_ALL_cumret]-monthlyres[:RF_cumret])
cor(res[:VWret_SL], res[:SLVW])
cor(res[:VWret_L], res[:LvalVW])
cor(res[:VWret_H], res[:HvalVW])
cor((res[:VWret_BH].+res[:VWret_SH])/2, res[:HvalVW])
cor((res[:VWret_BH].+res[:VWret_SH])/2 .- (res[:VWret_BL].+res[:VWret_SL])/2, res[:HML])
cor(res[:HvalVW]-res[:LvalVW], res[:HML])
cor(res[:HvalVW]-res[:LvalVW], res[:HML])


# foo, bar = weightsum(wMat, retMat, false);
# foo = ret2tick(VWret)
# @rput foo
# @rput VWsent
# # @rput bar
# R"plot(foo, type='l')"
#
#
# a = [1, 3.5, -1, -2.3]/100
# b = [4,2,-1.3,-0.5]/100
# a = [cumret([1, 3.5]/100), cumret([-1, -2.3]/100)]
# b = [cumret([4,2]/100), cumret([-1.3,-0.5]/100)]
# wa = [1785.0, 1785 ,1785, 1785]
# wb = [1354.0, 1354 ,1354, 1354]
# wa = [1785.0, 1785]
# wb = [1354.0, 1354]
# A = DataFrame([a,b])
# B = DataFrame([wa,wb])
# retMat = convert(Array, A)
# wMat = convert(Array, B)
# VWret, coveredMktCp = weightsum(wMat, retMat, "EW", false)
# ret2tick(VWret)[end]-100
