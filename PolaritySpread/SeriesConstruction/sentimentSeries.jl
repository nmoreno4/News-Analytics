using PyCall, Statistics, StatsBase, DataFramesMeta, NaNMath, RCall
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")

#####################################################################################
########################## User defined variables ###################################
#####################################################################################
chosenVars = ["wt", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,3778) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)
sentvar, nbstoriesvar = "sent_rel100_nov24H", "nbStories_rel100_nov24H"
perlength = 5
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
        ["SH", [(8,10), (1,5)]]]
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


ptf = "BL"

sentMat = replace_nan(subperiodCol(resDic[ptf][sentvar], perlength));
sentMat = aggregate(sentMat, :subperiod, [missingsum]);

nbstoriesMat = replace_nan(subperiodCol(resDic[ptf][nbstoriesvar], perlength));
nbstoriesMat = aggregate(nbstoriesMat, :subperiod, [missingsum]);

wMat = replace_nan(subperiodCol(resDic[ptf]["wt"], perlength));
wMat = aggregate(wMat, :subperiod, [missingmean]);

retMat = replace_nan(subperiodCol(resDic[ptf]["dailyretadj"], perlength));
retMat = aggregate(retMat, :subperiod, [cumret]);

for cdf in (sentMat, nbstoriesMat, wMat, retMat)
    delete!(cdf, :subperiod)
end

sentMat = replace_nan(convert(Array{Union{Float64, Missing},2}, convert(Array, sentMat) ./ convert(Array, nbstoriesMat)))
wMat = convert(Array, wMat)
retMat = convert(Array, retMat)

VWsent, coveredMktCp = weightsum(wMat, sentMat, "VW", false)
VWret, coveredMktCp = weightsum(wMat, retMat, "VW", false)

EWsent, coveredMktCp = weightsum(wMat, sentMat, "EW", true)
EWret, coveredMktCp = weightsum(wMat, retMat, "EW", true)

# foo, bar = weightsum(wMat, retMat, false);
foo = ret2tick(VWret)
@rput foo
@rput VWsent
# @rput bar
R"plot(foo, type='l')"


a = [1, 3.5, -1, -2.3]/100
b = [4,2,-1.3,-0.5]/100
a = [cumret([1, 3.5]/100), cumret([-1, -2.3]/100)]
b = [cumret([4,2]/100), cumret([-1.3,-0.5]/100)]
wa = [1785.0, 1785 ,1785, 1785]
wb = [1354.0, 1354 ,1354, 1354]
wa = [1785.0, 1785]
wb = [1354.0, 1354]
A = DataFrame([a,b])
B = DataFrame([wa,wb])
retMat = convert(Array, A)
wMat = convert(Array, B)
VWret, coveredMktCp = weightsum(wMat, retMat, "EW", false)
ret2tick(VWret)[end]-100
