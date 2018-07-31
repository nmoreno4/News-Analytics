module MongoDB_queries
using Mongo

export getAnalyticsCursor, fieldDistinct

"""
# Description
Gets a cursor pointing at all stories containing the desired analytics
"""
function getAnalyticsCursor(mongoConnect, startdate, enddate, permID, returnvalues=())
  # Get all stocks from the quintile during time period
  cursor = find(mongoConnect,
                Mongo.query("firstCreated" => Dict("\$gte"=>startdate,
                                             "\$lt"=>enddate),
                            "takes.analytics.assetId"=>string(permID)),
                returnvalues)
  return cursor
end #fct getAnalyticsCursor




"""
# Description
Gets a cursor pointing at all stories containing the desired analytics
"""
function getStockCursor(mongoConnect, startdate, enddate, permID, returnvalues=())
  # Get all stocks from the quintile during time period
  cursor = find(mongoConnect,
                Mongo.query("firstCreated" => Dict("\$gte"=>startdate,
                                             "\$lt"=>enddate),
                            "takes.analytics.assetId"=>string(permID)),
                returnvalues)
  return cursor
end #fct getAnalyticsCursor


function fieldDistinct(mongoConnect, fields, key="", value="")
    uniquesets=[]
    for field in fields
      allElements = []
      if key=="" && value==""
        cursor = find(mongoConnect, query())
      else
        cursor = find(mongoConnect, Dict("\$query" => Dict(key => value)))
      end
      for entry in cursor
        push!(allElements, entry[field])
      end
      push!(uniquesets, Set(allElements))
    end #for nb of field you want the unique values
  return uniquesets
end


end #module
