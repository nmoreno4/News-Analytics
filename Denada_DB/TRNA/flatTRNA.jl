using JSON, TimeZones, ArgParse, PyCall, Dates, Statistics, JLD2
laptop = "/home/nicolas/News-Analytics"
include("$(laptop)/Denada_DB/TRNA/TRNAfcts.jl")
include("$(laptop)/Denada_DB/WRDS/WRDSdownload.jl")
y=2003
method = "dictlike"
relthresh = 50
novspan = "24H"

#parse args
# s = ArgParseSettings()
# @add_arg_table s begin
#     "year"
#         help = "crt year"
#         required = true
#         arg_type = Int
#     "collection"
#         help = "Mongo collection"
#         required = false
#         default = "copystockdateflat2"
# end
# parsed_args = parse_args(s)
#
# y = parsed_args["year"]
# collection = parsed_args["collection"]

# Beginning and starting dates
y_start = 2003
y_end = 2017
# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060090 in case it has changed from the source.
datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"
datapath = "/run/media/nicolas/OtherData/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"


#get all trading days
FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])
dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
pushfirst!(dates, Dates.DateTime(2001,12,31,20))
dates = [ZonedDateTime(d, tz"America/New_York") for d in dates]
dates = [DateTime(astimezone(d, tz"UTC")) for d in dates]
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

@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[Symbol("copy_daily_CRSP_CS_TRNA")]
myvars = ["pos", "neg", "neut", "sentClas", "subjects"]
myvars = []

####!!!####
#Re-decomment!!!#
####!!!####
aggvars = ["pos", "neg", "neut", "sentClas", "spread"]
aggvars = []


# collection = db[:test]
# collection[:insert_one](ResultDic[4295860884][87])

#Must still do 2005!!!
for y in 2006
    ispan = 1:10
    if y == 2020
        ispan = 2:10
    end
    for i in ispan

        ResultDic = Dict()
        permidslostinoblivion = []

        @time if y>=2006
            JLD2.@load "/run/media/nicolas/Research/Data/Intermediate/splitDic/Dic_$(y)_p$(i).jld2" partDic
            ResultDic = partDic
            print("Dic_$(y)_p$(i).jld2 loaded")
        else
            if i>1
                break
            end
            @time partDic = JSON.parsefile(replace(datapath, "@"=>y))["Items"]
            @time for i in 1:length(partDic)
                item = partDic[i]
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
        end

        pcount = [0]
        @time for permid in ResultDic
            pcount[1]+=1
            print("$(pcount[1])-$(permid[1])-")
          # round(length(ResultDic)/p[1])%10==0 ? print("Stored $(round(100*p[1]/length(ResultDic))) %") :
            for td in permid[2]
                # tdstories = meansumtakes(td, myvars, relthresh, novspan)
                tdstories = dzielinskiandsum(td, myvars, relthresh, novspan)
                for pair in tdstories
                    if pair[1][1:3] == "dzi" || pair[1][1:3] == "nbS"
                        tdstories[pair[1]] = pair[2]
                    elseif pair[1] == "storyID"
                        tdstories[pair[1]] = tuple(pair[2]...)
                    elseif typeof(pair[2])!=Vector{Float64}
                        tdstories[pair[1]] = tuplerize(pair[2])
                        tdstories[pair[1]] = tuple(tdstories[pair[1]]...)
                    else
                        tdstories[pair[1]] = tuple(pair[2]...)
                    end
                end
                for var in aggvars
                    tdstories["$(var)_m"] = mean(tdstories["mean_$(var)"])
                    tdstories["$(var)_s"] = sum(tdstories["mean_$(var)"])
                    tdstories["rel_$(var)_m"] = mean(tdstories["mean_rel_$(var)"])
                    tdstories["rel_$(var)_s"] = sum(tdstories["mean_rel_$(var)"])
                    tdstories["novrel_$(var)_m"] = mean(tdstories["mean_novrel_$(var)"])
                    tdstories["novrel_$(var)_s"] = sum(tdstories["mean_novrel_$(var)"])
                    # print("\n $(tdstories["mean_$(var)_rel$(relthresh)nov$(novspan)"])")
                    # print("\n $( mean(tdstories["mean_$(var)_rel$(relthresh)nov$(novspan)"]))")
                    if haskey(tdstories, "mean_$(var)_rel$(relthresh)")
                        tdstories["$(var)_rel$(relthresh)_m"] = mean(tdstories["mean_$(var)_rel$(relthresh)"])
                        tdstories["$(var)_rel$(relthresh)_s"] = sum(tdstories["mean_$(var)_rel$(relthresh)"])
                    end
                    if haskey(tdstories, "mean_$(var)_rel$(relthresh)nov$(novspan)")
                        tdstories["$(var)_rel$(relthresh)nov$(novspan)_m"] = mean(tdstories["mean_$(var)_rel$(relthresh)nov$(novspan)"])
                        tdstories["$(var)_rel$(relthresh)nov$(novspan)_s"] = sum(tdstories["mean_$(var)_rel$(relthresh)nov$(novspan)"])
                    end
                    if haskey(tdstories, "mean_$(var)_nov$(novspan)")
                        tdstories["$(var)_nov$(novspan)_m"] = mean(tdstories["mean_$(var)_nov$(novspan)"])
                        tdstories["$(var)_nov$(novspan)_s"] = sum(tdstories["mean_$(var)_nov$(novspan)"])
                    end
                end

                #####Add BACK!!!##
                #####!!!!!!!!!!!!!!!!!!Add BACK!!!##
                # tdstories["rawStories"]=td[2]
                #####Add BACK!!!##

                # tdstories["permid"]=permid[1]
                # tdstories["td"]=td[1]
                if td[1]<length(dates)
                    tdstories["date"]=dates[td[1]+1]
                    collection[:update_one](
                            Dict("\$and"=> [
                                            Dict("permid"=>permid[1]),
                                            Dict("td"=> td[1])
                                            ]),
                            Dict("\$set"=>tdstories))
                end
            end
        end
    end
    print("done $y")
end
