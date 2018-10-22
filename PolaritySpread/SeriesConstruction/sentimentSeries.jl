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
tdperiods = (1,3776) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)
sentvar, nbstoriesvar, wtvar, retvar = "sent_rel100_nov24H", "nbStories_rel100_nov24H", "dailywt", "dailyretadj"
perlength = 5

FFfactors = FFfactors[1:tdperiods[2],:]
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

L_id = idPtf(resDic["ALL"]["dailyretadj"], resDic["SL"]["dailyretadj"], resDic["BL"]["dailyretadj"])
H_id = idPtf(resDic["ALL"]["dailyretadj"], resDic["SH"]["dailyretadj"], resDic["BH"]["dailyretadj"])

#Aggregate id mat

#create big DFs
finalSeriesDic = Dict()
for perlength in [1,5,20,60]
    @time for offset in [0,1,2,3,5,10,20]
        print("perlength: $perlength -/- offset: $offset\n")
        if offset<perlength
            finalSeriesDic["aggseriesDic_p$(perlength)_o$(offset)"] = aggSeriesToDic!(Dict(), resDic, ptfs, sentvar, nbstoriesvar, perlength, offset, wtvar, retvar)
            HMLspreads!(finalSeriesDic["aggseriesDic_p$(perlength)_o$(offset)"])
            finalSeriesDic["FFfactors_p$(perlength)_o$(offset)"] = aggperiod(FFfactors,"dummy", "dummy", perlength, cumret,offset)
            if perlength>1
                delete!(finalSeriesDic["FFfactors_p$(perlength)_o$(offset)"], [:Date_cumret, :subperiod])
                names!(finalSeriesDic["FFfactors_p$(perlength)_o$(offset)"],[Symbol(String(x)[1:end-7]) for x in names(finalSeriesDic["FFfactors_p$(perlength)_o$(offset)"])])
            end
            finalSeriesDic["res_p$(perlength)_o$(offset)"] = DataFrame(finalSeriesDic["aggseriesDic_p$(perlength)_o$(offset)"])
            finalSeriesDic["res_p$(perlength)_o$(offset)"] = hcat(finalSeriesDic["res_p$(perlength)_o$(offset)"], finalSeriesDic["FFfactors_p$(perlength)_o$(offset)"])
        end
    end
end

using JLD2
JLD2.@load "/home/nicolas/Data/finalSeriesDic.jld2" finalSeriesDic
JLD2.@load "/home/nicolas/Data/resDic.jld2" resDic

finalSeriesDicBis = Dict()
for perlength in [1,5,20,60]
    for offset in [0,1,2,3,5,10,20]
        print("perlength: $perlength -/- offset: $offset\n")
        @time if offset<perlength
            finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"] = aggperiod(resDic["ALL"]["dailyretadj"],"dummy", "dummy", perlength, cumret,offset)
            sentMat = aggperiod(resDic["ALL"][sentvar],"dummy", "dummy", perlength, missingsum,offset)
            nbstoriesMat = aggperiod(resDic["ALL"][nbstoriesvar],"dummy", "dummy", perlength, missingsum,offset)
            finalSeriesDicBis["sent_p$(perlength)_o$(offset)"] = replace_nan(convert(Array{Union{Float64, Missing},2}, convert(Array, sentMat) ./ convert(Array, nbstoriesMat)))
            finalSeriesDicBis["L_id_p$(perlength)_o$(offset)"] = aggperiod(L_id,"dummy", "dummy", perlength, missingmax,offset)
            finalSeriesDicBis["H_id_p$(perlength)_o$(offset)"] = aggperiod(H_id,"dummy", "dummy", perlength, missingmax,offset)
        end
    end
end
JLD2.@load "/home/nicolas/Data/finalSeriesDicBis.jld2" finalSeriesDicBis




aggseriesDic = aggSeriesToDic!(Dict(), resDic, ptfs, sentvar, nbstoriesvar, perlength, 0, wtvar, retvar)
aggseriesDic01 = aggSeriesToDic!(Dict(), resDic, ptfs, sentvar, nbstoriesvar, perlength, 1, wtvar, retvar)
aggseriesDic_p1_o0 = aggSeriesToDic!(Dict(), resDic, ptfs, sentvar, nbstoriesvar, 1, 0, wtvar, retvar)
HMLspreads!(aggseriesDic01)
HMLspreads!(aggseriesDic)
HMLspreads!(aggseriesDic_p1_o0)

