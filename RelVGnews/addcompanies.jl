using Mongo
using LibBSON
using JSON
using CSV
using DataFrames

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
Companies = MongoCollection(client, "NewsDB", "Companies")

df = CSV.read("/home/nicolas/Reuters/TRNA/Companies/EN/BASIC/TRNA.Companies.EN.BASIC.090.csv", rows_for_type_detect=100000)

i = 0
row = 0
ticker =0
for row in eachrow(df)
  if ismissing(row[1])
    PermID = ""
    i+=1
  else
    PermID=row[1]
  end
  if ismissing(row[2])
    companyName = ""
  else
    companyName=row[2]
  end
  if ismissing(row[3])
    countryOfDomicile = ""
  else
    countryOfDomicile=row[3]
  end
  if ismissing(row[4])
    TRBCEconomicSector = ""
  else
    TRBCEconomicSector=row[4]
  end
  if ismissing(row[5])
    status = ""
  else
    status=row[5]
  end
  if ismissing(row[6])
    RIC = ""
  else
    RIC=row[6]
  end
  if ismissing(row[7])
    ticker = ""
  else
    ticker=row[7]
  end
  if ismissing(row[8])
    marketMIC = ""
  else
    marketMIC=row[8]
  end

  insert(Companies, Dict("ticker"=>ticker, "COMNAM"=>lowercase(companyName),
                         "country"=>countryOfDomicile, "sector"=>TRBCEconomicSector,
                         "status"=>status, "RIC"=>RIC, "marketMIC"=>marketMIC,
                         "permID"=>PermID))
end
