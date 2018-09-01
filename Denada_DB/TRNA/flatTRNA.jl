using JSON, TimeZones, ArgParse, PyCall, Dates
include("/home/nicolas/Code/News-Analytics/Denada_DB/TRNA/TRNAfcts.jl")
y=2003

#parse args
s = ArgParseSettings()
@add_arg_table s begin
    "year"
        help = "crt year"
        required = true
        arg_type = Int
    "collection"
        help = "Mongo collection"
        required = false
        default = "copystockdateflat2"
end
parsed_args = parse_args(s)

y = parsed_args["year"]
collection = parsed_args["collection"]

# Beginning and starting dates
y_start = 2003
y_end = 2017
# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060090 in case it has changed from the source.
datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"


#get all trading days
FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])
dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
pushfirst!(dates, Dates.DateTime(2001,12,31,20))
dates = [ZonedDateTime(d, tz"America/New_York") for d in dates]
dates = [DateTime(astimezone(d, tz"UTC")) for d in dates]
function trading_day(dates, crtdate)
  i=0
  res = 0
  if crtdate < dates[i+1] # if first date
    res = i+1
  end
  for d in dates
    i+=1
    if dates[i] < crtdate <= dates[i+1]
      res = i+1
      break
    end
  end
  return res
end

#get all unique permids
# @pyimport pymongo
# client = pymongo.MongoClient()
# db = client[:NewsDB]
# collection = db[:Companies]
# allPermIDs = collection[:find](Dict())[:distinct]("permID")

@time News = JSON.parsefile(replace(datapath, "@"=>y))
print("file $(y) loaded")

ResultDic = Dict()
# for permid in allPermIDs
#     ResultDic[permid]=Dict()
# end


@time for i in 1:length(News["Items"])
    item = News["Items"][i]
    permid = parse(Int, item["data"]["analytics"]["analyticsScores"][1]["assetId"])
    timestamp = Dates.DateTime(item["data"]["newsItem"]["metadata"]["firstCreated"][1:end-1], "yyyy-mm-ddTHH:MM:SS.sss")
    if timestamp<=dates[end]
        td = trading_day(dates, timestamp)
        # sid = item["data"]["newsItem"]["sourceId"]
        # sid = "$(item["data"]["newsItem"]["metadata"]["altId"])$(item["data"]["newsItem"]["metadata"]["firstCreated"])"
        # sid = item["data"]["newsItem"]["sourceId"][1:end-4]
        sid = "$(td)-$(item["data"]["newsItem"]["metadata"]["altId"])"
        try
            a = ResultDic[permid]
        catch
            ResultDic[permid] = Dict()
        end
        try
            a = ResultDic[permid][td]
        catch
            ResultDic[permid][td] = Dict()
        end
        try
            try
                push!(ResultDic[permid][td][sid]["relevance"], item["data"]["analytics"]["analyticsScores"][1]["relevance"])
                push!(ResultDic[permid][td][sid]["Nov24H"], item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][2]["itemCount"])
                push!(ResultDic[permid][td][sid]["Nov3D"], item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][3]["itemCount"])
                push!(ResultDic[permid][td][sid]["Nov7D"], item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][5]["itemCount"])
                push!(ResultDic[permid][td][sid]["Vol24H"], item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][2]["itemCount"])
                push!(ResultDic[permid][td][sid]["Vol3D"], item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][3]["itemCount"])
                push!(ResultDic[permid][td][sid]["Vol7D"], item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][5]["itemCount"])
                push!(ResultDic[permid][td][sid]["pos"], item["data"]["analytics"]["analyticsScores"][1]["sentimentPositive"])
                push!(ResultDic[permid][td][sid]["neg"], item["data"]["analytics"]["analyticsScores"][1]["sentimentNegative"])
                push!(ResultDic[permid][td][sid]["neut"], item["data"]["analytics"]["analyticsScores"][1]["sentimentNeutral"])
                push!(ResultDic[permid][td][sid]["sentClas"], item["data"]["analytics"]["analyticsScores"][1]["sentimentClass"])
                append!(ResultDic[permid][td][sid]["subjects"], item["data"]["newsItem"]["subjects"])
                ResultDic[permid][td][sid]["subjects"] = collect(Set(ResultDic[permid][td][sid]["subjects"]))
            catch
                ResultDic[permid][td][sid] = Dict(
                    "firstCreated"=>item["data"]["newsItem"]["metadata"]["firstCreated"],
                    "subjects"=>item["data"]["newsItem"]["subjects"],
                    "relevance"=>[item["data"]["analytics"]["analyticsScores"][1]["relevance"]],
                    "Nov24H"=>[item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][2]["itemCount"]],
                    "Nov3D"=>[item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][3]["itemCount"]],
                    "Nov7D"=>[item["data"]["analytics"]["analyticsScores"][1]["noveltyCounts"][5]["itemCount"]],
                    "Vol24H"=>[item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][2]["itemCount"]],
                    "Vol3D"=>[item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][3]["itemCount"]],
                    "Vol7D"=>[item["data"]["analytics"]["analyticsScores"][1]["volumeCounts"][5]["itemCount"]],
                    "pos"=>[item["data"]["analytics"]["analyticsScores"][1]["sentimentPositive"]],
                    "neg"=>[item["data"]["analytics"]["analyticsScores"][1]["sentimentNegative"]],
                    "neut"=>[item["data"]["analytics"]["analyticsScores"][1]["sentimentNeutral"]],
                    "sentClas"=>[item["data"]["analytics"]["analyticsScores"][1]["sentimentClass"]]
                )
            end
        catch
        end #try if permid exists
        # if i>15000
        #     break
        # end
    else
        push!(permidslostinoblivion, permid)
    end #if td in bounds