FFfactors_p5_o0 = aggperiod(FFfactors,"dummy", "dummy", perlength, cumret,0)
FFfactors_p5_o1 = aggperiod(FFfactors,"dummy", "dummy", perlength, cumret,1)
FFfactors_p1_o0 = aggperiod(FFfactors,"dummy", "dummy", 1, cumret,1)
delete!(FFfactors_p5_o0, [:Date_cumret, :subperiod])
delete!(FFfactors_p5_o1, [:Date_cumret, :subperiod])
delete!(FFfactors_p1_o0, [:Date_cumret, :subperiod])
names!(FFfactors_p5_o0,[Symbol(String(x)[1:end-7]) for x in names(FFfactors_p5_o0)])
names!(FFfactors_p5_o1,[Symbol(String(x)[1:end-7]) for x in names(FFfactors_p5_o1)])
names!(FFfactors_p1_o0,[Symbol(String(x)[1:end-7]) for x in names(FFfactors_p1_o0)])

res = DataFrame(aggseriesDic)
res = hcat(res, FFfactors_p5_o0)
res10 = DataFrame(aggseriesDic01)
res10 = hcat(res10, FFfactors_p5_o1)
res1 = DataFrame(aggseriesDic_p1_o0)
res1 = hcat(res1, FFfactors)

foo = Dict("a"=>FFfactors10, "b"=>FFfactors10b)

@rput foo
R"(foo$a$CMA_cumret)"
@rput res1
R"res = monthlyres"
R"mod = lm(res$VWret_L ~ res$VWsent_L + res$VWsent_HML + res$Mkt_RF + res$HML)"
R"mod = lm(res$VWret_L[1:3775] ~ res$VWsent_L[2:3776] + res$VWsent_HML[2:3776] + res$Mkt_RF[2:3776] + res$HML[2:3776])"
R"mod = lm(res$VWret_BL[2:3776] ~ res$VWsent_BL[1:3775])"
R"mod = lm(res$VWret_BL[1:3775] ~ res$VWsent_BL[2:3776])"
R"summary(mod)"
R"ret2tick <- function(vec, startprice){return(Reduce(function(x,y) {x * exp(y)}, vec, init=startprice, accumulate=T))}"
R"plot(ret2tick(res$VWret_BL, 100), type='l')"
R"lines(ret2tick(res$BLVW, 100), type='l', col=2)"
R"lines(ret2tick(res$VWret_BL, 100), type='l', col=3)"
R"lines(ret2tick(res$VWret_BH, 100), type='l', col=4)"
R"plot(ret2tick(res1$VWret_ALL-res1$RF, 100), type='l', col=5)"
R"lines(ret2tick(res1$Mkt_RF, 100), type='l', col=4)"
R"plot(ret2tick(res$HML, 100), type='l', col=1)"
R"plot(ret2tick(res$VWret_HML, 100), type='l', col=4)"
R"plot(ret2tick((res$VWret_BH+res$VWret_SH)/2, 100), type='l', col=1)"
R"lines(ret2tick(res$HvalVW, 100), type='l', col=4)"
R"lines(ret2tick((res$VWret_BL+res$VWret_SL)/2, 100), type='l', col=1)"
R"lines(ret2tick(res$LvalVW, 100), type='l', col=4)"
R"plot(ret2tick(res$VWret_L-res$VWret_H, 100), type='l', col=1)"
R"plot(ret2tick(res$HML, 100), type='l', col=1)"
R"plot(ret2tick(res$VWret_H, 100), type='l', col=1)"
R"lines(ret2tick(res$HvalVW, 100), type='l', col=2)"

cor(res[:Mkt_RF], res[:VWret_ALL]-res[:RF])
cor(res[:VWret_BL], res[:BLVW])
cor(res[:VWret_L], res[:LvalVW])
cor(res[:VWret_H], res[:HvalVW])
cor(res[:VWret_HML], res[:HML])
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
