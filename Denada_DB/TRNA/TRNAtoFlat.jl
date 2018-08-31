push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Database management/Mongo_Queries")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using Mongo, WRDSdownload, TimeZones, MongoDB_queries
date = Dates.DateTime(2003,5,29,1,23)
permid = 4295914990
y_start = 2003
y_end = 2017

FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])
dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
unshift!(dates, Dates.DateTime(2002,12,31,20))
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

td = trading_day(dates, date)

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "News")
stockcoll = MongoCollection(client, "NewsDB", "copystockdateflat")
c = getAnalyticsCursor(TRNAcoll, dates[td-1], dates[td+1000], permid)

for i in c
  print(i["_id"])
end


cursor = find(stockcoll, Mongo.query())
i = 0
sc = 0
tic()
for entry in cursor
  i+=1
  if i > 550000
    c = getAnalyticsCursor(TRNAcoll, dates[td-1], dates[td+200], permid)
    break
  end
  date = entry["dailydate"]
  permid = entry["permid"]
  td = trading_day(dates, date)
  c = getAnalyticsCursor(TRNAcoll, dates[td-1], dates[td], permid)
  csc = 0
  newsarray = []
  for story in c
    sc+=1
    csc+=1
    push!(newsarray, story)
  end
  na = copy(newsarray)
  newsarray, dupcount = removeduplicateTRNA(newsarray)
  # if dupcount>1
  #   print(na)
  # end
  storiescount = length(newsarray)
  if csc > 0
    allstories, alltakes, subjects, takescount = storeTRNA(newsarray, permid)
    print("dup: $dupcount  -  sc: $storiescount tc: $takescount \n")
    # if takescount>12
    #   break
    # end
  end
end
toc()

function removeduplicateTRNA(newsarray)
  uids = []
  result =[]
  for n in newsarray
    if !(n["_id"] in uids)
      push!(uids, n["_id"])
      push!(result, n)
    end
  end
  dupcount = length(newsarray) - length(result)
  return result, dupcount
end

function storeTRNA(newsarray, permid)
  takescount = 0
  subjects = []
  alltakes = Dict("pos"=>[], "neg"=>[], "neut"=>[], "sentClas"=>[], "rel"=>[], "Nov1D"=>[],
                  "Nov3D"=>[], "Nov7D"=>[], "Vol1D"=>[], "Vol3D"=>[], "Vol7D"=>[])
  allstories = Dict("pos"=>[], "neg"=>[], "neut"=>[], "sentClas"=>[], "rel"=>[], "Nov1D"=>[],
                  "Nov3D"=>[], "Nov7D"=>[], "Vol1D"=>[], "Vol3D"=>[], "Vol7D"=>[])
  for crtstory in newsarray
    storytakes = Dict("pos"=>[], "neg"=>[], "neut"=>[], "sentClas"=>[], "rel"=>[], "Nov1D"=>[],
                    "Nov3D"=>[], "Nov7D"=>[], "Vol1D"=>[], "Vol3D"=>[], "Vol7D"=>[])
    for crttake in crtstory["takes"]
      push!(subjects, collect(crttake["subjects"]))
      for ana in crttake["analytics"]
        if parse(ana["assetId"])==permid
          takescount+=1
          push!(alltakes["pos"], ana["sentimentPositive"])
          push!(alltakes["neg"], ana["sentimentNegative"])
          push!(alltakes["neut"], ana["sentimentNeutral"])
          push!(alltakes["sentClas"], ana["sentimentClass"])
          push!(alltakes["rel"], ana["relevance"])
          push!(alltakes["Nov1D"], ana["noveltyCounts"][2]["itemCount"])
          push!(alltakes["Nov3D"], ana["noveltyCounts"][3]["itemCount"])
          push!(alltakes["Nov7D"], ana["noveltyCounts"][5]["itemCount"])
          push!(alltakes["Vol1D"], ana["volumeCounts"][2]["itemCount"])
          push!(alltakes["Vol3D"], ana["volumeCounts"][3]["itemCount"])
          push!(alltakes["Vol7D"], ana["volumeCounts"][5]["itemCount"])
          push!(storytakes["pos"], ana["sentimentPositive"])
          push!(storytakes["neg"], ana["sentimentNegative"])
          push!(storytakes["neut"], ana["sentimentNeutral"])
          push!(storytakes["sentClas"], ana["sentimentClass"])
          push!(storytakes["rel"], ana["relevance"])
          push!(storytakes["Nov1D"], ana["noveltyCounts"][2]["itemCount"])
          push!(storytakes["Nov3D"], ana["noveltyCounts"][3]["itemCount"])
          push!(storytakes["Nov7D"], ana["noveltyCounts"][5]["itemCount"])
          push!(storytakes["Vol1D"], ana["volumeCounts"][2]["itemCount"])
          push!(storytakes["Vol3D"], ana["volumeCounts"][3]["itemCount"])
          push!(storytakes["Vol7D"], ana["volumeCounts"][5]["itemCount"])
        end
      end
    end
    # print("\n\n\n\n\n\n=====\n\n\n\n\n")
    # print(crtstory)
    push!(allstories["pos"],mean(storytakes["pos"]))
    push!(allstories["neg"], mean(storytakes["neg"]))
    push!(allstories["neut"],mean(storytakes["neut"]))
    push!(allstories["sentClas"], mean(storytakes["sentClas"]))
    push!(allstories["rel"], mean(storytakes["rel"]))
    push!(allstories["Nov1D"], mean(storytakes["Nov1D"]))
    push!(allstories["Nov3D"], mean(storytakes["Nov3D"]))
    push!(allstories["Nov7D"], mean(storytakes["Nov7D"]))
    push!(allstories["Vol1D"], mean(storytakes["Vol1D"]))
    push!(allstories["Vol3D"], mean(storytakes["Vol3D"]))
    push!(allstories["Vol7D"], mean(storytakes["Vol7D"]))
  end
  subjects = Set(subjects)
  return allstories, alltakes, subjects, takescount
end #fct storTRNA


parse(newsarray[1]["takes"][1]["analytics"][1]["assetId"])
collect(newsarray[1]["takes"][1]["subjects"])
