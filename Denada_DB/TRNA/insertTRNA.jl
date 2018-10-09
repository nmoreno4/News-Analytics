using JSON, TimeZones, ArgParse, PyCall, Dates, Statistics, JLD2

# Set global variables
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/Denada_DB/TRNA/TRNAfctsbis.jl")
include("$(laptop)/Denada_DB/WRDS/WRDSdownload.jl")
novrelfilters = [(100, "24H"), (50, "3D"), (0,0)]
variables = ["pos", "neg", "sent", "nbStories"]
topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "PRXF", "RECAP1", "RECLL",
          "REORG", "RES", "RESF", "SHPP", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND"]

# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060090 in case it has changed from the source.
datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060090.JSON.txt"

# Get all trading days
y_start, y_end = 2003, 2017
FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])
dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
pushfirst!(dates, Dates.DateTime(2001,12,31,20))
dates = [ZonedDateTime(d, tz"America/New_York") for d in dates]
dates = [DateTime(astimezone(d, tz"UTC")) for d in dates]

# Prepare MongoDB connection
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[Symbol("daily_CRSP_CS_TRNA")]

y, i = 2006, 1
JLD2.@load "/run/media/nicolas/Research/Data/Intermediate/splitDic/Dic_$(y)_p$(i).jld2" partDic
ResultDic = partDic
print("Dic_$(y)_p$(i).jld2 loaded")
permid = ResultDic[1]

cc = Any[0,0]
@time for permid in ResultDic
    cc[1]+=1
    for td in permid[2]
        tdstories = tdFilter(td, variables, novrelfilters, topics, false)
        tdstories = allToTuple!(tdstories)
        cc[2] = copy(tdstories)
        if td[1]<length(dates) #Make sure I don't have news after my last trading day
            # tdstories["date"]=dates[td[1]+1]
            collection[:update_one](
                    Dict("\$and"=> [
                                    Dict("permid"=>permid[1]),
                                    Dict("td"=> td[1])
                                    ]),
                    Dict("\$set"=>tdstories))
        end
    end #for td
    if cc[1]>100
        break
    end
end #for permid
