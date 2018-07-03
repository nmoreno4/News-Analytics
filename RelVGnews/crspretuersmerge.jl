using Mongo, databaseQuerer, DataFrames, NaNMath
datarootpath = "/run/media/nicolas/OtherData/home/home/nicolas/Data"

using JLD2
# JLD2.@load "$datarootpath/TRNA/dailyAllPermIDcount.jld2" dfCountStories
JLD2.@load "$datarootpath/TRNA/dailyAllPermIDposandneg.jld2" dfSentimentNeg dfSentimentPos
JLD2.@load "$datarootpath/TRNA/dailyAllPermID_count_sentclas.jld2" dfsentClasRel dfCountStories
NaNMath.sum(Array{Float64}(dfSentimentPos[1541,2:end]))
# using Plots
# plotlyjs()
# a=Float64[]
# for i in 3477:size(dfCountStories,1)
#     push!(a, NaNMath.sum(Array{Float64}(dfCountStories[i,2:end])))
# end
# plot(a)
using FileIO
permNO_to_permID = FileIO.load("$datarootpath/permnopermid/permnoToPermId.jld2")["mappingDict"]
lastdate = Dates.Date(2002,12,31)
crtdate = Dates.Date(2003,1,1)
datelimit = Dates.Date(2017,7,1)
allobs=[]
client = MongoClient()
CRSPconnect = MongoCollection(client, "NewsDB", "DailyCRSP")
MERGEconnect = MongoCollection(client, "NewsDB", "CRSPTRNAmerge4")
allPermnos = collect(fieldDistinct(CRSPconnect, ["permno"])[1])
cc=0
nonnan = 0
permid = 0
daysPosNeg = 0
TRNAdate = 0
daysCount = 0
unmatched = []
for permno in allPermnos
    cc+=1
    print(cc)
    sentClasRel = NaN
    diffPosNeg = NaN
    dfdiffPosNegRelNeut = NaN
    storiesCount = 0
    permid = 0
    try
        permid = permNO_to_permID[permno]
    catch
        push!(unmatched, permno)
    end
    if permid==0
        print("\n ==== $permno =====\n")
        continue
    end
    print("$permno - $permid \n")
    cursor = find(CRSPconnect,
                Mongo.query("permno" => permno))
    for obs in cursor
        crtdate = obs["date"]
        # daysPosNeg = Float64[]
        daysPos = Float64[]
        daysNeg = Float64[]
        # daysPosNegRelNeut = Float64[]
        daysSentClas = Float64[]
        daysCount = Float64[]
        for TRNAdate in Dates.DateTime(lastdate)+Dates.Hour(20)+Dates.Day(1):Dates.DateTime(crtdate)+Dates.Hour(20)
            if TRNAdate>=datelimit
                continue
            end
            # push!(daysPosNeg, dfdiffPosNeg[dfdiffPosNeg[:Date].==TRNAdate, Symbol(permid)][1])
            push!(daysPos, dfSentimentPos[dfSentimentPos[:Date].==TRNAdate, Symbol(permid)][1])
            push!(daysNeg, dfSentimentNeg[dfSentimentNeg[:Date].==TRNAdate, Symbol(permid)][1])
            # push!(daysPosNegRelNeut, dfdiffPosNegRelNeut[dfdiffPosNegRelNeut[:Date].==TRNAdate, Symbol(permid)][1])
            push!(daysSentClas, dfsentClasRel[dfsentClasRel[:Date].==TRNAdate, Symbol(permid)][1])
            push!(daysCount, dfCountStories[dfCountStories[:Date].==TRNAdate, Symbol(permid)][1])
        end
        # if NaNMath.mean_count(daysCount)[2] == NaNMath.mean_count(daysPosNeg)[2]
        #     print(NaNMath.mean_count(daysCount)[2])
        #     print("=")
        #     print(NaNMath.mean_count(daysPosNeg)[2])
        # else
        #     print(daysCount)
        #     print("\n === $daysPosNeg ===\n")
        # end
        countweight = daysCount./NaNMath.sum(daysCount)
        sentClasRel = NaNMath.mean(countweight.*daysSentClas)
        # diffPosNeg = NaNMath.mean(countweight.*daysPosNeg)
        Pos = NaNMath.mean(countweight.*daysPos)
        Neg = NaNMath.mean(countweight.*daysNeg)
        # dfdiffPosNegRelNeut = NaNMath.mean(countweight.*daysPosNegRelNeut)
        storiesCount = NaNMath.sum(daysCount)
        if isnan(storiesCount)
            # print("$sentClasRel")
        end
        if !isnan(sentClasRel)
            nonnan+=1
        end
        p_oid = insert(MERGEconnect,
                ("permno" => permno,
                 "permid" => permid,
                 "date" => crtdate,
                 "adjret" => obs["adjret"],
                 "startdate" => lastdate,
                 "ptf_2by3_size_value" => obs["ptf_2by3_size_value"],
                 "ptf_10by10_size_value" => obs["ptf_10by10_size_value"],
                 "ptf_5by5_size_value" => obs["ptf_5by5_size_value"],
                 "rankbm" => obs["rankbm"],
                 "ranksize" => obs["ranksize"],
                 "wport" => obs["wport"],
                 "sentClasRel" => sentClasRel,
                 "storiesCount" => storiesCount,
                 "Pos" => Pos,
                 "Neg" => Neg
                 # "dfdiffPosNegRelNeut" => dfdiffPosNegRelNeut,
                 # "diffPosNeg" => diffPosNeg
                 ))
        lastdate = crtdate
    end
    # if cc==100
    #     break
    # end
end
