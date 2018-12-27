using JSON, Mmap, Dates, ReadReuters, Statistics, StatsBase

datef = DateFormat("y-m-dTH:M:S.sZ");

############## Params ##############
offsetNewsDay = Dates.Minute(15)
####################################

# f = open("/run/media/nicolas/OtherData/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/2014/TRNA2014_aa.json", "r")
# s = String(Mmap.mmap(f));
# j = JSON.parse(s);
# 1


dictByStories = Dict{String,Any}("totaltakes"=>0)
for year in 2003
    @time for crtfile in readdir("/run/media/nicolas/OtherData/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/$(year)")
        print("$crtfile \n")
        f = open("/run/media/nicolas/OtherData/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/$(year)/$(crtfile)", "r")
        # s = String(Mmap.mmap(f));
        j = JSON.parse(f);
        close(f)
        dictByStories["totaltakes"] += length(j)
        for take in j
            sId, takeInfo = parseTRNAjson(take, datef)
            if sId in keys(dictByStories)
                push!(dictByStories[sId], takeInfo)
            else
                dictByStories[sId] = [takeInfo]
            end
        end
        j=0
    end
end



for year in 2003
    @time for crtfile in readdir("/run/media/nicolas/OtherData/Reuters/News/Archives/Historical/RTRS_/$(year)/extracted")
        print("$crtfile \n")
        f = open("/run/media/nicolas/OtherData/Reuters/News/Archives/Historical/RTRS_/$(year)/extracted/$(crtfile)", "r")
        # s = String(Mmap.mmap(f));
        nArchive = JSON.parse(f)["Items"];
        close(f)
        for news in nArchive
            storyID = string(split(news["guid"], "-")[1], "_", split(news["guid"], "-")[3])
            if storyID in keys(dictByStories)
                for take in dictByStories[storyID]
                    if "hasArchive" in keys(take)
                        if news["data"]["headline"] == take["headline"]
                            take["headlineArchive"] = news["data"]["headline"]
                        end
                        if length(news["data"]["body"])>length(take["bodyArchive"])
                            take["bodyArchive"] = news["data"]["body"]
                        end
                        if length(news["data"]["subjects"])>length(take["topicsArchive"])
                            take["topicsArchive"] = news["data"]["subjects"]
                        end
                    else
                        take["hasArchive"] = true
                        if news["data"]["headline"] == take["headline"]
                            take["headlineArchive"] = news["data"]["headline"]
                        end
                        take["bodyArchive"] = news["data"]["body"]
                        take["topicsArchive"] = news["data"]["subjects"]
                    end
                end
            end
        end
    end
end


permidDict = Dict()
@time for (key, story) in dictByStories
    for take in story
        if "permId" in keys(take)
            permID = take["permId"]
            if permID in keys(permidDict)
                if  key in keys(permidDict[permID])# this take is part of an existing story ==> append to it
                    push!(permidDict[permID][key], take)
                else # This take is a new story
                    permidDict[permID][key] = [take]
                end
            else
                permidDict[permID] = Dict(key => [take])
            end
        else
            print(take)
        end
    end
end


storyAggDict = Dict()
@time for (permid, stories) in permidDict
    for (storyID, takes) in stories
        if permid in keys(storyAggDict)
            push!(storyAggDict[permid], aggTakes(takes))
        else
            storyAggDict[permid] = [aggTakes(takes)]
        end
    end
end


using Mongoc, Dates, JSON, DataStructures
client = Mongoc.Client()
database = client["Dec2018"]
collection = database["PermnoDay"]
bson_result = Mongoc.command_simple(database, Mongoc.BSON("{ \"distinct\" : \"PermnoDay\", \"key\" : \"date\" }"))
uniquedays = convert(Array{DateTime}, sort(Mongoc.as_dict(bson_result)["values"]))

show(keys(storyAggDict[4295860884][1]))
crtdate = storyAggDict[4295860884][1]["firstCreated"]
tdMatch = assignBucket(crtdate+offsetNewsDay, uniquedays)
uniquedays[209]



















4295905573
4295899948
5030853586
5000122354
4295903128


312252/5165
ccounter = Any[0]
for (permno, X) in storyAggDict
    if permno==4295903128
        ccounter[1] = X
    end
end
length(ccounter[1])










f = open("/run/media/nicolas/OtherData/Reuters/News/Archives/Historical/RTRS_/2003/extracted/News.RTRS.200301.0214.txt", "r")
# s = String(Mmap.mmap(f));
nArchive = JSON.parse(f)["Items"];
close(f)
nArchive[7]["data"]["subjects"]


res = []
for (key, newsarray) in dictByStories
    if "hasArchive" in keys(newsarray[1])
        push!(res, newsarray)
    end
