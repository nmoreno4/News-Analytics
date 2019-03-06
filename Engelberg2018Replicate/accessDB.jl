using Mongoc, Dates, DataFrames
dbName = "Jan2019"
collName = "PermnoDay"
client = Mongoc.Client()
database = client[dbName]
collection = database[collName]

function dateTo_ymonth(x)
    y = year(x)
    m = month(x)
    if m<10
        r = "$(y)0$(m)"
    else
        r = "$y$m"
    end
    return parse(Int, r)
end


function queryToArray(crtquery, collection, retvalues)
    res = []
    for doc in Mongoc.aggregate(collection, crtquery)
        doc = Mongoc.as_dict(doc)
        if length(setdiff(retvalues, keys(doc)))>0
            for crtKey in setdiff(retvalues, keys(doc))
                doc[crtKey] = missing
            end
        end
        push!(res, doc)
    end
    return res
end

function symbolKeys(dic)
    for (k,v) in dic
        delete!(dic, k)
        dic[Symbol(k)] = v
    end
    return dic
end

function retBson(retvalues)
    retString = "\"_id\": 0 "
    [", \"$(i)\" : 1 " for i in retvalues]
    for i in retvalues
        retString = "$(retString),  \"$(i)\" : 1 "
    end
    return retString
end

function bsonQuery(date1, date2, retvals)
    my_pipeline = Mongoc.BSON("""
        [
            { "\$match" : { "ymonth" :  { "\$gt" : $(date1) ,  "\$lte" : $(date2)  }  } },
            { "\$project" : { $retvals } }
        ]
    """)
    return my_pipeline
end

retvalues = ["date", "permno", "retadj", "volume", "me", "ranksize", "rankbm", "EAD", "prc",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100"]
retDic = Mongoc.BSON(Dict(zip(retvalues, [1 for i in retvalues])))
monthrange = Month(6)
y1 = Dates.DateTime(2002,12,31):monthrange:Dates.DateTime(2017,12,31)-monthrange
y2 = Dates.DateTime(2002,12,31)+monthrange:monthrange:Dates.DateTime(2017,12,31)
dateranges = [(dateTo_ymonth(y1), dateTo_ymonth(y2)) for (y1, y2) in zip(y1, y2)]
myqueries = [bsonQuery(date1, date2, retBson(retvalues)) for (date1, date2) in dateranges]

function firstQuery(myquery, collection, retvalues)
    x = 0
    while x==0
        res = @time queryToArray(myquery, collection, retvalues)
        resDF = @time vcat(DataFrame.(res)...)
        print(typeof(resDF[:date]))
        if typeof(resDF[:date])==Array{DateTime,1}
            x=1
            return resDF
            break
        end
    end
end


function subsequentQueriesToArray(myqueries, resDF, collection, retvalues)
    for crtquery in myqueries
        print("$crtquery \n =================================== \n")
        while 0==0
            x, failed = 0, 0
            tempDF = resDF[1:2,:]
            res = @time queryToArray(crtquery, collection, retvalues)
            @time for dic in res
                try
                    push!(tempDF, symbolKeys(dic))
                catch err
                    failed = 1
                    print(dic)
                    print(err)
                    print("----- FAILURE ---- \n\n $crtquery \n\n\n")
                    break
                end
            end
            if failed == 0
                deleterows!(tempDF, 1)
                resDF = vcat(resDF, tempDF)
                x=1
                break
            end
        end
    end
    return resDF
end

resDF = @time firstQuery(myqueries[1], collection, retvalues)

@time a = subsequentQueriesToArray(myqueries[2:end], resDF, collection, retvalues)



# res = []
# @time for crtquery in Mongoc.BSON.(myqueries)
#     print(crtquery)
#     @time for i in Mongoc.find(collection, crtquery)
#         rDic = Mongoc.as_dict(i)
#         for crtKey in setdiff(keys(rDic), retvalues)
#             delete!(rDic, crtKey)
#         end
#         if length(setdiff(retvalues, keys(rDic)))>0
#             for crtKey in setdiff(retvalues, keys(rDic))
#                 rDic[crtKey] = missing
#             end
#         end
#         push!(res, rDic)
#     end
#     break
# end
# print("Loop done! \n")
# @time vcat(DataFrame.(res)...)
#
#
# dfStart = 1000
#
# df = vcat(DataFrame.(res[1:dfStart])...)
# @time for dic in res[dfStart+1:end]
#     push!(df, symbolKeys(dic))
# end
