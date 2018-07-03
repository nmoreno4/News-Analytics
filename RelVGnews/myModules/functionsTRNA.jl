module functionsTRNA
# using
export gatherSentiment, computeAnalytics, checkAnalyticsCount

"""
!!!!!!!!!
NEED TO NORMALIZE SUM OF WEIGHTS TO 1!!!!!!
!!!!!!!!
"""
function gatherSentiment(cursor, assetId, enddate, startdate, decay = 0.94, deltaFrequency=Dates.Day)
    # All analytics for that company during the given period
    totalPeriods = Int(deltaFrequency(ceil(enddate, deltaFrequency)-ceil(startdate, deltaFrequency)))
    sumDecays = 0
    for t in 1:totalPeriods
        sumDecays += decay^(totalPeriods-t)
    end
    periodAnalytics = []
    for story in cursor
        j=0
        # All analytics for that company on that particular story
        storyAnalytics = []
        for take in story["takes"]
            i=0
            crtdate = take["feedTimestamp"]
            timeDelta = deltaFrequency(ceil(enddate, deltaFrequency)-ceil(crtdate, deltaFrequency))
            for ana in take["analytics"]
                # Need to get the analytic of the RIGHT company
                anakeys = []
                for (k,v) in ana
                    push!(anakeys, k)
                end #for keys, values in ana
                if string(assetId) == ana["assetId"]
                    i+=1
                    j+=1
                    # if i>1
                    #     print("Hey this is the $i th analytic for this company in that take. The story is $(story["altId"]) / $(story["firstCreated"])\n")
                    # end #if test multiple analytics in the take
                    # if j>1
                    #     print("Hey this is the $j th analytic for this company in that story\n")
                    # end #if test multiple analytics in the story
                    pos = ana["sentimentPositive"]
                    neg = ana["sentimentNegative"]
                    neut = ana["sentimentNeutral"]
                    relevance = ana["relevance"]
                    novelties = []
                    for r in ana["noveltyCounts"]
                        push!(novelties, r["itemCount"])
                    end
                    volumes = []
                    for r in ana["volumeCounts"]
                        push!(volumes, r["itemCount"])
                    end
                    sentimentClass = ana["sentimentClass"]
                    sentimentWordCount = ana["sentimentWordCount"]
                    wordCount = take["wordCount"]
                    # All analytics for that company on that particular take
                    weightFactor = (decay^(totalPeriods-Int(timeDelta)))/sumDecays
                    takeAnalytics = (pos, neg, neut, relevance, novelties, volumes, sentimentClass, sentimentWordCount, wordCount, weightFactor)
                    if i<2
                        push!(storyAnalytics, takeAnalytics)
                    else
                        print("weird")
                    end #make sure to only add one analytic for the company for the take in case Reuters left duplicates
                end #if correct analytic assetId
            end #for ana
        end #for take
        push!(periodAnalytics, storyAnalytics)
    end #for story
    # print(periodAnalytics)
    return periodAnalytics
end #fun

"""
idx -> 1:pos, 2:neg, 3:neut, 4:relevance, 5:novelties, 6:volumes, 7:sentimentClass, 8:sentimentWordCount, 9:wordCount, 10:decayWeight
"""
function computeAnalytics(inputMat, idx, vType, storyAVG=true, filterRepet=false, newness = 5)
    outputMat = Array{Float64}(size(inputMat))*NaN
    for row in 1:size(inputMat, 1)
        for col in 1:size(inputMat, 2)
            daysStackList = []
            for daysStack in inputMat[row,col] #for each of the periods in the regroupment
                sumWeights, storiesWeights = 0, []
                for story in daysStack #for each story of the day
                    sWeights = []
                    for take in story
                        push!(sWeights, take[10])
                        sumWeights += take[10]
                    end #for take to compute weighting
                    push!(storiesWeights, mean(sWeights))
                end #for take to compute weighting
                storyList = []
                sCount = 0
                for story in daysStack
                    sCount += 1
                    takeList = []
                    for take in story
                        if storyAVG
                            wFactor = storiesWeights[sCount]/sumWeights
                        else
                            wFactor = take[10]/sumWeights
                        end
                        if length(idx)==1
                            if idx[1] in [5,6]
                                a = take[idx[1]][newness]
                            else
                                a = take[idx[1]]
                            end
                        elseif length(idx)==2
                            if idx[1] in [5,6]
                                a = take[idx[1]][newness]
                            else
                                a = take[idx[1]]
                            end
                            if idx[2] in [5,6]
                                b = take[idx[2]][newness]
                            else
                                b = take[idx[2]]
                            end
                        elseif length(idx)==3
                            if idx[1] in [5,6]
                                a = take[idx[1]][newness]
                            else
                                a = take[idx[1]]
                            end
                            if idx[2] in [5,6]
                                b = take[idx[2]][newness]
                            else
                                b = take[idx[2]]
                            end
                            if idx[3] in [5,6]
                                c = take[idx[3]][newness]
                            else
                                c = take[idx[3]]
                            end
                        end #if length idx
                        repetFilter = 1
                        if filterRepet && sum(take[5][1:newness])>0
                            repetFilter = 0
                        end
                        if vType == 1
                            push!(takeList, (a)*wFactor*repetFilter)
                        elseif vType == 2
                            push!(takeList, (a-b)*wFactor*repetFilter)
                        elseif vType == 3
                            push!(takeList, ((a-b)*c)*wFactor*repetFilter)
                        elseif vType == 4
                            push!(takeList, (a*b)*wFactor*repetFilter)
                        elseif vType == 5
                            if b>=a
                                push!(takeList, (1-(a/b))*wFactor*repetFilter)
                            end
                        elseif vType == 6
                            push!(takeList, take[10])
                        elseif vType == 7
                            push!(takeList, 1)
                        end #if vType
                    end #for take to store analytics
                    if vType!=6
                        push!(storyList, sum(takeList))
                    else
                        push!(storyList, mean(takeList))
                    end
                end #for story
                if length(storyList)>0
                    if vType!=6
                        push!(daysStackList, sum(storyList))
                    else
                        push!(daysStackList, mean(storyList))
                    end
                end
            end #for daysStack
            # print("$(daysStackList) - $row $col")
            if length(daysStackList)>0
                outputMat[row, col] = mean(daysStackList)
            end
        end #for col
    end #for row
    return outputMat
end #fun


"""
small function that can be used to do a rowwise counting of the nbAnalyticsFound (or nbStoriesFound) array
"""
function checkAnalyticsCount(dates, nbAnalyticsFound)
    totalAnalyticsPeriod = []
    allRows = 1:length(dates)
    for row in allRows
        periodTotal = 0
        for elem in nbAnalyticsFound
            if elem[1] == row
                periodTotal+=elem[2]
            end #if row match
        end #for nbAnalyticsFound
        push!(totalAnalyticsPeriod, periodTotal)
    end #for row
    return totalAnalyticsPeriod
end #for fun

end #module
