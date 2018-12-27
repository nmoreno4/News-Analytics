using JSON, JLD2, Dates, ReadReuters, Statistics, StatsBase, Buckets, DBstats, Mongoc

datef = DateFormat("y-m-dTH:M:S.sZ");

############## Params ##############
offsetNewsDay = Dates.Minute(15)
recomputeUniqueTDs = false
ystart, yend = 2017,2017
####################################


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


if recomputeUniqueTDs
    uniqueVal()
end
JLD2.@load "/home/nicolas/Data/MongoDB Inputs/unique_date.jld2"
uniquedays = copy(uniquevals)

for permid in keys(storyAggDict)
    for story in storyAggDict[permid]
        story["td"] = assignBucket(story["firstCreated"]+offsetNewsDay, uniquedays)
    end
end

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


@time for (permid, permidDic) in permidTdDic
    for (td, tdDic) in permidTdDic[permid]
        permnoday = permidTdDic[permid][td]["stories"]

        restruenov = computeTopicScores(permnoday; novFilter=("nov12H",0))
        permidTdDic[permid][td]["nS_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_nov12H_0"] = restruenov[3]

        restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov12H",0))
        permidTdDic[permid][td]["nS_RES_inc_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_RES_inc_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_RES_inc_nov12H_0"] = restruenov[3]

        restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov12H",0))
        permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov12H_0"] = restruenov[3]

        restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov12H",0), abjoin=|)
        permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov12H_0"] = restruenov[3]

        restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov12H",0))
        permidTdDic[permid][td]["nS_RESF_inc_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_RESF_inc_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_RESF_inc_nov12H_0"] = restruenov[3]

        restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov12H",0))
        permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov12H_0"] = restruenov[1]
        permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov12H_0"] = restruenov[2]
        permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov12H_0"] = restruenov[3]
    end
end


client = Mongoc.Client()
database = client["Dec2018"]
collection = database["PermnoDay"]

@time for (permid, permidDict) in permidTdDic
    for (td, setDict) in permidDict
        selectDict = [Dict("permid"=>permid), Dict("td"=>td)]
        # Update all matching in MongoDB
        crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
        crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
        Mongoc.update_many(collection, crtselector, crtupdate)
    end
end
