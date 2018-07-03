module customWRDSvariables
using DataFrames, Missings, CSV, RCall
@rlibrary stlplus
begin
  export
    computeBE, Scaling, profitability, month_year, ME_retadj,
    computePE, computeDE, computeROE, ME_June_Dec, lagvariable,
    dlretOnLine, CRSP_CS_merge, weight_port, loadWRDSdata, rfDate,
    meanPerPeriod, demean_standardize, detrend, filterExtremeValues,
    deseasonalize
end

"""
"""
function detrend(df, myvar, target_np=36)
  a = df[myvar]
  df[Symbol("$(myvar)_stl")] = a
  try sum(Missings.skipmissing(a*0+1))
    if length(a)-sum(Missings.skipmissing(a*0+1))>12
      print(length(a))
      @rput a
      R"np = min(c($(target_np), (length(a) - sum(is.na(a)))/4))"
      R"print(np)"
      R"b = stlplus::stlplus(a, n.p = np, s.window = 'periodic')"
      R"remainder = stlplus::remainder(b)"
      @rget remainder
      df[Symbol("$(myvar)_stl")] = remainder
    end
  end
  return df
end

function deseasonalize(df, myvar, target_np=36)
  a = df[myvar]
  df[Symbol("$(myvar)_stl")] = a
  try sum(Missings.skipmissing(a*0+1))
    if length(a)-sum(Missings.skipmissing(a*0+1))>12
      print(length(a))
      @rput a
      R"np = min(c($(target_np), (length(a) - sum(is.na(a)))/4))"
      R"print(np)"
      R"b = stlplus::stlplus(a, n.p = np, s.window = 'periodic')"
      R"remainder = stlplus::raw(b)-stlplus::seasonal(b)"
      @rget remainder
      df[Symbol("$(myvar)_stl")] = remainder
    end
  end
  return df
end


"""
"""
function demean_standardize(df, myvar, meanVar, stdVar, dateSymbol=:CRSPDATE)
    df[Symbol("$(myvar)_demeaned")] = missing
    df[Symbol("$(myvar)_demeaned")] = Array{Union{Float64, Missing}}(df[Symbol("$(myvar)_demeaned")])
    df[Symbol("$(myvar)_standardized")] = missing
    df[Symbol("$(myvar)_standardized")] = Array{Union{Float64, Missing}}(df[Symbol("$(myvar)_standardized")])
    for row in eachrow(df)
        crtmean = meanVar[row[dateSymbol]]
        crtstd = stdVar[row[dateSymbol]]
        row[Symbol("$(myvar)_demeaned")] = row[myvar] - crtmean
        row[Symbol("$(myvar)_standardized")] = (row[myvar] - crtmean)/crtstd
    end
    return df
end


"""
"""
function meanPerPeriod(mergedDF, myvar, dateSymbol=:CRSPDATE)
  ROEdict = Dict()
  cc=0
  for permno in mergedDF
      cc+=1
      for row in eachrow(permno[2])
          try
              push!(ROEdict[row[dateSymbol]], row[myvar])
          catch
              print(row[dateSymbol])
              ROEdict[row[dateSymbol]] = []
              push!(ROEdict[row[dateSymbol]], row[myvar])
          end
      end
  end
  meandic = Dict()
  stddic = Dict()
  for el in ROEdict
      meandic[el[1]] = mean(Missings.skip(el[2]))
      stddic[el[1]] = std(Missings.skip(el[2]))
  end
  return (meandic, stddic)
end



"""
"""
function loadWRDSdata(datapath, dateSymbol)
  data = @time readtable(datapath)
  dates = String[]
  for d in data[dateSymbol[1]]
    push!(dates, string(d))
  end
  colnames = names(data)
  data[dateSymbol[2]] = DateTime(dates,"yyyymmdd")
  data = data[vcat(dateSymbol[2], colnames)]
  return data
end


"""
To define
"""
function lagvariable(df, var)
  for row in eachrow(df)

  end
end


