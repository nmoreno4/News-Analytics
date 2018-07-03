using Mongo, databaseQuerer, DataFrames, JLD2
timespan = Dates.DateTime(2003,1,1,20,0,0):Dates.DateTime(2017,6,30,20,0,0)
rootpath = "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/Data Inputs"
datarootpath = "/run/media/nicolas/OtherData/home/home/nicolas/Data"
logpath = "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/log"

client = MongoClient()
newsConnect = MongoCollection(client, "NewsDB", "News")
companiesConnect = MongoCollection(client, "NewsDB", "Companies")
allPermIDs = collect(fieldDistinct(companiesConnect, ["permID"])[1])
function tosymbol(el)
    el = Symbol(el)
    return el
end
coltypes = repeat([Float64],inner=[length(allPermIDs)])
symbolPermIDs = unshift!(map(tosymbol, allPermIDs), :Date)
coltypes = unshift!(coltypes, DateTime)

# The market closes at 4pm EST, which is 8pm UTC
function createNAdf(coltypes, symbolPermIDs, timespan)
    NAdf = DataFrame(coltypes, symbolPermIDs, length(timespan))
    NAdf[1:end, 2:end] = NaN
    NAdf[:Date] = timespan
    return NAdf
end
dfSentimentPos = createNAdf(coltypes, symbolPermIDs, timespan)
# dfSentimentNeut = createNAdf(coltypes, symbolPermIDs, timespan)
dfSentimentNeg = createNAdf(coltypes, symbolPermIDs, timespan)
# dfSentimentClas = createNAdf(coltypes, symbolPermIDs, timespan)
# dfRel = createNAdf(coltypes, symbolPermIDs, timespan)
# dfNov24H = createNAdf(coltypes, symbolPermIDs, timespan)
# dfNov7D = createNAdf(coltypes, symbolPermIDs, timespan)
# dfVol24H = createNAdf(coltypes, symbolPermIDs, timespan)
# dfVol7D = createNAdf(coltypes, symbolPermIDs, timespan)
# dfsentClasRel = createNAdf(coltypes, symbolPermIDs, timespan)
# dfsentClasRel = createNAdf(coltypes, symbolPermIDs, timespan)
# dfdiffPosNegRelNeut = createNAdf(coltypes, symbolPermIDs, timespan)
# dfCountStories = createNAdf(coltypes, symbolPermIDs, timespan)
# dftakesCount = createNAdf(coltypes, symbolPermIDs, timespan)
# dfdiffPosNeg = createNAdf(coltypes, symbolPermIDs, timespan)
datedic = Dict()
stock =0
date=0
noPermid = []
tic()
for date in timespan
    toc()
    tic()
    print(date)
    cursor = getAnalyticsCursorAny(newsConnect, date-Dates.Day(1), date)
    storydic = Dict()
    for story in cursor
        anadic = Dict()
        for take in story["takes"]
            for ana in take["analytics"]
                try
                    push!(anadic[Symbol(ana["assetId"])]["sentimentPositive"], ana["sentimentPositive"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentNeutral"], ana["sentimentNeutral"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentNegative"], ana["sentimentNegative"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentClass"], ana["sentimentClass"])
                    push!(anadic[Symbol(ana["assetId"])]["relevance"], ana["relevance"])
                    push!(anadic[Symbol(ana["assetId"])]["novelty24H"], ana["novelty24H"])
                    push!(anadic[Symbol(ana["assetId"])]["novelty7D"], ana["novelty7D"])
                    push!(anadic[Symbol(ana["assetId"])]["volume24H"], ana["volume24H"])
                    push!(anadic[Symbol(ana["assetId"])]["volume7D"], ana["volume7D"])
                    push!(anadic[Symbol(ana["assetId"])]["sentclasRel"], ana["sentimentClass"]*ana["relevance"])
                    push!(anadic[Symbol(ana["assetId"])]["diffPosNeg"], ana["sentimentPositive"]-ana["sentimentNegative"])
                    push!(anadic[Symbol(ana["assetId"])]["diffPosNegRelNeut"], (ana["sentimentPositive"]-ana["sentimentNegative"])*(1-ana["sentimentNeutral"])*ana["relevance"])
                catch
                    anadic[Symbol(ana["assetId"])] = Dict("sentimentPositive"=>[],
                         "sentimentNeutral"=>[],
                         "sentimentNegative"=>[],
                         "sentimentClass"=>[],
                         "relevance"=>[],
                         "novelty24H"=>[],
                         "novelty7D"=>[],
                         "volume24H"=>[],
                         "volume7D"=>[],
                         "sentclasRel"=>[],
                         "diffPosNeg"=>[],
                         "diffPosNegRelNeut"=>[])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentPositive"], ana["sentimentPositive"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentNeutral"], ana["sentimentNeutral"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentNegative"], ana["sentimentNegative"])
                    push!(anadic[Symbol(ana["assetId"])]["sentimentClass"], ana["sentimentClass"])
                    push!(anadic[Symbol(ana["assetId"])]["relevance"], ana["relevance"])
                    push!(anadic[Symbol(ana["assetId"])]["novelty24H"], ana["noveltyCounts"][2]["itemCount"])
                    push!(anadic[Symbol(ana["assetId"])]["novelty7D"], ana["noveltyCounts"][5]["itemCount"])
                    push!(anadic[Symbol(ana["assetId"])]["volume24H"], ana["volumeCounts"][2]["itemCount"])
                    push!(anadic[Symbol(ana["assetId"])]["volume7D"], ana["volumeCounts"][5]["itemCount"])
                    push!(anadic[Symbol(ana["assetId"])]["sentclasRel"], ana["sentimentClass"]*ana["relevance"])
                    push!(anadic[Symbol(ana["assetId"])]["diffPosNeg"], ana["sentimentPositive"]-ana["sentimentNegative"])
                    push!(anadic[Symbol(ana["assetId"])]["diffPosNegRelNeut"], (ana["sentimentPositive"]-ana["sentimentNegative"])*(1-ana["sentimentNeutral"])*ana["relevance"])
                end
            end
        end
        for take in anadic
            ana = take[1]
            try
                push!(storydic[Symbol(ana)]["sentimentPositive"], mean(anadic[Symbol(ana)]["sentimentPositive"]))
                push!(storydic[Symbol(ana)]["sentimentNeutral"], mean(anadic[Symbol(ana)]["sentimentNeutral"]))
                push!(storydic[Symbol(ana)]["sentimentNegative"], mean(anadic[Symbol(ana)]["sentimentNegative"]))
                push!(storydic[Symbol(ana)]["sentimentClass"], mean(anadic[Symbol(ana)]["sentimentClass"]))
                push!(storydic[Symbol(ana)]["relevance"], mean(anadic[Symbol(ana)]["relevance"]))
                push!(storydic[Symbol(ana)]["novelty24H"], mean(anadic[Symbol(ana)]["novelty24H"]))
                push!(storydic[Symbol(ana)]["novelty7D"], mean(anadic[Symbol(ana)]["novelty7D"]))
                push!(storydic[Symbol(ana)]["volume24H"], mean(anadic[Symbol(ana)]["volume24H"]))
                push!(storydic[Symbol(ana)]["volume7D"], mean(anadic[Symbol(ana)]["volume7D"]))
                push!(storydic[Symbol(ana)]["sentclasRel"], mean(anadic[Symbol(ana)]["sentclasRel"]))
                push!(storydic[Symbol(ana)]["diffPosNeg"], mean(anadic[Symbol(ana)]["diffPosNeg"]))
                push!(storydic[Symbol(ana)]["diffPosNegRelNeut"], mean(anadic[Symbol(ana)]["diffPosNegRelNeut"]))
                push!(storydic[Symbol(ana)]["takesCount"], length(anadic[Symbol(ana)]["diffPosNegRelNeut"]))
            catch
                storydic[Symbol(ana)] = Dict("sentimentPositive"=>[],
                     "sentimentNeutral"=>[],
                     "sentimentNegative"=>[],
                     "sentimentClass"=>[],
                     "relevance"=>[],
                     "novelty24H"=>[],
                     "novelty7D"=>[],
                     "volume24H"=>[],
                     "volume7D"=>[],
                     "diffPosNeg"=>[],
                     "sentclasRel"=>[],
                     "diffPosNegRelNeut"=>[],
                     "takesCount"=>[])
                     push!(storydic[Symbol(ana)]["sentimentPositive"], mean(anadic[Symbol(ana)]["sentimentPositive"]))
                     push!(storydic[Symbol(ana)]["sentimentNeutral"], mean(anadic[Symbol(ana)]["sentimentNeutral"]))
                     push!(storydic[Symbol(ana)]["sentimentNegative"], mean(anadic[Symbol(ana)]["sentimentNegative"]))
                     push!(storydic[Symbol(ana)]["sentimentClass"], mean(anadic[Symbol(ana)]["sentimentClass"]))
                     push!(storydic[Symbol(ana)]["relevance"], mean(anadic[Symbol(ana)]["relevance"]))
                     push!(storydic[Symbol(ana)]["novelty24H"], mean(anadic[Symbol(ana)]["novelty24H"]))
                     push!(storydic[Symbol(ana)]["novelty7D"], mean(anadic[Symbol(ana)]["novelty7D"]))
                     push!(storydic[Symbol(ana)]["volume24H"], mean(anadic[Symbol(ana)]["volume24H"]))
                     push!(storydic[Symbol(ana)]["volume7D"], mean(anadic[Symbol(ana)]["volume7D"]))
                     push!(storydic[Symbol(ana)]["diffPosNeg"], mean(anadic[Symbol(ana)]["diffPosNeg"]))
                     push!(storydic[Symbol(ana)]["sentclasRel"], mean(anadic[Symbol(ana)]["sentclasRel"]))
                     push!(storydic[Symbol(ana)]["diffPosNegRelNeut"], mean(anadic[Symbol(ana)]["diffPosNegRelNeut"]))
                     push!(storydic[Symbol(ana)]["takesCount"], length(anadic[Symbol(ana)]["diffPosNegRelNeut"]))
            end
        end
    end
    for permID in storydic
        try
            dfSentimentPos[dfSentimentPos[:Date].==date, permID[1]] =  mean(permID[2]["sentimentPositive"])
            # dfSentimentNeut[dfSentimentNeut[:Date].==date, permID[1]] = mean(permID[2]["sentimentNeutral"])
            dfSentimentNeg[dfSentimentNeg[:Date].==date, permID[1]] = mean(permID[2]["sentimentNegative"])
            # dfSentimentClas[dfSentimentClas[:Date].==date, permID[1]] = mean(permID[2]["sentimentClass"])
            # dfRel[dfRel[:Date].==date, permID[1]] = mean(permID[2]["relevance"])
            # dfNov24H[dfNov24H[:Date].==date, permID[1]] = mean(permID[2]["novelty24H"])
            # dfNov7D[dfNov7D[:Date].==date, permID[1]] = mean(permID[2]["novelty7D"])
            # dfVol24H[dfVol24H[:Date].==date, permID[1]] = mean(permID[2]["volume24H"])
            # dftVol7D[dftVol7D[:Date].==date, permID[1]] = mean(permID[2]["volume7D"])
            # dfdiffPosNeg[dfdiffPosNeg[:Date].==date, permID[1]] = mean(permID[2]["diffPosNeg"])
            # dfsentClasRel[dfsentClasRel[:Date].==date, permID[1]] = mean(permID[2]["sentclasRel"])
            # dfdiffPosNegRelNeut[dfdiffPosNegRelNeut[:Date].==date, permID[1]] = mean(permID[2]["diffPosNegRelNeut"])
            # dfCountStories[dfCountStories[:Date].==date, permID[1]] = length(permID[2]["diffPosNegRelNeut"])
            # dftakesCount[dftakesCount[:Date].==date, permID[1]] = mean(permID[2]["takesCount"])
        catch
            push!(noPermid, permID[1])
        end
    end
end
toc()

JLD2.@save "$datarootpath/TRNA/dailyAllPermIDposandneg.jld2" dfSentimentNeg dfSentimentPos
# JLD2.@save "$datarootpath/TRNA/dailyAllPermIDcount.jld2" dfCountStories
# JLD2.@save "$datarootpath/TRNA/dailyAllPermIDnovelty.jld2" dftVol7D dftVol24H dftNov7D dfNov24H

sent = Float64[]
for row in 1:size(dfdiffPosNegRelNeut,1)
    print(row)
    push!(sent, NaNMath.mean(Array{Float64}(dfdiffPosNegRelNeut[row,2:end])))
end
using RCall
sent = Array{Float64}(sent)
@rput sent
R"plot(sent)"
