push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Database management/Mongo_Queries")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using Mongo, TimeZones, WRDSdownload, DataFrames, CSV
import DFmanipulation: deletemissingrows!

senttype = "sentClasRel"
dftosavename = "rawpanel1"

### Load mongo client ###
client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "copyflatstockdate")

### Load dates and trading days ###
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


### Query all entries ###
cursor = find(TRNAcoll,
            Mongo.query())

### Populate Arraywith data for each date-permno pair ###
### permno - td - dailyretadj - sent - dummy newsday - rankbm - 10by10_size_value - EAD ###
df = Array{Any}(14082497,8)
i = 0
for entry in cursor
  i+=1
  sent = 0
  newsday = 0
  td = trading_day(dates, entry["dailydate"])
  try
    sent = entry[senttype]
    newsday = 1
  end
  row = [entry["permno"],  td, entry["dailyretadj"], sent, newsday, entry["rankbm"], entry["ptf_10by10_size_value"], entry["EAD"]]
  df[i,:] = row
  if i%100000==0
    print(i)
  end
end

### Save raw DataFrame ###
df = DataFrames.DataFrame(df)
names!(df, [:permno, :td, :retadj, :sent, :newsday, :rankbm, :ptf_5by5, :EAD])
CSV.write("/home/nicolas/Data/Intermediate/$(dftosavename).csv", df)



df[:ret3days] = NaN
df[:sent3days] = NaN
df[:EAD3days] = NaN
df[:ret5days] = NaN
df[:sent5days] = NaN
df[:EAD5days] = NaN
df[:ret10days] = NaN
df[:sent10days] = NaN
df[:EAD10days] = NaN
df[:ret20days] = NaN
df[:sent20days] = NaN
df[:EAD20days] = NaN
df[:ret60days] = NaN
df[:sent60days] = NaN
df[:EAD60days] = NaN
df[:tokeep3days] = NaN
df[:tokeep5days] = NaN
df[:tokeep10days] = NaN
df[:tokeep20days] = NaN
df[:tokeep60days] = NaN

df = by(df, :permno, pastreturn)

df10 = deletemissingrows!(deepcopy(df), :ret10days, "NaN")
df5 = deletemissingrows!(deepcopy(df), :ret5days, "NaN")
df3= deletemissingrows!(deepcopy(df), :ret3days, "NaN")

by(df10, :permno, keeponeobsperiod)
by(df5, :permno, keeponeobsperiod)
by(df3, :permno, keeponeobsperiod)

df10bis = deletemissingrows!(deepcopy(df), :tokeep10days, "NaN")
df5bis = deletemissingrows!(deepcopy(df), :tokeep5days, "NaN")
df3bis = deletemissingrows!(deepcopy(df), :tokeep3days, "NaN")

df10[[:td, :permno, :sent, :ret10days, :sent10days, :EAD10days]][1:15,:]

pastreturn(groupeddf[1], 3)[[:retadj, :ret3days]]

function lagvariables(subdf)
end

function keeponeobsperiod(subdf, nbdays = 3)
  i = 0
  for row in eachrow(subdf)
    i+=1
    if (i-1)%nbdays == 0
      row[Symbol("tokeep$(nbdays)days")] = 1
    end
  end
  return subdf
end

function shiftpush(X,x)
  shift!(X)
  push!(X, x)
  return X
end

function cumret(X)
  start = 1
  for x in X
    start*=(1+x)
  end
  res = start - 1
  return res
end

function meanexclude(X, toexclude = 0)
  res = Float64[]
  for x in X
    if x!= toexclude
      push!(res, x)
    end
  end
  if length(res)==0
    push!(res,0)
  end
  return mean(res)
end

function pastreturn(subdf, nbdays=10)
  lastreturns = []
  lastsents = []
  lastEAD = []
  for row in eachrow(subdf)
    if length(lastreturns)==nbdays
      lastreturns = shiftpush(lastreturns, row[:retadj])
      lastsents = shiftpush(lastsents, row[:sent])
      lastEAD = shiftpush(lastEAD, row[:EAD])
      row[Symbol("ret$(nbdays)days")] = cumret(lastreturns)
      row[Symbol("sent$(nbdays)days")] = meanexclude(lastsents)
      row[Symbol("EAD$(nbdays)days")] = sum(lastEAD)
    else
      push!(lastreturns, row[:retadj])
      push!(lastsents, row[:sent])
      push!(lastEAD, row[:EAD])
      if length(lastreturns)==nbdays
        row[Symbol("ret$(nbdays)days")] = cumret(lastreturns)
        row[Symbol("sent$(nbdays)days")] = meanexclude(lastsents)
        row[Symbol("EAD$(nbdays)days")] = sum(lastEAD)
      else
        row[Symbol("ret$(nbdays)days")] = NaN
        row[Symbol("sent$(nbdays)days")] = NaN
        row[Symbol("EAD$(nbdays)days")] = NaN
      end
    end
  end
  return subdf
end


function isvalue(x)
  if x=="H"
    return 1
  else
    return 0
  end
end

function isgrowth(x)
  if x=="L"
    return 1
  else
    return 0
  end
end

function issmall(x)
  if floor(x)==1
    return 1
  else
    return 0
  end
end


df[:test] = collect(zip(df[:permid],df[:td]))
Set(df[:test])
df[:ones] = 1
a = df[[:test, :ones]]
a = find(nonunique(a))

deleterows!(df, a)

df[:isvalue] = map(isvalue, df[:rankbm])
df[:isgrowth] = map(isgrowth, df[:rankbm])
df[:issmall] = map(isgrowth, df[:rankbm])


using RCall
@rlibrary plm

@rput df
R"df <- as.data.frame(lapply(df, unlist))"
R"E <- plm::pdata.frame(df, index = c('permid', 'td'), drop.index=TRUE, row.names=TRUE)"
R"head(E)"

R"model <- plm::plm(retadj~sent+sent*isvalue, data=E, model = 'within')"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
