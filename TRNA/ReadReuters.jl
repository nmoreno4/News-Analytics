module ReadReuters

using Dates, Statistics
export parseTRNAjson, aggTakes, xInArrayOfDicts, customSentClass, findLongest, computeTopicScores

function parseTRNAjson(j, datef)

    storyID = string(split(j["guid"], "-")[1][4:end], "_", split(j["guid"], "-")[3])

    # Take-dependent info
    resDic = Dict()
    resDic["rootTstamp"] = DateTime(j["timestamps"][1]["timestamp"], datef)
    resDic["guId"] = j["guid"]
    resDic["dataId"] = j["data"]["id"]
    resDic["bodySize"] = j["data"]["analytics"]["newsItem"]["bodySize"]
    resDic["companyCount"] = j["data"]["analytics"]["newsItem"]["companyCount"]
    resDic["wordCount"] = j["data"]["analytics"]["newsItem"]["wordCount"]
    resDic["dataType"] = j["data"]["newsItem"]["dataType"]
    resDic["headline"] = j["data"]["newsItem"]["headline"]
    resDic["urgency"] = j["data"]["newsItem"]["urgency"]
    resDic["provider"] = j["data"]["newsItem"]["provider"]
    resDic["topics"] = j["data"]["newsItem"]["subjects"]
    resDic["sourceTimestamp"] = DateTime(j["data"]["newsItem"]["sourceTimestamp"], datef)
    resDic["altId"] = j["data"]["newsItem"]["metadata"]["altId"]
    resDic["feedTimestamp"] = DateTime(j["data"]["newsItem"]["metadata"]["feedTimestamp"], datef)
    resDic["firstCreated"] = DateTime(j["data"]["newsItem"]["metadata"]["firstCreated"], datef)
    resDic["isArchive"] = j["data"]["newsItem"]["metadata"]["isArchive"]
    resDic["takeSequence"] = j["data"]["newsItem"]["metadata"]["takeSequence"]


    # Stock-dependent info
    st = 1
    if length(j["data"]["analytics"]["analyticsScores"]) > 1
        error("There is more than one stock with analytics reported!")
    end
    resDic["permId"] = parse(Int, j["data"]["analytics"]["analyticsScores"][st]["assetId"])
    resDic["assetName"] = j["data"]["analytics"]["analyticsScores"][st]["assetName"]
    resDic["firstMentionSentence"] = j["data"]["analytics"]["analyticsScores"][st]["firstMentionSentence"]
    resDic["linkedIds"] = j["data"]["analytics"]["analyticsScores"][st]["linkedIds"]
    resDic["nov12H"] = j["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][1]["itemCount"]
    resDic["nov24H"] = j["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][2]["itemCount"]
    resDic["nov3D"] = j["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][3]["itemCount"]
    resDic["nov5D"] = j["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][4]["itemCount"]
    resDic["nov7D"] = j["data"]["analytics"]["analyticsScores"][st]["noveltyCounts"][5]["itemCount"]
    resDic["vol12H"] = j["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][1]["itemCount"]
    resDic["vol24H"] = j["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][2]["itemCount"]
    resDic["vol3D"] = j["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][3]["itemCount"]
    resDic["vol5D"] = j["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][4]["itemCount"]
    resDic["vol7D"] = j["data"]["analytics"]["analyticsScores"][st]["volumeCounts"][5]["itemCount"]
    resDic["relevance"] = j["data"]["analytics"]["analyticsScores"][st]["relevance"]
    resDic["sentClass"] = j["data"]["analytics"]["analyticsScores"][st]["sentimentClass"]
    resDic["sentimentNegative"] = j["data"]["analytics"]["analyticsScores"][st]["sentimentNegative"]
    resDic["sentimentNeutral"] = j["data"]["analytics"]["analyticsScores"][st]["sentimentNeutral"]
    resDic["sentimentPositive"] = j["data"]["analytics"]["analyticsScores"][st]["sentimentPositive"]
    resDic["sentimentWordCount"] = j["data"]["analytics"]["analyticsScores"][st]["sentimentWordCount"]

    return storyID, resDic
end


function aggTakes(takes)
    res = Dict()
    res["vol12H"] = xInArrayOfDicts(takes, minimum, "vol12H")
    res["vol24H"] = xInArrayOfDicts(takes, minimum, "vol12H")
    res["vol3D"] = xInArrayOfDicts(takes, minimum, "vol12H")
    res["vol5D"] = xInArrayOfDicts(takes, minimum, "vol12H")
    res["vol7D"] = xInArrayOfDicts(takes, minimum, "vol12H")
    res["nov12H"] = xInArrayOfDicts(takes, minimum, "nov12H")
    res["nov24H"] = xInArrayOfDicts(takes, minimum, "nov12H")
    res["nov3D"] = xInArrayOfDicts(takes, minimum, "nov12H")
    res["nov5D"] = xInArrayOfDicts(takes, minimum, "nov12H")
    res["nov7D"] = xInArrayOfDicts(takes, minimum, "nov12H")
    res["sourceTimestamp"] = xInArrayOfDicts(takes, minimum, "sourceTimestamp")
    res["companyCount"] = xInArrayOfDicts(takes, mean, "companyCount")
    res["linkedIds"] = xInArrayOfDicts(takes, findLongest, "linkedIds")
    res["headline"] = xInArrayOfDicts(takes, findLongest, "headline")
    res["topics"] = xInArrayOfDicts(takes, findLongest, "topics")
    res["wordCount"] = xInArrayOfDicts(takes, mean, "wordCount")
    res["firstCreated"] = xInArrayOfDicts(takes, minimum, "firstCreated")
    res["assetName"] = xInArrayOfDicts(takes, findLongest, "assetName")
    res["takeSequence"] = xInArrayOfDicts(takes, mean, "takeSequence")
    res["relevance"] = xInArrayOfDicts(takes, mean, "relevance")
    res["firstMentionSentence"] = xInArrayOfDicts(takes, minimum, "firstMentionSentence")
    res["sentimentNegative"] = xInArrayOfDicts(takes, mean, "sentimentNegative")
    res["sentimentNeutral"] = xInArrayOfDicts(takes, mean, "sentimentNeutral")
    res["sentimentPositive"] = xInArrayOfDicts(takes, mean, "sentimentPositive")
    # Right order is important
    res["sentClass"] = customSentClass([res["sentimentNegative"], res["sentimentNeutral"], res["sentimentPositive"]])

    if "hasArchive" in keys(takes[1])
        for i in 1:length(takes)
            if !("headlineArchive" in keys(takes[i]))
                takes[i]["headlineArchive"]=""
            end
        end
        res["topicsArchive"] = xInArrayOfDicts(takes, findLongest, "topicsArchive")
        res["headlineArchive"] = xInArrayOfDicts(takes, findLongest, "headlineArchive")
        res["bodyArchive"] = xInArrayOfDicts(takes, findLongest, "bodyArchive")
    end

    return res
end

function xInArrayOfDicts(dictArray, customfct, crtkey)
    toCompare = []
    for take in dictArray
        push!(toCompare, take[crtkey])
    end
    return customfct(toCompare)
end

function customSentClass(X)
    maxidx = findmax(X)[2]
    if maxidx==1
        return -1
    elseif maxidx==2
        return 0
    elseif maxidx==3
        return 1
    end
end

function findLongest(X)
    return X[findmax(length.(X))[2]]
end



"""
Not specifying top2 and top3 will do a plain vanilla filter with all stories
on the topic.
Each argument should be a tuple with the topic as String in it's first argument
and a boolean indicating if I want all those new's topic (true) or all news without
that topic (false).
top1 is the "stonger" conditioning if top1, top2 and top3 are provided given the
ordering of abjoin and bcjoin
"""
function computeTopicScores(permnoday, top1=(), top2=(), top3=(); novFilter=false, abjoin=&, bcjoin=&, relthresh=0, replacemissing=true)
    stCount = 0
    posSum = 0
    negSum = 0
    if typeof(relthresh)==String
        relthresh = 0
        multrel = true
    else
        relthresh = relthresh/100
        multrel = false
    end
    for i in 1:length(permnoday)
        if multrel
            relsmooth=permnoday[i]["relevance"]
        else
            relsmooth=1
        end
        if top1==() && top2==() && top3==()
            if typeof(novFilter)==Bool && !novFilter && permnoday[i]["relevance"]>=relthresh
                stCount+=1
                posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
            elseif permnoday[i][novFilter[1]]<=novFilter[2] && permnoday[i]["relevance"]>=relthresh
                stCount+=1
                posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
            end
        elseif top2==() && top3==()
            top1[2] ? a = in : a = !in
            top1[2] ? aBitOp = (|) : aBitOp = (&)
            if "topicsArchive" in keys(permnoday[i])
                topicCond = aBitOp(a(top1[1], permnoday[i]["topics"]), a(top1[1], permnoday[i]["topicsArchive"]))
            else
                topicCond = a(top1[1], permnoday[i]["topics"])
            end
            if topicCond
                if typeof(novFilter)==Bool && !novFilter && permnoday[i]["relevance"]>=relthresh
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                elseif permnoday[i][novFilter[1]]<=novFilter[2] && permnoday[i]["relevance"]>=relthresh
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                end
            end
        elseif length(top2)>0 && top3==()
            top1[2] ? a = in : a = !in
            top1[2] ? aBitOp = (|) : aBitOp = (&)
            top2[2] ? b = in : b = !in
            top2[2] ? bBitOp = (|) : bBitOp = (&)

            if "topicsArchive" in keys(permnoday[i])
                topicCond = abjoin(aBitOp(a(top1[1], permnoday[i]["topics"]), a(top1[1], permnoday[i]["topicsArchive"])),
                                   bBitOp(b(top2[1], permnoday[i]["topics"]), b(top2[1], permnoday[i]["topicsArchive"])))
            else
                topicCond = abjoin(a(top1[1], permnoday[i]["topics"]),
                                   b(top2[1], permnoday[i]["topics"]))
            end

            if topicCond
                if typeof(novFilter)==Bool && !novFilter && permnoday[i]["relevance"]>=relthresh
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                elseif permnoday[i][novFilter[1]]<=novFilter[2] && permnoday[i]["relevance"]>=relthresh
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                end
            end
        elseif length(top2)>0 && length(top3)>0
            top1[2] ? a = in : a = !in
            top1[2] ? aBitOp = (|) : aBitOp = (&)
            top2[2] ? b = in : b = !in
            top2[2] ? bBitOp = (|) : bBitOp = (&)
            top3[2] ? c = in : c = !in
            top3[2] ? cBitOp = (|) : cBitOp = (&)

            if "topicsArchive" in keys(permnoday[i])
                topicCond = abjoin(aBitOp(a(top1[1], permnoday[i]["topics"]), a(top1[1], permnoday[i]["topicsArchive"])),
                                   bcjoin(bBitOp(b(top2[1], permnoday[i]["topics"]), b(top2[1], permnoday[i]["topicsArchive"])),
                                          cBitOp(c(top3[1], permnoday[i]["topics"]), c(top3[1], permnoday[i]["topicsArchive"]))))
            else
                topicCond = abjoin(a(top1[1], permnoday[i]["topics"]),
                                   bcjoin(b(top2[1], permnoday[i]["topics"]),
                                          c(top3[1], permnoday[i]["topics"])))
            end

            if topicCond
                if typeof(novFilter)==Bool && !novFilter
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                elseif permnoday[i][novFilter[1]]<=novFilter[2]
                    stCount+=1
                    posSum+=(permnoday[i]["sentimentPositive"]*relsmooth)
                    negSum+=(permnoday[i]["sentimentNegative"]*relsmooth)
                end
            end
        end
    end
    if replacemissing
        if stCount==0
            stCount=missing
        end
        if posSum==0
            posSum=missing
        end
        if negSum==0
            negSum=missing
        end
    end
    return stCount, posSum, negSum
end


end # module
