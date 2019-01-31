using PyCall
pymongo = pyimport("pymongo")
client = pymongo[:MongoClient]()
db = client["Jan2019"]
collection = db["PermnoDay"]
pydatetime = pyimport("datetime")
@time collect(collection[:find](Dict("permid"=> 4295904980, "td"=> Dict("\$gt"=> 0)), Dict("td"=>1)))
@time collect(collection[:find](Dict("nS_RESF_inc_nov24H_0_rel0"=> Dict("\$gt"=> 0)), Dict("stories.bodyArchive"=>1)))

@time a = collect(collection[:find](Dict("td"=> Dict("\$gte"=> 1, "\$lte"=> 3776)), Dict("nS_nov24H_0_rel0"=>1, "permno"=>1, "td"=>1)))



using QueryMongo