"""
"""
function rfDate(csvpath, kdates)
  riskfree = CSV.read(csvpath)
  rowstodelete = Int[]
  cc=0
  for row in eachrow(riskfree)
    cc+=1
    if !(Dates.DateTime(row[:date]) in kdates)
      push!(rowstodelete, cc)
    end
  end
  deleterows!(riskfree, rowstodelete)
  riskfree[:date] = Array{Union{DateTime, Missing}}(riskfree[:date])
  return riskfree
end


"""
"""
function ME_retadj(df)
  totdeleted = 0
  df[:retadj] = missing
  df[:ME] = missing
  df[:retadj] = Array{Union{Float64, Missing}}(df[:retadj])
  df[:ME] = Array{Union{Float64, Missing}}(df[:ME])
  for row in eachrow(df)
    # print("$(row[:RET]) - $(row[:dlret]) \n")
    if !ismissing(row[:RET]) && typeof(parse(row[:RET]))==Float64
      row[:retadj] = (1+parse(row[:RET]))*(1+row[:dlret])-1
    else
      row[:retadj] = missing
    end
    if !ismissing(row[:PRC]) && !ismissing(row[:SHROUT])
      row[:ME] = abs(row[:PRC])*row[:SHROUT]
    else
      row[:ME] = missing
    end
  end
  return df
end


"""
Adjust for q and y
"""
function computeBE(df)
  CEQ_ = df[:ceqq]+df[:PSq]
  BKV = df[:atq] - df[:ltq]
  SHE = Missings.coalesce.(df[:seqq], CEQ_, BKV)
  df[:BEq] = SHE + df[:txditcq] - df[:PSq]
  df[:BEq] = Array{Union{Float64, Missing}}(df[:BEq])
  for row in eachrow(df)
    if !(ismissing(row[:BEq]) || row[:BEq]>0)
      row[:BEq]=missing
    end
  end
  df[:BEMEq] = (1000*df[:BEq])./df[:ME_dec]
  # In the paper they apply a log transformations
  df[:BM_GGq] = ((1000*0.9*df[:BEq])+0.1*df[:ME_dec])./df[:ME_dec]
  return df
end


"""
Delisting returns are indicated on separated lines.
Put the delisting return on the row of the date of occurence and delete
redundant lines.
"""
function dlretOnLine(CRSP_data)
  CRSP_data[:dlret] = NaN
  lag = CRSP_data[1,:]
  cc = 0
  rowstodelete = Int[]
  for row in eachrow(CRSP_data)
    cc+=1
    if ismissing(row[:DLRET])
      row[:dlret] = 0
    else
      if typeof(parse(row[:DLRET])) == Float64
        lag[:dlret] = parse(row[:DLRET])
      else
        lag[:dlret] = 0
      end
      push!(rowstodelete, cc)
    end
    lag = row
  end
  deleterows!(CRSP_data, rowstodelete)

  return CRSP_data
end #fun


"""
"""
function Scaling(df, vtype, myvar, myvar2, rfdf=0)
  df[Symbol("Scaled$(myvar)")] = NaN
  for row in eachrow(df)
    if vtype == "rf"
      crtrf = rfdf[rfdf[:date] .== row[:CRSPDATE], :][:value][1]/100
      row[Symbol("Scaled$(myvar)")] = 0.9*row[myvar]+0.1*crtrf
    elseif  vtype=="BM"
      row[Symbol("Scaled$(myvar)")] = log((0.9*row[myvar]+0.1*row[myvar2])/row[myvar2])
    elseif vtype == "ROE"
      row[Symbol("Scaled$(myvar)")] = 0.9*row[myvar]+0.1*row[myvar2]
    end
  end
  return df
end

"""
"""
function filterExtremeValues(df, myvar, lowVal, highVal)
  cc=0
  toremove = Int64[]
  for row in eachrow(df)
    cc+=1
    if row[myvar]>highVal || row[myvar]<lowVal
      push!(toremove, cc)
    end
  end
  deleterows!(df, toremove)
  return (df, [length(toremove), size(df,1)])
end


