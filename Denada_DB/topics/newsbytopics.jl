using CSV
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,12) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)

using PyCall, StatsBase, Statistics, NaNMath, RCall, DataFrames, JLD, Dates, DataFramesMeta, JLD2, RollingFunctions

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]


topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "PRXF", "RECAP1", "RECLL",
          "REORG", "RES", "RESF", "SHPP", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND",""]
for i in ["_$(x)" for x in ["AAA"]]
    if i =="_"
        i=""
    end
    i = "nonews"
    print("\n $i \n")
    print(Dates.format(now(), "HH:MM"))
    chosenVars = ["roa","gsector","dailywt", "dailyretadj", "bm", "me", "dailyvol", "EAD", "ebitda", "gp", "momrank", "rankbm", "ranksize", "tobinQ", "altmanZ", "at"]
    @time res = queryDB_singlefilt_Dic("permno", tdperiods, chosenVars, [-1,999999999], mongo_collection)
    @time resdf = queryDic_to_df(res[1] , res[2])
    try
        delete!(resdf, :_id)
        [resdf[resdf[nm] .== nothing, nm] = NaN for nm in names(resdf)]
        # CSV.write("/run/media/nicolas/Research/DenadaDB/CSVs/N$(i).csv", resdf)
        show(resdf)
    catch
        print("there was a problem")
    end
end
