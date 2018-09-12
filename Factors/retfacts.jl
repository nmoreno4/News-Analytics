using PyCall
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[Symbol("daily_CRSP_CS")]

pynull = py"None"
@time cursor = collect(collection[:find](Dict("\$and" => [
                Dict("rankbm"=>1),
                Dict("td"=> 1)
                ])))

db.daily_CRSP_CS.aggregate({$match:{$and:[{td:1}]}},{$group:{_id:null, sum:{$sum:"$wt"}}})
collection[:aggregate](Dict("\$match"=>
                                Dict("\$and"=>[
                                    Dict("td"=>1)
                                ])),
                        Dict("\$group"=>Dict(
                            Dict("_id"=>1),
                            Dict("sum"=>Dict("\$sum"=>"wt"))
                        )))

a = Dict{String, Union{Array{Float64}, Float64}}("retwt" => Float64[], "wt" => 0.0)
@time for entry in cursor
    push!(a["retwt"], entry["retadj"]*entry["wt"])
    a["wt"]+=entry["wt"]
end