"""
"""
function profitability(df, dateSymbol)
  # profitability Novy-Marx
  df[Symbol("grossProfit$freq")] = row[Symbol("revt$freq")] -(Missings.coalesce.(df[Symbol("cogs$freq")],0))/df[Symbol("at$freq")]
  # profitability FF
  df[Symbol("operatingProfit$freq")] = df[Symbol("revt$freq")] -(Missings.coalesce.(df[Symbol("cogs$freq")],0)+Missings.coalesce.(df[Symbol("xint$freq")],0)+Missings.coalesce.(df[Symbol("xsga$freq")],0))/df[Symbol("BE$freq")]
  return df
end


"""
"""
function computeDE(df, freq="q")
  # de_ratioq=%mean_year(ltq)/%mean_year(sum(ceqq,pstkq)); /*debt to equity ratio*/
  df[Symbol("ceqqpstk$freq")] = df[Symbol("ceq$freq")]+df[Symbol("PS$freq")]
  lagslt, lagsceqqpstk = Array{Any}(zeros(3*4)), Array{Any}(zeros(3*4))
  cc=0
  df[Symbol("de$freq")] = missing
  df[Symbol("de$freq")] = Array{Union{Float64, Missing}}(df[Symbol("de$freq")])
  mcount, nmcount = 0, 0
  for row in eachrow(df)
    cc+=1
    shift!(lagslt)
    push!(lagslt, row[Symbol("lt$freq")])
    shift!(lagsceqqpstk)
    push!(lagsceqqpstk, row[Symbol("ceqqpstk$freq")])
    if cc>(3*4-1)
      try
        row[Symbol("de$freq")] = mean(skipmissing(lagslt))/mean(skipmissing(lagsceqqpstk))
      catch
        row[Symbol("de$freq")] = missing
      end
      if ismissing(row[Symbol("de$freq")])
        mcount+=1
      else
        nmcount+=1
      end
    end
  end
  return df
end


"""
"""
function month_year(df, dateSymbol=:CRSPDATE)
  df[:MONTH] = 0
  df[:YEAR] = 0
  for row in eachrow(df)
    row[:MONTH] = Dates.month(row[dateSymbol])
    row[:YEAR] = Dates.year(row[dateSymbol])
  end
  return df
end


"""
Adjust for q and y
"""
function computePE(df)
   # CAPEIq=%ttm(IBq);
   # /*Calculate moving average income before EI over previous 20 quarters (5 years)*/
   # convert CAPEIq=CAPEIq/ transformout=(MOVAVE 20 trimleft 12);
   # capei=(mktcap/capei); /*Shiller's CAPE*/
   df[:CAPEIq] = missing
   df[:CAPEIq] = Array{Union{Float64, Missing}}(df[:CAPEIq])
   lagibq = Array{Any}(zeros(3*4))
   mcount, nmcount = 0, 0
   cc=0
   for row in eachrow(df)
     cc+=1
     shift!(lagibq)
     push!(lagibq, row[:ibq])
     if cc>(3*4-1)
       try
         row[:CAPEIq] = sum(skipmissing(lagibq))
       catch
         row[:CAPEIq] = missing
       end
       if ismissing(row[:CAPEIq])
         mcount+=1
       else
         nmcount+=1
       end
     end
   end
   df[:CAPEIq5y] = missing
   df[:CAPEIq5y] = Array{Union{Float64, Missing}}(df[:CAPEIq5y])
   lagcapei = Array{Any}(zeros(5*12))
   cc=0
   for row in eachrow(df)
     cc+=1
     shift!(lagcapei)
     push!(lagcapei, row[:CAPEIq])
     if cc>(5*12-1)
       try
         row[:CAPEIq5y] = mean(skipmissing(lagcapei))
       catch
         row[:CAPEIq5y] = missing
       end
     end
   end
   return df
end


