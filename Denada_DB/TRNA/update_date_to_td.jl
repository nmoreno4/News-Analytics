### This script recomputes td in the flattened DB collection and updates all fields ###

push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
using Mongo, WRDSdownload, TimeZones

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "copyflatstockdate")

#get all trading days
y_start = 2003
y_end = 2017
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

cursor = find(TRNAcoll,
            Mongo.query())

i = 0
for entry in cursor
  i+=1
  permno = entry["permno"]
  date = entry["dailydate"]
  td = trading_day(dates, date)
  update(TRNAcoll,
         Dict("permno"=>permno, "dailydate"=>Dict("\$gt"=> dates[td-1],"\$lte"=> dates[td])),
         Dict("\$set"=>Dict("td"=>td))
         )
  if i%100000==0
    print(i)
  end
end
