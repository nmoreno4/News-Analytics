args = ["local", "all", "_"]
args = map(x->x, ARGS)
if args[1]=="CECI"
  push!(LOAD_PATH, "$(pwd())/RelVGnews/myModules")
end
using helperFunctions
rootpath, datarootpath, logpath = loadPaths(args[1])
using Plots, Mongo, JLD2, databaseQuerer, dataframeFunctions, functionsCRSP, nanHandling, TSfunctions

Specification = defineSpec(args[2], args[3])

yStart, yEnd = (2003,1,1), (2017,7,1)

tFrequence = Dates.Day(1)

client = MongoClient()
CRSPconnect = MongoCollection(client, "NewsDB", "dailyCRSP")
mat = 0
chosenIdx = 0
spec=Specification[1]
for spec in Specification
print("$spec \n")
factor = spec[1]
quintile = spec[2]
mat, PERMNOs, dates = createreturnsmatrix(CRSPconnect, factor, quintile, yStart, yEnd, tFrequence)
mat, keptrows = removeonlyNaNrows(mat)
rebalanceIdx = rebalancingDatesIdx(dates[keptrows])
chosenIdx = idxWithData(mat, rebalanceIdx)
chosenIdxbis = idxWithDatabis(mat, 1:length(keptrows))

mkpath("$datarootpath/CRSP/$tFrequence")
if quintile == ["H", "M", "L"]
  JLD2.@save "$datarootpath/CRSP/$tFrequence/AllStocks.jld2" mat PERMNOs dates keptrows chosenIdx
else
  JLD2.@save "$datarootpath/CRSP/$tFrequence/$(factor)_$(quintile).jld2" chosenIdx
end
end #for ptype