"""
Adjust for q and y
"""
function computeROE(df, perfreq = 4)
  # if ((be+lag(be))/2)>0 then roe=ib/((be+lag(be))/2)
  # if lagbe4>=0 then roeq=%ttm(ibq)/lagbe4
  # if first.gvkey or first.fyr then do; lagbe4=be4
  # be4=%mean_year(beq)
  df[:ROEq] = missing
  df[:ROEq] = Array{Union{Float64, Missing}}(df[:ROEq])
  df[:ROEqAdjusted] = missing
  df[:ROEqAdjusted] = Array{Union{Float64, Missing}}(df[:ROEqAdjusted])
  lagibq = Array{Any}(zeros(3*perfreq))
  lagbe4 = Array{Any}(zeros(3*perfreq))
  lagme4 = Array{Any}(zeros(3*perfreq))
  mcount, nmcount = 0, 0
  cc=0
  for row in eachrow(df)
    cc+=1
    shift!(lagibq)
    push!(lagibq, row[:ibq])
    shift!(lagbe4)
    push!(lagbe4, row[:BEq])
    shift!(lagme4)
    push!(lagme4, row[:ME])
    if cc>(3*perfreq-1)
      try
        row[:ROEq] = sum(skipmissing(lagibq))/lagbe4[1]
        row[:ROEqAdjusted] = sum(skipmissing(lagibq))/lagbe4[1]
      catch
        row[:ROEq] = missing
        row[:ROEqAdjusted] = missing
      end
      if ismissing(row[:ROEq])
        mcount+=1
      else
        nmcount+=1
      end
    end
  end
  return df
end


function ME_June_Dec(df, dateSymbol)
  df[:ME_june], df[:ME_dec] = missing, missing
  df[:ME_june] = Array{Union{Float64, Missing}}(df[:ME_june])
  df[:ME_dec] = Array{Union{Float64, Missing}}(df[:ME_dec])
  prev_ME_June, prev_ME_Dec, cold_prev_ME_Dec = missing, missing, missing
  for row in eachrow(df)
    if Dates.month(row[dateSymbol]) == 6
      prev_ME_June = row[:ME]
      prev_ME_Dec = cold_prev_ME_Dec
    end
    if Dates.month(row[dateSymbol]) == 12
      cold_prev_ME_Dec = row[:ME]
    end
    row[:ME_june] = prev_ME_June
    row[:ME_dec] = prev_ME_Dec
  end
  return df
end


