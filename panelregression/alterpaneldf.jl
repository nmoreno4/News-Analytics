module alterpaneldf

using CSV, Missings, TimeSeries
export lagvariables

"Computes lag both of past values (-t) or future values (+t)"
function lagvariables(subdf)
    nblags = []
    nbaggs = []
    for row in CSV.eachrow(subdf)
        for col in row
            if String(col[1])[1:2]=="la"
                push!(nblags, (col[2], replace(replace(String(col[1]), "-", "")[5:end], "0", "")))
            end
            if String(col[1])[1:2]=="ag"
                push!(nbaggs, (col[2], replace(replace(String(col[1]), "-", "")[5:end], "0", "")))
            end
        end
        break
    end
    for vlag in nblags
        try
          if abs(vlag[1])>10 && vlag[1]%10!=0
              error("lag must be 1-10 or multiple of 10")
          end
        catch
          print(vlag)
        end
        lag = Int(vlag[1])
        var = vlag[2]
        if lag<0
            lagvec = subdf[Symbol("$(var)")][1:end+lag]
            lagvec = vcat(Missings.missings(Float64, abs(lag)), lagvec)
        else
            lagvec = subdf[Symbol("$(var)")][1+lag:end]
            lagvec = vcat(lagvec, Missings.missings(Float64, lag))
        end
        subdf[Symbol("lag$(lag)$(var)")] = lagvec
    end
    for vagg in nbaggs
        if abs(vagg[1])>10 && vagg[1]%10!=0
            error("lag must be 1-10 or multiple of 10")
        end
        nbdays = Int(vagg[1])
        var = vagg[2]
        lastreturns = []
        lastsents = []
        lastEAD = []
        for row in CSV.eachrow(subdf)
          if length(lastreturns)==nbdays
            lastreturns = shiftpush(lastreturns, row[:retadj])
            lastsents = shiftpush(lastsents, row[:sent])
            lastEAD = shiftpush(lastEAD, row[:EAD])
            row[Symbol("agg$(nbdays)retadj")] = cumret(lastreturns)
            row[Symbol("agg$(nbdays)sent")] = meanexclude(lastsents)
            row[Symbol("agg$(nbdays)EAD")] = sum(lastEAD)
          else
            push!(lastreturns, row[:retadj])
            push!(lastsents, row[:sent])
            push!(lastEAD, row[:EAD])
            if length(lastreturns)==nbdays
              row[Symbol("agg$(nbdays)retadj")] = cumret(lastreturns)
              row[Symbol("agg$(nbdays)sent")] = meanexclude(lastsents)
              row[Symbol("agg$(nbdays)EAD")] = sum(lastEAD)
            else
              row[Symbol("agg$(nbdays)retadj")] = missing
              row[Symbol("agg$(nbdays)sent")] = missing
              row[Symbol("agg$(nbdays)EAD")] = missing
            end
          end
        end
    end
    return subdf
end #fun


function timecompress(subdf)
    TS = TimeArray(subdf[:date], Array{Float64}(subdf[:, 2:end]), [String(x) for x in names(subdf)][2:end])
    
end


function shiftpush(X,x)
  shift!(X)
  push!(X, x)
  return X
end

function cumret(X)
  start = 1
  for x in X
    start*=(1+x)
  end
  res = start - 1
  return res
end

function meanexclude(X, toexclude = 0)
  res = Float64[]
  for x in X
    if x!= toexclude
      push!(res, x)
    end
  end
  if length(res)==0
    push!(res,0)
  end
  return mean(res)
end


end # module
