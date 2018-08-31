module otherCleaning
using DataFrames, Missings
export permcoDateClean, permcoMerge, removeearlyDates, ageCompustat


"""
"""
function permcoDateClean(CRSP_data, dateSymbol)
  tic()
  permcoDateMap = Dict()
  for row in eachrow(CRSP_data)
    try
      push!(permcoDateMap[row[:permco]], row[dateSymbol])
    catch
      permcoDateMap[row[:permco]] = []
      push!(permcoDateMap[row[:permco]], row[dateSymbol])
    end
  end
  toc()
  tic()
  duplicateDates = Dict()
  for stock in permcoDateMap
    for el in stock[2]
      if is_duplicate(el, stock[2])
        try
          push!(duplicateDates[stock[1]], el)
        catch
          duplicateDates[stock[1]] = []
          push!(duplicateDates[stock[1]], el)
        end
      end
    end
  end
  toc()
  CRSP_data[:cleanpermco] = NaN
  cc=0
  for row in eachrow(CRSP_data)
    cc+=1
    row[:cleanpermco] = cc
  end
  toadd = Dict()
  toremove = Dict()
  cc = 0
  for permco in duplicateDates
    cc+=1
    permdf = CRSP_data[(CRSP_data[:permco].==permco[1]),:]
    for d in Set(permco[2])
      df = permdf[(permdf[dateSymbol].==d),:]
      maxidx = findmax(df[:me])[2]
      toadd[(df[:permno][maxidx], df[dateSymbol][maxidx])] = (df[:cleanpermco][maxidx], sum(df[:me]))
      # add the same but for the lines that will have to be removed
      for r in 1:size(df, 1)
        if r != maxidx
          toremove[(df[:permno][r], df[dateSymbol][r])] = df[:cleanpermco][r]
        end
      end
    end
    print("\n$(round((100*cc)/length(duplicateDates), 2))% \n")
  end
  return (toadd, toremove, permcoDateMap)
end

function permcoMerge(CRSPdf, toadd, toremove)
  linestoadd = Int[]
  valtoadd = []
  for i in toadd
    push!(linestoadd, i[2][1])
    push!(valtoadd, i[2][2])
  end
  linestoremove = Int[]
  for i in toremove
    push!(linestoremove, i[2][1])
  end
  sort!(linestoremove)
  cc=0
  valcc = 1
  for row in eachrow(CRSPdf)
    cc+=1
    if cc in linestoadd
      row[:me] = valtoadd[valcc]
      valcc+=1
    end
  end
  deleterows!(CRSPdf, linestoremove)
  return CRSPdf
end


"""
"""
function ageCompustat(df, minHistLength=2, dateSymbol=:CSDATE, rowdeletion = false)
  firstObs = minimum(df[dateSymbol])
  df[:AGE_Compustat] = missing
  df[:AGE_Compustat] = Array{Union{Date, Missing, Float64}}(df[:AGE_Compustat])
  cc = 0
  rowstodelete = Int[]
  for row in eachrow(df)
    cc+=1
    row[:AGE_Compustat] = Dates.days(row[dateSymbol]-firstObs)/365
    if row[:AGE_Compustat]<minHistLength
      push!(rowstodelete, cc)
    end
  end
  if rowdeletion
    deleterows!(df, rowstodelete)
  end
  return df
end


"""
"""
function removeearlyDates(df, datelimit, dateSymbol)
  rowstodelete = Int64[]
  cc=0
  for row in eachrow(df)
    cc+=1
    if row[dateSymbol]<datelimit
      push!(rowstodelete, cc)
    end
  end
  deleterows!(df, rowstodelete)
  return (df, [length(rowstodelete), size(df,1)])
end

end #module
