##########################################################################################
# Description...
##########################################################################################
using JSON, JLD2, Dates, ReadReuters, Statistics, StatsBase, Buckets, DBstats, Mongoc

# 2017, 2016, 2003, 2004, 2005, 2006, 2007, 2008, 2009
# [2008-2015] is only analytics
# 2014 failed at JLD2 save
############## Params ##############
offsetNewsDay = Dates.Minute(15)
datef = DateFormat("y-m-dTH:M:S.sZ");
recomputeUniqueTDs = false
ystart, yend = 2005,2005
insertOnlyAna = false
####################################
using Mongoc
client = Mongoc.Client()
database = client["Jan2019"]
collection = database["PermnoDay"]
####################################

function splitDict(inputDic, nbSplits)
    alldicts = []
    L = length(inputDic)
    for i in 1:ceil(L/nbSplits):L
        maxval = minimum([i+ceil(L/nbSplits), L+1])-1
        print("$i -- $maxval \n")
        push!(alldicts, Dict(collect(inputDic)[Int(i):Int(maxval)]))
    end
    return tuple(alldicts...)
end

dictByStories = Dict{String,Any}("totaltakes"=>0)
for year in ystart:yend
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


# Insert matching Archive bodies to corresponding news.
for year in ystart:yend
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


# Reorder news by permID
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
            print("$take hey")
        end
    end
end


# Aggregate all news by stories
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


# Load unique tds
if recomputeUniqueTDs
    uniqueVal()
end
JLD2.@load "/home/nicolas/Data/MongoDB Inputs/unique_date.jld2"
uniquedays = copy(uniquevals)

# Assign td based on "firstCreated" for each story
for permid in keys(storyAggDict)
    for story in storyAggDict[permid]
        story["td"] = assignBucket(story["firstCreated"]+offsetNewsDay, uniquedays)
    end
end

# Reorder all stories in a permid by td
permidTdDic = Dict()
@time for (permid, permidDic) in storyAggDict
    tdSet = []
    for story in permidDic
        push!(tdSet, story["td"])
    end
    tdSet = sort(collect(Set(tdSet)))
    permidTdDic[permid] = Dict()
    for td in tdSet
        permidTdDic[permid][td] = Dict{Any,Any}("stories"=>[])
    end
    for story in permidDic
        td = story["td"]
        push!(permidTdDic[permid][td]["stories"], story)
    end
end






print("Preparing final Dictionary \n")
dictByStories = nothing
storyAggDict = nothing
permidDic = nothing
GC.gc()

permidTdDic, permidTdDic2 = splitDict(permidTdDic, 2)
try
    @time JLD2.@save "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic2.jld2" permidTdDic2
catch
    using JLD
    @time JLD.save("/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic2.jld","permidTdDic2",permidTdDic2)
end
permidTdDic2 = nothing; GC.gc();
try
    @time JLD2.@save "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic.jld2" permidTdDic
catch
    using JLD
    @time JLD.save("/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic.jld","permidTdDic",permidTdDic)
end
permidTdDic = nothing; GC.gc();


# mtopics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
#           "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
#           "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
#           "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
#           "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "PRXF", "RECAP1", "RECLL",
#           "REORG", "SHPP", "SHRACT", "SISU", "SL1", "SPLITB",
#           "STAT", "STK", "XPAND"]
# # Compute sentiment aggregates, filtering by topic, novelty and relevance
# for i in 1:1
#     print("This is Dict # $i \n")
#     row = [0]
#     if i==1
#         print("effectively number 1 \n")
#         GC.gc()
#         filetoload = "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic.jld2"
#         @time JLD2.@load filetoload permidTdDic
#         print("size permidTdDic 4: $(length(permidTdDic))\n")
#     elseif i==2
#         print("effectively number 2 \n")
#         permidTdDic = nothing
#         GC.gc()
#         filetoload = "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic2.jld2"
#         @time JLD2.@load filetoload permidTdDic2
#         permidTdDic = permidTdDic2
#     end
#     @time for (permid, permidDic) in permidTdDic
#         row[1]+=1
#         if row[1] in 1:40:length(permidTdDic)
#             print("Advnacement : ~$(round(100*row[1]/length(permidTdDic)))% \n")
#             print(Dates.now())
#         end
#         for (td, tdDic) in permidTdDic[permid]
#             permnoday = permidTdDic[permid][td]["stories"]
#
#             ############## only new news #######################
#             rthresh = 90
#             novthresh = 0
#
#             restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
#             permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#
#             ############## no rel thresh #######################
#             rthresh = 0
#
#             restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
#             permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             ############### no rel thresh  but multiply by relevance #######################
#             rthresh = "smooth"
#
#             restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
#             permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#
#             ############### only new news #######################
#             rthresh = 100
#             novthresh = 0
#
#             restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
#             permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
#             permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#             permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#             permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#
#             for top in mtopics
#                 restruenov = computeTopicScores(permnoday, ("N2:$(top)", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
#                 permidTdDic[permid][td]["nS_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
#                 permidTdDic[permid][td]["posSum_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
#                 permidTdDic[permid][td]["negSum_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
#             end
#
#
#             if insertOnlyAna
#                 delete!(permidTdDic[permid][td], "stories")
#             end
#         end
#     end
#     GC.gc()
#     print("Inserting dictionary")
#     row = [0]
#     @time for (permid, permidDict) in permidTdDic
#         row[1]+=1
#         if row[1] in 1:40:length(permidTdDic)
#             print("Advnacement : ~$(round(100*row[1]/length(permidTdDic)))% \n")
#         end
#         for (td, setDict) in permidDict
#             selectDict = [Dict("permid"=>permid), Dict("td"=>td)]
#             # Update all matching in MongoDB
#             crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
#             crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
#             try
#                 Mongoc.update_many(collection, crtselector, crtupdate)
#             catch x
#                 print("$(crtselector) \n")
#                 print(crtupdate)
#                 error(x)
#             end
#         end
#     end
# end

# match resulting data to MongoDB entries and update them