end

# counter = [0, Dict(), Dict(), Dict()]
# for dic in ResultDic
#     if length(dic[2])>0
#         counter[3] = dic
#         for subdic in dic[2]
#             if length(subdic[2])>0
#                 counter[4] = subdic
#                 for subsubdic in subdic[2]
#                     if length(subsubdic[2]["pos"])>1
#                         counter[1]+=1
#                         counter[2] = subsubdic[2]
#                     end
#                 end
#             end
#         end
#     end
# end

# for i in ResultDic[4295905573]
#     print(length(i))
# end

@time JLD2.@load "/home/nicolas/Data/Intermediate/testResultDic.jld2"

@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[:TRNA]
p=[0]
myvars = ["pos", "neg", "neut", "sentClas", "subjects"]
@time for permid in ResultDic
    p[1]+=1
    length(ResultDic)%p[1]==0 ? print("$(round(100*p[1]/length(ResultDic)))") :
    for td in permid[2]
        tdstories = meansumtakes(td, myvars)
        tdDic = Dict()
        for var in myvars[1:end-1]
            tdDic["$(var)_m"] = mean(tdstories["mean_$(var)"])
            tdDic["$(var)_s"] = sum(tdstories["mean_$(var)"])
            tdDic["rel_$(var)_m"] = mean(tdstories["mean_rel_$(var)"])
            tdDic["rel_$(var)_s"] = sum(tdstories["mean_rel_$(var)"])
            tdDic["novrel_$(var)_m"] = mean(tdstories["mean_novrel_$(var)"])
            tdDic["novrel_$(var)_s"] = sum(tdstories["mean_novrel_$(var)"])
        end
        tdDic["nbStories"]=length(tdstories["mean_$(myvars[1])"])
        tdDic["subjects"]=collect(Set(tdstories["subjects"]))
        tdDic["permid"]=permid[1]
        tdDic["td"]=td[1]
        tdDic["date"]=dates[td[1]+1]
        collection[:insert_one](tdDic)
    end
end


print("done $year")
