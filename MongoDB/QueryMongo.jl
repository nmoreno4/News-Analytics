module QueryMongo

using Mongoc, Dates, JSON, DataFrames, OrderedDictBSON, DataStructures
export queryDF, testQuery, gatherData


function queryDF(returnVars, initArrays, filters... ; dbname="Dec2018", collname="PermnoDay")
    client = Mongoc.Client()
    database = client[dbname]
    collection = database[collname]

    resDic = Dict(zip(returnVars, initArrays))

    crtfilter = OrderedDict()
    for filt in filters
        if length(filt[2])>1
            filt[2] = Dict("\$gte"=>filt[2][1], "\$lte"=>filt[2][2])
        end
        crtfilter[filt[1]] = filt[2]
    end
    crtfilter = OrderedDictBSON.BSON(crtfilter)
    print(crtfilter)

    dbCursor = Mongoc.find(collection,crtfilter)
    i=0
    for el in dbCursor
        i+=1
        for crtvar in returnVars
            try
                push!(resDic[crtvar], el[crtvar])
            catch
                push!(resDic[crtvar], missing)
            end
        end
    end

    return DataFrame(resDic)
end


function testQuery(dbname="Dec2018", collname="PermnoDay")
    client = Mongoc.Client()
    database = client[dbname]
    collection = database[collname]
    dbCursor = Mongoc.find_one(collection)
    return Mongoc.as_dict(dbCursor)
end


function gatherData(tdrange, retvals, iniArrays;
                    ptfnames = ["BG", "BV", "SG", "SV", "ALL"],
                    ptfs = [("tdF", "BigF", "GrowthF"), ("tdF", "BigF", "ValueF"),
                            ("tdF", "SmallF", "GrowthF"), ("tdF", "SmallF", "ValueF"),
                            ("tdF", "SizeA", "ValueA")],
                    szvar = "ranksize", bmvar = "rankbm" )

    raw = Dict()
    cc = 1
    filters = Dict( "tdF" => ["td", tdrange],
                    "BigF" => [szvar, (6,10)],
                    "SmallF" => [szvar, (1,5)],
                    "GrowthF" => [bmvar, (1,3)],
                    "ValueF" => [bmvar, (8,10)],
                    "SizeA" => [szvar, (1,10)],
                    "ValueA" => [bmvar, (1,10)],
                    "V1" => [bmvar, (1,1)],
                    "V2" => [bmvar, (2,2)],
                    "V3" => [bmvar, (3,3)],
                    "V4" => [bmvar, (4,4)],
                    "V5" => [bmvar, (5,5)],
                    "V6" => [bmvar, (6,6)],
                    "V7" => [bmvar, (7,7)],
                    "V8" => [bmvar, (8,8)],
                    "V9" => [bmvar, (9,9)],
                    "V10" => [bmvar, (10,10)],
                    "S1" => [szvar, (1,1)],
                    "S2" => [szvar, (2,2)],
                    "S3" => [szvar, (3,3)],
                    "S4" => [szvar, (4,4)],
                    "S5" => [szvar, (5,5)],
                    "S6" => [szvar, (6,6)],
                    "S7" => [szvar, (7,7)],
                    "S8" => [szvar, (8,8)],
                    "S9" => [szvar, (9,9)],
                    "S10" => [szvar, (10,10)] )
    testQuery()
    @time for ptf in ptfs
        eArrays = deepcopy(iniArrays)
        if length(ptf)==3
            f1 = deepcopy(filters[ptf[1]])
            f2 = deepcopy(filters[ptf[2]])
            f3 = deepcopy(filters[ptf[3]])
            raw[ptfnames[cc]] = @time queryDF(retvals, eArrays, f1, f2, f3)
        elseif length(ptf)==1
            f1 = deepcopy(filters[ptf[1]])
            raw[ptfnames[cc]] = @time queryDF(retvals, eArrays, f1)
        end
        cc+=1
    end
    return raw
end


end #module