"""
"""
function CRSP_CS_merge(CSdfPERMNO, CRSPdfPERMNO, CSvars, CRSPvars, finalOrder, rowprint=200, freq=Dates.Month(3))
  finalDF = Dict()
  ctot = 0
  CScount = 0
  emptydf = 0
  boundserrorcount = 0
  crtPERMNO = 0
  c = 0
  d = 0
  noCRSPdata = 0
  for permno in CSdfPERMNO
    ctot+=1
    CScount = 1
    CSdf = permno[2]
    print(size(CSdf))
    crtPERMNO = CSdf[:LPERMNO][1]
    try
      CRSPdfPERMNO[crtPERMNO]
      emptydf = 1
    catch
      noCRSPdata+=1
      emptydf = 0
      print("no CRSPdata : $crtPERMNO \n")
    end

    CRSPcount = 0
    if emptydf==1 #Make sure I have data from CRSP
      CRSPdf = CRSPdfPERMNO[crtPERMNO]
      for CRSProw in eachrow(CRSPdf)
        CRSPcount+=1

        #find out last date of period
        if CScount<size(CSdf, 1)
          maxdate = CSdf[:CSDATE][CScount+1]
        else
          # Make beginning/end of dates CRSP/CS match properly
          try
            maxdate = CSdf[:CSDATE][CScount]+freq
          catch excep
            if isa(excep, BoundsError)
              #I have more CS observations than CRSP
              boundserrorcount+=1
              break
            end
          end
        end # if (for maxdate)

        if CRSProw[:CRSPDATE]>maxdate
          # print("too far out $CScount")
          # I'm already too far in the dates and they will only keep getting older anyways
          CScount+=1
          if CScount<size(CSdf, 1)
            maxdate = CSdf[:CSDATE][CScount+1]
          else
            # Make beginning/end of dates CRSP/CS match properly
            try
              maxdate = CSdf[:CSDATE][CScount]+freq
            catch excep
              if isa(excep, BoundsError)
                #I have more CS observations than CRSP
                boundserrorcount+=1
                break
              end
            end
          end # if (for maxdate)
        end

        # print("$(CSdf[:DATE][CScount]) - $(CSdf[:DATE][CScount]) - $(CRSProw[:DATE]) \n \n")
        try
          if CRSProw[:CRSPDATE] in CSdf[:CSDATE][CScount]:maxdate && CSdf[:consol][CScount]=="C" && CSdf[:indfmt][CScount]=="INDL" && CSdf[:popsrc][CScount]=="D" && CSdf[:datafmt][CScount]=="STD" && datebeg<=CRSProw[:CRSPDATE]<dateend && isless(0,CSdf[:atq][CScount])
            #+ other filter conditions linkprim etc?

            crtrow = []
            crtrow = desiredVarToArray(crtrow, CRSProw, CRSPvars)
            crtrow = desiredVarToArray(crtrow, CSdf[CScount, :], CSvars)

            try
              push!(finalDF[permno[1]],crtrow)
              c+=1
            catch excep
              if isa(excep, KeyError)
                finalDF[crtPERMNO] = DataFrame(crtrow)
                names!(finalDF[crtPERMNO], vcat(CRSPvars,CSvars), makeunique=true)
                for col in vcat(CSvars, CRSPvars)
                  if !ismissing(finalDF[crtPERMNO][col][1])
                    finalDF[crtPERMNO][col] = Array{Union{typeof(finalDF[crtPERMNO][col][1]), Missing}}(finalDF[crtPERMNO][col])
                  else
                    finalDF[crtPERMNO][col] = Array{Union{Any, Missing}}(finalDF[crtPERMNO][col])
                  end
                  finalDF[crtPERMNO][:txditcq] = Array{Union{Any, Missing}}(finalDF[crtPERMNO][:txditcq])
                  finalDF[crtPERMNO][:PSq] = Array{Union{Any, Missing}}(finalDF[crtPERMNO][:PSq])
                end
                d+=1
              elseif isa(excep, ArgumentError)
                #Change dataframe column types
                print("expected error : $excep")
              end
              print("CScount: $CScount \n CRSPcount: $CRSPcount \n")
              print(excep)
            end

          end
        catch excep
          print(excep)
        end

      end # the CRSP rows to compare to current CS year row
      try
        finalDF[crtPERMNO] = finalDF[crtPERMNO][finalOrder]
      catch except
        if isa(except, KeyError)
          print("$(permno[1]) has no CRSP data for the CS date(s)")
        end
      end
    end #if I have CRSP data
    if ctot%rowprint==0
      print("Advancement : $(round(100*ctot/length(CSdfPERMNO), 2))% -- boundserrorcount : $boundserrorcount \n")
      # break
    end
  end
  print("noCRSPdata : $noCRSPdata")
  return finalDF
end


"""
"""
function weight_port(df)
  pastLME, pastCumretx, pastWeight_port, pastMe_base, pastME =  NaN, NaN, NaN, NaN, NaN
  df[:LME], df[:cumretx], df[:weight_port], df[:ME_base]= NaN, NaN, NaN, NaN
  cc = 0
  for row in eachrow(df)
    cc+=1
    # If this is the very first observation for this permno
    if cc==1
      row[:LME] = row[:ME]/(1+parse(row[:RETX]))
      row[:cumretx] = 1+parse(row[:RETX])
      row[:ME_base] = row[:LME]
      row[:weight_port] = NaN
    # If this is not the very first observation for the Permno but we are in july
    # and need to consider rebalancing
  elseif cc > 1 && Dates.month(row[:CRSPDATE])==7
      row[:weight_port] = pastLME
      row[:ME_base] = pastLME
      row[:cumretx] = 1+parse(row[:RETX])
      row[:LME] = pastME
    # If it is not the first observation and we have no rebalancing (not july)
    else
      if pastLME>0
        row[:weight_port] = pastCumretx*pastMe_base
      else
        row[:weight_port] = NaN
      end
      row[:cumretx] = pastCumretx*(1+parse(row[:RETX]))
      row[:LME] = pastME
      row[:ME_base] = pastLME
    end
    # Retain variable value for next iteration
    pastME = row[:ME]
    pastLME = row[:LME]
    pastCumretx = row[:cumretx]
    pastWeight_port = row[:weight_port]
    pastMe_base = row[:ME_base]
  end
  return df
end


end #module
