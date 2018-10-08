using JSON, ArgParse, JLD2, Dates
function trading_day(dates, crtdate, offset = Dates.Hour(0))
  i=0
  res = 0
  for d in dates
    i+=1
    if dates[i]-offset < crtdate <= dates[i+1]-offset
      return i
      break
    end
  end
  return res
end

#parse args
s = ArgParseSettings()
@add_arg_table s begin
    "year"
        help = "crt year"
        required = true
        arg_type = Int
    "machine"
        help = "machine"
        required = false
        default = "Vega"
end
parsed_args = parse_args(s)

y = parsed_args["year"]
machine = parsed_args["machine"]

nb_split = 10
# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060090 in case it has changed from the source.
if machine == "local"
    include("/home/nicolas/Code/News-Analytics/Denada_DB/TRNA/TRNAfcts.jl")
    datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"
    JLD2.@load "/home/nicolas/Data/Inputs/dates.jld2"
elseif machine== "Vega"
    include("/home/ulg/affe/nmoreno/Code/Code/News-Analytics/Denada_DB/TRNA/TRNAfcts.jl")
    datapath = "/home/ulg/affe/nmoreno/Reuters/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"
    JLD2.@load "/home/ulg/affe/nmoreno/Data/Inputs/Inputs/dates.jld2"
end

print("Everything loaded!")

@time News = JSON.parsefile(replace(datapath, "@"=>y))
print("file $(y) loaded")
ResultDic = Dict()
permidslostinoblivion = []
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
                push!(ResultDic[permid][td][sid]["subjects"], item["data"]["newsItem"]["subjects"])
                # ResultDic[permid][td][sid]["subjects"] = collect(Set(ResultDic[permid][td][sid]["subjects"]))
            catch
                ResultDic[permid][td][sid] = Dict(
                    "firstCreated"=>item["data"]["newsItem"]["metadata"]["firstCreated"],
                    "subjects"=>[item["data"]["newsItem"]["subjects"]],
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

@time Splitted = splitDic(ResultDic, nb_split)

@time for i in 1:nb_split
    partDic = Splitted[i]
    if machine == "local"
        JLD2.@save "/home/nicolas/Data/Intermediate/Dic_$(y)_p$(i).jld2" partDic
    elseif machine== "Vega"
        JLD2.@save "/home/ulg/affe/nmoreno/Data/Intermediate/splitDic/Dic_$(y)_p$(i).jld2" partDic
    end
end
