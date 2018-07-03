module functionsCRSP
using databaseQuerer, dataframeFunctions, nanHandling, TSfunctions

export idxWithDatabis, idxWithData, createreturnsmatrix, fillDateLabelDF, getMatch, sortedMapWithIdx, rebalancingDatesIdx

"""
createreturnsmatrix(quintile = ["H", "M", "L"], factor="BM")
# Description
Queries the database to filter all datapoints between 2003-01-01 and 2014-31-12\
that are in the quintile. It does so on a year-by-year basis.
"""
function createreturnsmatrix(CRSPconnect, factor, quintile, yStart=(2003,1,31), yEnd=(2016,12,31), tFrequence=Dates.Day(1), adjFreq=false)
  ## Get all unique PERMNOs in the CRSP database
  allPERMNOs = collect(fieldDistinct(CRSPconnect, ["PERMNO"])[1]) # use collect to transform the set to a list
  permnomap = sortedMapWithIdx(allPERMNOs) #sorted map to idx (for later usage)
  ## Create empty DF with all PERMNO labels and dates
  df = @time createDateLabelDF(allPERMNOs, [], Date(yStart[1],yStart[2],yStart[3]), Date(yEnd[1],yEnd[2],yEnd[3]), false, Dates.Day(1))
  print(size(df))
  datemap = sortedMapWithIdx(df[:Date])
  provMatrix = Array{Float64}(size(df,1), size(df,2)-1, 4)*NaN
  for crtyear in yStart[1]:yEnd[1]
    print(crtyear)
    if crtyear==yEnd[1]
      tDelta = Date(crtyear,yEnd[2],yEnd[3])-Date(crtyear-1,12,31)
      cursor = singleFactorCursor(CRSPconnect, factor, quintile, Date(crtyear,yEnd[2],yEnd[3]), tDelta)
    else
      cursor = singleFactorCursor(CRSPconnect, factor, quintile, Date(crtyear+1,yStart[2],yStart[3]), Dates.Year(1))
    end
    provMatrix = fillDateLabelMat(provMatrix, cursor, permnomap, datemap)
  end # for crtyear
  if adjFreq
    dfFreq = createDateLabelDF(allPERMNOs, [], Date(yStart[1],yStart[2],yStart[3]), Date(yEnd[1],yEnd[2],yEnd[3]), false, tFrequence)
    rightFreqMat = Array{Float64}(size(dfFreq,1), size(dfFreq,2)-1, 4)*NaN
    datesToKeep = []
    for d in dfFreq[:Date]
      push!(datesToKeep, find(x->x==d, df[:Date])[1])
    end #for date
    rightFreqMat = adjustFreq(rightFreqMat, provMatrix, datesToKeep)
  else
    rightFreqMat = provMatrix
    dfFreq = df
  end
  return rightFreqMat, names(dfFreq), dfFreq[:Date]
end #fun

"""
Does not take into consideration data in the period that came *before* the stcok entered the portfolio.
"""
function adjustFreq(rightFreqMat, provMatrix, datesToKeep)
  for col in 1:size(provMatrix, 2)
    periodArrayRet = []
    periodArrayWeight = []
    periodArrayPrice = []
    periodArrayVol = []
    dateIdx = 1
    for row in 1:size(provMatrix, 1)
      if dateIdx>length(datesToKeep)
        break
      end
      if row==datesToKeep[dateIdx]
        # print("\n$dateIdx - $row - $(size(provMatrix, 1))\n")
        rightFreqMat[dateIdx, col, 1] = cumRet(periodArrayRet)
        rightFreqMat[dateIdx, col, 2] = nanmean(periodArrayWeight)
        if length(periodArrayPrice)>0
          rightFreqMat[dateIdx, col, 3] = periodArrayPrice[end]
        else
          rightFreqMat[dateIdx, col, 3] = NaN
        end
        rightFreqMat[dateIdx, col, 4] = nansum(periodArrayVol)
        periodArrayRet = []
        periodArrayWeight = []
        periodArrayPrice = []
        periodArrayVol = []
        dateIdx += 1
      else
        push!(periodArrayRet, provMatrix[row,col,1])
        push!(periodArrayWeight, provMatrix[row,col,2])
        push!(periodArrayPrice, provMatrix[row,col,3])
        push!(periodArrayVol, provMatrix[row,col,4])
      end #if match date
    end #for row
  end #for col
  return rightFreqMat
