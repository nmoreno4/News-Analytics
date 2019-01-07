module OrderedDictBSON

using DataStructures, Mongoc
export BSON

function BSON(dict::OrderedDict)
    result = Mongoc.BSON()

    for (k, v) in pairs(dict)
        result[k] = v
    end

    return result
end

end #module
