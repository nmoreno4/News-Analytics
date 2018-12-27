module DBstats

using Mongoc, Dates, JSON, DataStructures, JLD2

export uniqueVal

function uniqueVal(crtvar="date", rootpath="/home/nicolas/Data/MongoDB Inputs")
    client = Mongoc.Client()
    database = client["Dec2018"]
    collection = database["PermnoDay"]
    bson_result = Mongoc.command_simple(database, Mongoc.BSON("{ \"distinct\" : \"PermnoDay\", \"key\" : \"$crtvar\" }"))
    uniquevals = convert(Array{DateTime}, sort(Mongoc.as_dict(bson_result)["values"]))
    filetoSave = "$(rootpath)/unique_$(crtvar).jld2"
    JLD2.@save filetoSave uniquevals
end

end # module
