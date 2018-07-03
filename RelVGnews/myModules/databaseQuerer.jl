module databaseQuerer
using Mongo

export fieldDistinct, singleFactorCursor, getAnalyticsCursor, getAnalyticsCursorAny


"""
"""
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

"""
# Description
Gets a cursor pointing at all stocks
"""
function singleFactorCursor(mongoConnect, factor, value, split_date=Date(2018,12,31),
                                timespan=Dates.Year(20), returnvalues=Dict())
  # Get all stocks from the quintile during time period
  if typeof(value)==Array{String,1} || typeof(value)==Array{Float64,1}
    cursor = find(mongoConnect,
                  Dict("date"=>Dict("\$gte"=>split_date-timespan,
                                    "\$lt"=>split_date),
                       factor=>Dict("\$in" => value)),
                  returnvalues)
  else
    cursor = find(mongoConnect,
                  Dict("date"=>Dict("\$gte"=>split_date-timespan,
                                    "\$lt"=>split_date),
                       factor=>value),
                  returnvalues)
  end

  return cursor
end


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
end

function getAnalyticsCursorAny(mongoConnect, startdate, enddate, returnvalues=())
  # Get all stocks from the quintile during time period
  cursor = find(mongoConnect,
                Mongo.query("firstCreated" => Dict("\$gte"=>startdate,
                                             "\$lt"=>enddate)),
                returnvalues)
  return cursor
end

end #module
