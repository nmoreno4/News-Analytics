module Portfolio_Sorting
using DataFrames, Missings
export assignPortfolio, computeBreakpoints


"""
"""
function assignPortfolio(df, breakpoints, vars, kdates, typesort = "5x5", dateSymbol=:CRSPDATE, counter=0, output=String, monthRebal=6)
  firstyear = Dates.year(minimum(kdates))
  lastyear = Dates.year(maximum(kdates))
  if lastyear-firstyear != length(breakpoints[1])
    print("There is a problem with length of Dates")
    return "There is a problem with length of Dates"
  end
  typesort = Symbol("$(typesort)_$(vars[1])_$(vars[2])")
  df[typesort] = missing
  df[typesort] = Array{Union{String, Missing, Float64}}(df[typesort])
  idx=0
  for row in eachrow(df)
    # Get the index of the row in the current's stocks dataframe for the
    if Dates.month(row[dateSymbol])>monthRebal
      idx = Dates.year(row[dateSymbol])-firstyear
    else
      idx = Dates.year(row[dateSymbol])-(firstyear+1)
    end
    if idx==0 #|| (Dates.year(row[dateSymbol])>=firstyear && Dates.month(row[dateSymbol])>monthRebal) || idx>length(breakpoints[1])
      counter+=1
      # print("$(row[:PERMNO]) - $(row[:CRSPDATE])\n")
    elseif idx>length(breakpoints[1]) || idx <0
      print(row[dateSymbol])
    else
      t = []
      vcc = 0
      for var in vars
        vcc+=1
        # If the value of the variable exceeds the biggest quantile it gets assigned to the biggest portfolio
        if row[var]>breakpoints[vcc][idx][end]
          push!(t, length(breakpoints[vcc][idx])+1)
        else
          cc=0
          for q in breakpoints[vcc][idx]
            cc+=1
            if row[vars[vcc]]<=q
              push!(t, cc)
              break
            end
          end
        end
      end
      if output==String
        stringClas = "$(t[1])"
        for clasif in t[2:end]
          stringClas = "$(stringClas).$(clasif)"
        end
        row[typesort] = stringClas
      elseif output==Float64
        stringClas = "$(t[1])"
        for clasif in t[2:end]
          stringClas = "$(stringClas).$(clasif)"
        end
        if length(t)<3
          try
            row[typesort] = parse(stringClas)
          catch
            # print("$stringClas \n")
          end
        else
          print("Sorting along too many dimensions, classification will be saved as a String")
          row[typesort] = stringClas
        end
      end
    end
  end
  return (df, counter)
end


"""
"""
function computeBreakpoints(mergedDF, vars, percentilesBreakpoints=([0.2 0.4 0.6 0.8]), verbose=false, ystart=1973, yend=2017)
  allyears = []
  res = []
  #Create empty space for the different variables
  nbSortingVars = length(vars)
  for y in ystart:yend
    res = []
    for i in 1:nbSortingVars
      push!(res,[])
    end
    for permno in mergedDF
      res = appendVariables(res, permno[2], y, vars, :YEAR)
    end
    push!(allyears, res)
    if verbose
      print(y)
    end
  end

  breakpoints = []
  for i in 1:nbSortingVars
    push!(breakpoints,[])
  end
  for y in allyears
    if verbose
      print(y)
    end
    cc=0
    for vvar in vars
      cc+=1
      vec = Float64[]
      for i in y[cc]
        if !ismissing(i)
          push!(vec, i)
        end
      end
      push!(breakpoints[cc], quantile(vec, percentilesBreakpoints[cc]))
    end
  end

  return breakpoints
end #fun


"""
"""
function appendVariables(res, df, crtdate, vars, dateSymbol=:CRSPDATE)
  for row in eachrow(df)
    if row[dateSymbol]==crtdate && row[:MONTH]==6
      cc=0
      for crtVarVec in res
        cc+=1
        push!(crtVarVec, row[vars[cc]])
      end
    elseif row[dateSymbol]>crtdate
      break
    end
  end
  return res
end


end #module
