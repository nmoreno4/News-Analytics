using PyCall, CSV, DataFrames
@pyimport pymongo
@pyimport datetime
client = pymongo.MongoClient()
db = client[:News]
collection = db[:daily_agg]

matched = CSV.read("/home/nicolas/Data/permidmatch/matched.csv");

@time for row in eachrow(dailyDF)
    insertDic = Dict{String,Any}()
    for var in names(dailyDF)
        if !ismissing(row[var])
            insertDic[String(var)] = row[var]
        else
            insertDic[String(var)] = nothing
        end
    end
    collection[:insert_one](insertDic)
end;
