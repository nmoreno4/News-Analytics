##########################################################################################
# Description...
##########################################################################################
using JSON, JLD2, Dates, ReadReuters, Statistics, StatsBase, Buckets, DBstats, Mongoc, ArgParse

s = ArgParseSettings()
@add_arg_table s begin
    "--y"
        help = "Serves for both yend and ystart"
        arg_type = Int
    "--ioa"
        help = "Boolean. Should only analytics be inserted?"
        arg_type = Bool
        default = false
end
parsed_args = parse_args(ARGS, s)
############## Params ##############
offsetNewsDay = Dates.Minute(15)
datef = DateFormat("y-m-dTH:M:S.sZ");
recomputeUniqueTDs = false
ystart, yend = parsed_args["y"],parsed_args["y"]
insertOnlyAna = parsed_args["ioa"]
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
