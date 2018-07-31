push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Database management/Mongo_Queries")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using Mongo, LibBSON, JSON, WRDSdownload, TimeZones, MongoDB_queries, ArgParse

#parse args
s = ArgParseSettings()
@add_arg_table s begin
    "year"
        help = "crt year"
        required = true
        arg_type = Int
    "collection"
        help = "Mongo collection"
        required = true
        default = "copystockdateflat2"
end
parsed_args = parse_args(s)

year = parsed_args["year"]
collection = parsed_args["collection"]

# Define Mongo instance
client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
stockcoll = MongoCollection(client, "NewsDB", collection)
# Beginning and starting dates
y_start = 2003
y_end = 2017
# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060090 in case it has changed from the source.
datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"


#get all trading days
FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])
dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
unshift!(dates, Dates.DateTime(2001,12,31,20))
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
allPermIDs = collect(fieldDistinct(stockcoll, ["permid"])[1])
print("permids loaded")

print(year)
tic()
News = JSON.parsefile(replace(datapath, "@", year))
toc()
print("file loaded")

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
stockcoll = MongoCollection(client, "NewsDB", collection)

ResultDic = Dict()
for permid in allPermIDs
    ResultDic[permid]=Dict()
end

i=0
tic()
for item in News["Items"]
    i+=1
    permid = parse(item["data"]["analytics"]["analyticsScores"][1]["assetId"])
    timestamp = Dates.DateTime(item["data"]["newsItem"]["metadata"]["firstCreated"][1:end-1], "yyyy-mm-ddTHH:MM:SS.sss")
    if timestamp<=dates[end]
        td = trading_day(dates, timestamp)
        # sid = item["data"]["newsItem"]["sourceId"]
        # sid = "$(item["data"]["newsItem"]["metadata"]["altId"])$(item["data"]["newsItem"]["metadata"]["firstCreated"])"
        sid = item["data"]["newsItem"]["sourceId"][1:end-4]


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
            catch
                ResultDic[permid][td] = Dict()
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
        end #try if permid exists
        # if i>15000
        #     break
        # end
    end #if td in bounds
end
toc()


tic()
p=0
for permid in ResultDic
    p+=1
    # print("$p\n")
    for td in permid[2]
        pos = []
        neg = []
        sentClas = []
        sentClasRel = []
        posneg = []
        posnegRel = []
        posRel = []
        negRel = []
        subjects = []
        vol24H = []
        vol3D = []
        vol7D = []
        nov24H = []
        nov3D = []
        nov7D = []
        for story in td[2]
            subjects = story[2]["subjects"]
            push!(vol24H, mean(story[2]["Vol24H"]))
            push!(vol3D, mean(story[2]["Vol3D"]))
            push!(vol7D, mean(story[2]["Vol7D"]))
            push!(nov24H, mean(story[2]["Nov24H"]))
            push!(nov3D, mean(story[2]["Nov3D"]))
            push!(nov7D, mean(story[2]["Nov7D"]))
            push!(pos, mean(story[2]["pos"]))
            push!(neg, mean(story[2]["neg"]))
            push!(posRel, mean(story[2]["pos"].*story[2]["relevance"]))
            push!(negRel, mean(story[2]["neg"].*story[2]["relevance"]))
            push!(posneg, mean(story[2]["pos"].-story[2]["neg"]))
            push!(posnegRel, mean((story[2]["pos"].-story[2]["neg"]).*story[2]["relevance"]))
            push!(sentClas, mean(story[2]["sentClas"]))
            push!(sentClasRel, mean(story[2]["sentClas"].*story[2]["relevance"]))
        end
        # crtdate = story[2]["firstCreated"]
        # td = (dates, crtdate)
        if td[1]==1
            tidx=2
        else
            tidx = td[1]
        end
        update(stockcoll,
               Dict("permid"=>permid[1], "dailydate"=>Dict("\$gte"=> dates[tidx-1],"\$lt"=> dates[tidx])),
               Dict("\$set"=>Dict("pos"=>mean(pos),
                                  "td"=>tidx,
                                  "nbstories"=>length(pos),
                                  "posRel"=>mean(posRel),
                                  "vol24H"=>mean(vol24H),
                                  "vol3D"=>mean(vol3D),
                                  "vol7D"=>mean(vol7D),
                                  "nov24H"=>mean(nov24H),
                                  "nov3D"=>mean(nov3D),
                                  "nov7D"=>mean(nov7D),
                                  "negRel"=>mean(negRel),
                                  "subjects"=>subjects,
                                  "sentClas"=>mean(sentClas),
                                  "sentClasRel"=>mean(sentClasRel),
                                  "posneg"=>mean(posneg),
                                  "posnegRel"=>mean(posnegRel),
                                  "neg"=>mean(neg)))
                                  )
    end
end
toc()

print("done $year")
