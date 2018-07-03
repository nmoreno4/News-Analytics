module dataframeFunctions
using DataFrames, nanHandling

export df_to_array, removeonlyNaNrowsDF, createDateLabelDF

function df_to_array(df, rows=1:size(df,1), cols=1:size(df,2))
  a = Array{Float64}(df[rows,cols])
end #fun

"""
Remove rows of Dataframes where all elements are NaNs.\n
Typical use is to remove non-trading days.\n
Starts from second column onwards to ignore date.
colsToIgnore : indicate for which col one should not care if there is a NaN
               or not and the column should be inserted back to the final DF.
"""
function removeonlyNaNrowsDF!(df, colsToIgnore)
  colsKeep = []
  for i in 1:size(df,1)
    if !(i in colsToIgnore)
      push!(colsKeep, i)
    end
  end
  mat = df_to_array(df, 1:size(df,1), colsKeep)
  newDF, keptRows, discardedRows = removeonlyNaNrows(mat)
  return df[keptRows,:]
end #fun


function createDateLabelDF(myLabels::Array, customDates = [], startDate=Date(2003,1,1), endDate=Date(2017,12,31), filterWeekends=true, freq=Dates.Day(1))
  if length(customDates)==0
    # Create a list with all the desired dates
    chosenDates = startDate:freq:endDate
    if filterWeekends
      chosenDates = filter(dy -> Dates.dayname(dy) != "Saturday" && Dates.dayname(dy) != "Sunday" , chosenDates)
    end
  else
    chosenDates = customDates
  end #if customDates

  # Create empty NaNs DF
  NaNsMatrix = Array{Float64}(length(chosenDates), length(myLabels)+1)*NaN
  DateLabelDF = DataFrame(NaNsMatrix)

  #Set labels on DF
  names!(DateLabelDF, unshift!([Symbol(i) for i in myLabels], Symbol("Date")))

  DateLabelDF[:Date]=chosenDates

  return DateLabelDF
end #fun

end #module