end #fun



function cumRet(x)
  p=1
  for r in x
    if !isnan(r)
      p*=(1+r)
    end
  end
  return p-1
end #fun

function fillDateLabelMat(provMatrix, cursor, stockList, datesList, controlCheck = false)
  i=0
  for entry in cursor
    i+=1
    crtpermno=entry["PERMNO"]
    crtdate=entry["date"]
    # if crtdate <= maximum(Array{Date}(datesList[:,1])) # make sure that the date is in the matrix
    crtprice = entry["PRC"]
    crtret = entry["retadj"]
    crtweight = entry["weight_port"]
    crtvol = entry["VOL"]
    rowInd = getMatch(datesList, crtdate)
    colInd = getMatch(stockList, crtpermno)
    if typeof(crtret)==Float64
      provMatrix[rowInd, colInd, 1] = crtret
    end
    if typeof(crtprice)==Float64
      provMatrix[rowInd, colInd, 2] = abs(crtprice)
    end
    if typeof(crtweight)==Float64
      provMatrix[rowInd, colInd, 3] = crtweight
    end
    if typeof(crtvol)==Float64
      provMatrix[rowInd, colInd, 4] = crtvol
    end
    # end # if date in matrix
  end #for cursor
  if controlCheck
    print("Total matches $i")
  end
  return provMatrix
end #fun

"""
"""
function getMatch(idList, val)
  i=0
  idx = false
  for p in idList[:,1]
    i+=1
    if p == val
      idx = idList[i,2]
      break
    end
  end
  return idx
end #fun

"""
"""
function sortedMapWithIdx(listToOrder)
  sortedmap = []
  i = 0
  for a in listToOrder
    i+=1
    push!(sortedmap, i)
  end
  sortedmap = hcat(listToOrder, sortedmap)
  sortedmap = sortrows(sortedmap)
  return sortedmap
end #fun

function idxWithData(mat, rebalanceIdx)
  chosenIdx = []
  for var in 1:size(mat,3)
    colrows = []
    for col in 1:size(mat,2)
      chosenrows = []
      for row in 1:size(mat,1)
        if !(row in chosenrows)
          #if I have a value for that date on that stock
          if !(isnan(mat[row, col, var]))
            cc, first, last, el = 0, 0, 0, 0
            for el in rebalanceIdx
              cc+=1
              if el>row
                first, last = rebalanceIdx[cc-1], rebalanceIdx[cc]-1
                break
              end
            end
            for found in first:last
              # if found == 0
              #   print("$first $last $var $el $row $col $cc\n")
              # end
              push!(chosenrows, found)
            end
            #push!(chosenrows, row)
          end #if is not nan
        end #if not in banned rows
      end
      push!(colrows, chosenrows)
    end
    push!(chosenIdx, colrows)
  end
  return chosenIdx
end

function idxWithDatabis(mat, rebalanceIdx)
  chosenIdx = []
  for var in 1:size(mat,3)
    colrows = []
    for col in 1:size(mat,2)
      chosenrows = []
      for row in 1:size(mat,1)
        #if I have a value for that date on that stock
        if !(isnan(mat[row, col, var]))
          push!(chosenrows, row)
          #push!(chosenrows, row)
          end #if is not nan
      end
      push!(colrows, chosenrows)
    end
    push!(chosenIdx, colrows)
  end
  return chosenIdx
end

"""
Finds the indexes of dates corresponding to the first date of July of a year, i.e. when FF do their rebalancing
"""
function rebalancingDatesIdx(dates)
  lastYear = Dates.year(dates[1])-1
  foundIdx = [1]
  crtIdx = 0
  for d in dates
    crtIdx+=1
    if (Dates.year(d) > lastYear) && (Dates.month(d)>6)
      push!(foundIdx, crtIdx)
      lastYear = Dates.year(d)
    end
  end
  return push!(foundIdx, length(dates)+1)
end #fun


end #module
