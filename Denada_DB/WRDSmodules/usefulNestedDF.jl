module usefulNestedDF
using DataFrames, JLD2
export is_duplicate, flattenDF, desiredVarToArray, removeMissing!, df_to_PERMNO_Dict, countRemoved, stackDF


"""
"""
function removeMissing!(df, var, acceptedTypes = (Float64, Int64), filterExchange=true)
  # Careful only works for Float64 and Int64

  rowstodelete = Int64[]

  cc=0
  for row in eachrow(df)
    if (!ismissing(row[var]) && typeof(row[var])==String &&  typeof(parse(row[var]))==Float64)
      row[var] = parse(row[var])
    end
    cc+=1
    if !(typeof(row[var]) in acceptedTypes) || (filterExchange && (ismissing(row[:EXCHCD]) || !(row[:EXCHCD] in [1,2,3])))
      push!(rowstodelete, cc)
    end
  end
  deleterows!(df, rowstodelete)
  return (df, [length(rowstodelete), size(df,1)])
end


function countRemoved(rr)
  kept = 0
  removed = 0
  for r in rr
    kept+=r[2]
    removed+=r[1]
  end
  return (kept, removed, removed/kept)
end


"""
"""
function desiredVarToArray(resArray, dataRow, selVars)
  cc=0
  for el in Array(dataRow)
    cc+=1
    if names(dataRow)[cc] in selVars
      push!(resArray, el)
    end
  end
  return resArray
end


"""
"""
function df_to_PERMNO_Dict(data, permnosymbol=:PERMNO, dateSymbol=:CSDATE, rowprint=30000, path="/run/media/nicolas/Research/Data/temp/dfPERMNO.jld2", reload=false)
  if reload
    dfPERMNO = Dict()
    cc=0
    for row in eachrow(data)
      cc+=1
      try
        push!(dfPERMNO[row[permnosymbol]], Array(row))
      catch
        dfPERMNO[row[permnosymbol]] = DataFrame(Array(row))
        names!(dfPERMNO[row[permnosymbol]], names(data))
      end
      if cc % rowprint == 0
        print("\n$(round((100*cc)/size(data,1), 2))% \n")
      end
    end
    #sort by date
    for permno in dfPERMNO
      sort!(permno[2], cols = [dateSymbol])
    end
    @save path dfPERMNO
  else
    @load path dfPERMNO
  end
  return dfPERMNO
end


"""
"""
function is_duplicate(val, x)
  cc = 0
  for i in x
    if val == i
      cc+=1
    end
    if cc>1
      break
    end
  end
  dup = 0
  if cc>1
    dup = true
  else
    dup = false
  end
  return dup
end


"""
"""
function flattenDF(dicdf, cols, rowprint=50)
  coldic = Dict()
  for var in cols
    coldic[var] = dicdf[var]
  end
  return coldic
end


"""
This function flattenDFbis is currently outdated and needs to be reworked on.
"""
function flattenDFbis(dicdf, cols, rowprint=50)
  cc=0
  coldic = Dict()
  tic()
  for permno in dicdf
    cc+=1
    if cc<250000 #used to be ==1 if you want multiple permnos
      for var in cols
        coldic[var] = permno[2][var]
      end
    else
      for var in cols
        coldic[var] = vcat(coldic[var], permno[2][var])
      end
    end #if first permno I initialize df
    if cc>=length(dicdf)
      break
    end
    if cc%rowprint==0
      print("Advancement : $(round(100*cc/length(dicdf), 2))% \n")
      toc()
      tic()
      # break
    end
  end
  toc()
  return coldic
end


function stackDF(mergedDF, varstokeep, span=600, kstart=2)
  totempty = 0
  kend = kstart+span
  finalDF = flattenDF(mergedDF[collect(keys(mergedDF))[1]], varstokeep)
  for permnocount in 1:ceil(length(mergedDF)/span)
    # First DF in the span
    flatDF = flattenDF(mergedDF[collect(keys(mergedDF))[kstart]], varstokeep)
    print(kstart)
    # All following permnos in the span
    for permno in collect(keys(mergedDF))[kstart+1:kend]
      if size(mergedDF[permno],1)>0
        crtflatDF = flattenDF(mergedDF[permno], varstokeep)
        for var in varstokeep
          try
            flatDF[var] = vcat(flatDF[var], crtflatDF[var])
          catch
            print("$(flatDF) - permno \n")
          end
        end
      else
        totempty+=1
      end
    end
    kstart+=span+1
    p1 = kend+span+1
    kend=minimum([p1, length(mergedDF)])
    for var in varstokeep
      finalDF[var] = vcat(finalDF[var], flatDF[var])
    end
  end
  return finalDF
end


end #module