end


idx = 765
a = res[idx][1]["headline"]
a = res[idx][1]["headlineArchive"]
a = res[idx][1]["topics"]
a = res[idx][1]["topicsArchive"]
BA = res[idx][1]["bodyArchive"]
BA[findmax(length.(BA))[2]]

#
# res = []
# for i in 1:length(j)
#     if j[i]["data"]["analytics"]["newsItem"]["companyCount"] > 1
#         push!(res, j[i]["data"]["newsItem"]["metadata"]["altId"])
#     end
# end
# res1 = []
# for i in 1:length(j)
#     if j[i]["data"]["newsItem"]["metadata"]["altId"] == "nL3N0L81NJ"
#         push!(res1, j[i])
#     end
# end
#
# stocks = []
# for i in res1
#     push!(stocks, i["data"]["analytics"])
# end














rootTstamp = DateTime(j[i]["timestamps"][1]["timestamp"], datef)
guId = fulldict[i]["guid"]
dataId = j[i]["data"]["id"]
bodySize = j[i]["data"]["analytics"]["newsItem"]["bodySize"]
companyCount = j[i]["data"]["analytics"]["newsItem"]["companyCount"]
wordCount = j[i]["data"]["analytics"]["newsItem"]["wordCount"]
dataType = j[i]["data"]["newsItem"]["dataType"]
headline = j[i]["data"]["newsItem"]["headline"]
urgency = j[i]["data"]["newsItem"]["urgency"]
provider = j[i]["data"]["newsItem"]["provider"]
topics = j[i]["data"]["newsItem"]["subjects"]
sourceTimestamp = DateTime(j[i]["data"]["newsItem"]["sourceTimestamp"], datef)
altId = j[i]["data"]["newsItem"]["metadata"]["altId"]
feedTimestamp = DateTime(j[i]["data"]["newsItem"]["metadata"]["feedTimestamp"], datef)
firstCreated = DateTime(j[i]["data"]["newsItem"]["metadata"]["firstCreated"], datef)
res = []
@time j[i]["data"]["newsItem"]["metadata"]
for i in 1:length(j)
    push!(res, j[i]["data"]["newsItem"]["metadata"]["isArchive"])
end
sum(res)
takeSequence = j[i]["data"]["newsItem"]["metadata"]["takeSequence"]


# Stock-dependent info
permId = parse(Int, j[i]["data"]["analytics"]["analyticsScores"][st]["assetId"])
assetName = j[i]["data"]["analytics"]["analyticsScores"][st]["assetName"]
firstMentionSentence = j[i]["data"]["analytics"]["analyticsScores"][st]["firstMentionSentence"]
linkedIds = j[i]["data"]["analytics"]["analyticsScores"][st]["linkedIds"]
nov12H = j[i]["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][1]["itemCount"]
nov24H = j[i]["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][2]["itemCount"]
nov3D = j[i]["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][3]["itemCount"]
nov5D = j[i]["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][4]["itemCount"]
nov7D = j[i]["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][5]["itemCount"]
vol12H = j[i]["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][1]["itemCount"]
vol24H = j[i]["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][2]["itemCount"]
vol3D = j[i]["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][3]["itemCount"]
vol5D = j[i]["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][4]["itemCount"]
vol7D = j[i]["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][5]["itemCount"]
relevance = j[i]["data"]["analytics"]["analyticsScores"][st]["relevance"]
sentClass = j[i]["data"]["analytics"]["analyticsScores"][st]["sentimentClass"]
sentimentNegative = j[i]["data"]["analytics"]["analyticsScores"][st]["sentimentNegative"]
sentimentNeutral = j[i]["data"]["analytics"]["analyticsScores"][st]["sentimentNeutral"]
sentimentPositive = j[i]["data"]["analytics"]["analyticsScores"][st]["sentimentPositive"]
sentimentWordCount = j[i]["data"]["analytics"]["analyticsScores"][st]["sentimentWordCount"]




typeof(j) == LazyJSON.PropertyDicts.PropertyDict{AbstractString,Any,LazyJSON.Object{String}}


fArchive = open("/run/media/nicolas/OtherData/Reuters/News/Archives/Historical/RTRS_/2003/News.RTRS.200301.0210.txt")
fArchive2 = open("/run/media/nicolas/OtherData/Reuters/News/Archives/Historical/RTRS_/2003/News.RTRS.200301.0214.txt")
sArchive = String(Mmap.mmap(fArchive));
jArchive = LazyJSON.value(sArchive);
jArchive[10000]["data"]
sArchive2 = String(Mmap.mmap(fArchive2));
jArchive2 = LazyJSON.value(sArchive2);
length(j)
1
