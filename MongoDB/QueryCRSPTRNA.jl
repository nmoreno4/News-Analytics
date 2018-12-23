using Mongoc, Dates, JSON
client = Mongoc.Client()
database = client["Denada"]

################ test ####################
collection = database["test"]
document = Dict("birth date" => DateTime(1983, 4, 16), "location" => "Paris", "w" => ["er", 3])
result = push!(collection, Mongoc.BSON(document))
crtfilt = [Dict("birth date" => DateTime(1983, 4, 16)), Dict("location" => 1)]
crtfilt = Dict("birth date" => DateTime(1983, 4, 16))
crtfilt = Mongoc.BSON("{ \"location\" : \"Paris\"}")
a = Mongoc.find_one(collection,crtfilt)
b = Mongoc.as_dict(a)
b["w"]
##########################################


collection = database["daily_CRSP_CS_TRNA"]
bmfilt = Dict("\$gte"=>1, "\$lte"=>3)
tdfilt = Dict("\$gte"=>1, "\$lte"=>3)
crtfilter = Mongoc.BSON(Dict("td"=>tdfilt, "bmdecile"=>bmfilt, "sizedecile"=>4))
foo = Mongoc.find_one(collection,crtfilter)

res = []
@time for document in Mongoc.find(collection,crtfilter)
    push!(res,  JSON.parse(Mongoc.as_json(document)))
end

length(collection,crtfilter)

@time a = Mongoc.as_dict(Mongoc.find_one(collection,crtfilter))

@time let
b = collect(Mongoc.find(collection,crtfilter))
vartokeep = ["td", "permno", "bmdecile", "dailyretadj"]
c = []
for doc in b
    crtdict = JSON.parse(Mongoc.as_json(doc))
    for (key, val) in crtdict
        if !(key in vartokeep)
            delete!(crtdict, key)
        end
    end
    push!(c, crtdict)
end
end
