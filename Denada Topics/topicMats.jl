using DataFrames, Statistics, CSV, StatsBase

chosenVars = ["permno", "td","retadj", "bemeY", "meM", "volume", "gsector"]
topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "RECLL",
          "REORG", "RES", "RESF", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND", "ALL"]

using PyCall
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")

statvars = ["Avg_Nb_stories_day", "Nb_permnos_day", "EWret1", "EWret2", "EWret3",
            "VWret1", "VWret2", "Size1", "Size2", "Size3", "totNews", "scaledNegSum",
            "scaledPosSum", "scaledSent", "negSum", "posSum", "nb_neg_news",
            "topicCounts", "posnegcorrel"]
statDict = Dict(zip(statvars, [Union{Float64, Int64, Dict{Union{Missing,Float64},Int64}}[] for i in statvars]))


#Separate sample of positive and negative news
for topic in topics
    print("$topic \n")
    if topic!="ALL"
        retVars = [["nS_$(topic)_inc_nov24H_0_rel100", "posSum_$(topic)_inc_nov24H_0_rel100", "negSum_$(topic)_inc_nov24H_0_rel100"]; chosenVars]
    else
        retVars = [["nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100"]; chosenVars]
    end
    print(chosenVars)
    retDic = Dict(zip(retVars, [1 for i in retVars]))
    nbItems = collection[:find](Dict(retVars[1]=> Dict("\$gte"=> 0), "gsector"=>Dict("\$ne"=> "40")))[:count]()
    cursor = collection[:find](Dict(retVars[1]=> Dict("\$gte"=> 0), "gsector"=>Dict("\$ne"=> "40")), retDic)
    retDic = Dict(zip(retVars, [Array{Union{Float64,Missing}}(undef,nbItems) for i in retVars]))
    cc = [0]
    @time for doc in cursor
        cc[1]+=1
        el = Dict(doc)
        for var in retVars
            if !(var in ["gsector", "gsubind"])
                try
                    retDic[var][cc[1]] = el[var]
                catch
                    retDic[var][cc[1]] = missing
                end
            else
                try
                    retDic[var][cc[1]] = parse(Float64,el[var])
                catch
                    retDic[var][cc[1]] = missing
                end
            end
        end
    end
    resDF = DataFrame(retDic)


    # Compute descriptive stats
    # Average number of stories of the category when the category has any news
    push!(statDict["Avg_Nb_stories_day"], mean(resDF[Symbol(retVars[1])]))
    # Average of unique permnos per day within a category
    prov = by(resDF, :td, :permno => size)
    try
        push!(statDict["Nb_permnos_day"], mean([i[1] for i in prov[:permno_size]]))
    catch x
        show(resDF)
        show(prov)
        error(x)
    end
    # EW returns
    push!(statDict["EWret1"],  (1 + mean(resDF[:retadj]))^(252) - 1)
    # EW return aggregated by date
    prov = by(resDF, :td, :retadj => mean)
    push!(statDict["EWret2"],  (1 + mean([i[1] for i in prov[Symbol("retadj_Statistics.mean")]]))^(252) - 1)
    # EW return aggregated by permno
    prov = by(resDF, :permno, :retadj => mean)
    push!(statDict["EWret3"],  (1 + mean([i[1] for i in prov[Symbol("retadj_Statistics.mean")]]))^(252) - 1)


    # VW returns
    totME = sum(skipmissing(resDF[:meM]))
    ret = sum(skipmissing( (resDF[:meM] ./ totME) .* resDF[:retadj] ))
    push!(statDict["VWret1"], (1 + ret)^(252) - 1)
    # VW return aggregated by date
    res = by(resDF, [:td]) do xdf
        res = Dict()
        totME = sum(skipmissing(xdf[:meM]))
        res["ret"] = sum(skipmissing( (xdf[:meM] ./ totME) .* xdf[:retadj] ))
    end
    push!(statDict["VWret2"],  (1 + mean(res[:x1]))^(252) - 1)

    # Mean size simple
    push!(statDict["Size1"],  mean(resDF[:meM]))
    # Mean size (all companies are equally important)
    prov = by(resDF, :permno, :meM => mean)
    push!(statDict["Size2"],  mean([i[1] for i in prov[Symbol("meM_Statistics.mean")]]))
    # Size scaled by size aggregated by date
    res = by(resDF, [:td]) do xdf
        res = Dict()
        totME = sum(skipmissing(xdf[:meM]))
        res["meM"] = sum(skipmissing( (xdf[:meM] ./ totME) .* xdf[:meM] ))
    end
    push!(statDict["Size3"],  mean(res[:x1]))

    # Sentiment
    push!(statDict["totNews"],  sum(resDF[Symbol(retVars[1])]))
    push!(statDict["scaledNegSum"],  sum(resDF[Symbol(retVars[3])])/statDict["totNews"][end])
    push!(statDict["scaledPosSum"],  sum(resDF[Symbol(retVars[2])])/statDict["totNews"][end])
    push!(statDict["scaledSent"],  (sum(resDF[Symbol(retVars[2])]) - sum(resDF[Symbol(retVars[3])])) / statDict["totNews"][end])
    push!(statDict["negSum"],  sum(resDF[Symbol(retVars[3])]))
    push!(statDict["posSum"],  sum(resDF[Symbol(retVars[2])]))
    push!(statDict["nb_neg_news"], sum( resDF[Symbol(retVars[3])] .> resDF[Symbol(retVars[2])] ))
    push!(statDict["topicCounts"], countmap(resDF[:gsector]))
    push!(statDict["posnegcorrel"], cor(resDF[Symbol(retVars[2])], resDF[Symbol(retVars[3])]))
end
#nb of days where neg>pos
#modes : imdustries with most announcements in a topic
#what is the correlation between pos and neg?
topicCounts = statDict["topicCounts"]
delete!(statDict, "topicCounts")

statDF = DataFrame(statDict)
statDF[:topic] = topics
CSV.write("/home/nicolas/Documents/Paper Denada/summaryStats.csv", statDF)
