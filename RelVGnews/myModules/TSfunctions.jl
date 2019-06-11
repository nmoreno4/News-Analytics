module TSfunctions
using nanHandling

export ret2tick, sameweek, freq_adj, monthlyDriftWeight, getOutOfSet,
  setNonPortfolioRetsToNaN!, averagePeriod, newPeriodsDatesIdx, concernedStocks

"""
# Description
Transforms a series of returns into a cumulated price series
# Arguments
- `series::Array`: The list of returns
- `base::Number`: The initial price
- `removeNaN::bool`: Ignores NaNs to reconstruct price series.false by default to avoid shorter series.
"""
function ret2tick(series, base=1, removeNaN=false)
  prices=Float64[base]
  if removeNaN
    for ret in series
      if !isnan.(ret)
        push!(prices, prices[end]*(1+ret))
      end #if
    end #for
    #
  else
    for ret in series
      push!(prices, prices[end]*(1+ret))
    end #for
  end #if
  return prices
end #fun


"""
sameweek(a:Date, b:Date)
# Description
Check if two dates fall on a same week.
Returns a **tuple**.
# Returns
1/ A bool for same week check\n
2/ Date **a** year-week string\n
3/ Date **b** year-week string
"""
function sameweek(a,b)
  A_id = "$(Dates.year(a))-$(Dates.week(a))"
  B_id = "$(Dates.year(b))-$(Dates.week(b))"
  return (Dates.week(a)==Dates.week(b) && Dates.year(a)==Dates.year(b), A_id, B_id)
end #fun

function freq_adj(rdf, wMat1=ones(size(rdf)), freq=Dates.day, rdf2=0, wMat2=ones(size(rdf)))
  retVec = Float64[]
  for row in 1:size(rdf,1)
    if freq==Dates.day
      if rdf2 == 0
        push!(retVec, nansum(rdf[row,:].*wMat1[row,:]))
      else
        push!(retVec, mean([nansum(rdf[row,:].*wMat1[row,:]),
                            nansum(rdf2[row,:].*wMat2[row,:])]))
      end #if rdf2
    end #if freq
  end #for row
  return retVec
end #fun

"""
monthlyDriftWeight(WwMat, WS)
# Description
Only for monthly data. For daily data it gets much more complex.
Outputs a new weighting matrix where weights drift correctly for both EW and VW.
# Arguments
- `wMat::Array{Float64}`: Matrix af monthly ME
- `WS::String`: Weighting scheme. Either **VW** or **EW**
"""
function monthlyDriftWeight(wMat, WS="VW")
  #Obsolete comment : doublesort default 2 or 1 for simple H - L instead of HH+HL - LH+LL
  driftedWeights = Array{Float64}(size(wMat))*NaN
  for row in 1:size(wMat, 1)
    if WS == "VW"
      driftedWeights[row,:] = wMat[row,:]./nansum(wMat[row,:])
    elseif WS == "EW"
      # First parenthese gives a 1 to all stocks currently in portfolio and NaN otherwise
      driftedWeights[row,:] = (wMat[row,:]./wMat[row,:])*(nonnancount(wMat[row,:])/nansum(wMat[row,:]))
    end # if WS
  end #for
  return driftedWeights
end #fun

function getOutOfSet(x,y)
  reslist = []
  for i in y
    if !(i in x)
      push!(reslist, i)
    end
  end
  return reslist
end #fun


function setNonPortfolioRetsToNaN!(mat, portfolioIdxs)
  col=0
  for rows in portfolioIdxs
    col+=1
    toRemove = getOutOfSet(rows, 1:size(mat, 1))
    mat[toRemove, col] = NaN
  end
  return mat
end #fun


#tPeriod indicates the minimum span before we find a new period
function newPeriodsDatesIdx(dates, tPeriod)
  crtdate = dates[1]
  crtidx = 1
  tWindow = tPeriod
  newDates = []
  idxCount = 0
  for d in dates
    idxCount+=1
    if (d-crtdate) > tWindow || d==dates[end]
      push!(newDates, [crtdate, d, (crtidx:idxCount)])
      crtdate = d
      crtidx = idxCount
    end
  end
  return newDates
end



function concernedStocks(row, selIdx, rowsToPeriod=1, colOnly=true)
  stockIdx = []
  for crtrow in (row-rowsToPeriod):row
    cc = 0
    for i in selIdx
      cc+=1
      if crtrow in i
        if colOnly
          push!(stockIdx, cc)
        else
          push!(stockIdx, (crtrow,cc))
        end
      end
    end
  end
  return stockIdx
end #fun


function averagePeriod(finalWmat, alldesiredCols, mat, typeW="VW")
  resultVec = Float64[]
  for row in 1:length(alldesiredCols)
    if typeW =="VW"
      push!(resultVec, nansum(finalWmat[row, alldesiredCols[row]].*mat[row, alldesiredCols[row]]))
    elseif typeW == "EW"
      push!(resultVec, nanmean(mat[row, alldesiredCols[row]]))
    end
  end
  return resultVec
end

end #module
