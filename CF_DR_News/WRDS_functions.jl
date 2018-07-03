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


#=========================================================================
Delisting returns are indicated on separated lines.
Put the delisting return on the row of the date of occurence and delete
redundant lines.
=========================================================================#
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




function ageCompustat(df, minHistLength=Dates.Year(0), dateSymbol=:CSDATE, rowdeletion = true)
  firstObs = minimum(df[dateSymbol])
  df[:AGE_Compustat] = missing
  df[:AGE_Compustat] = Array{Union{DateTime, Missing}}(df[:AGE_Compustat])
  cc = 0
  rowstodelete = Int[]
  for row in eachrow(df)
    cc+=1
    row[:AGE_Compustat] = row[dateSymbol]-firstObs
    if Dates.Year(row[:AGE_Compustat])<minHistLength
      push!(rowstodelete, cc)
    end
  end
  if rowdeletion
    deleterows!(df, rowstodelete)
  end
  return df
end

function sameRowVarComp(df)
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


function removeMissing(df, var, acceptedTypes = (Float64, Int64), filterExchange=true)
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

function lagvariable(df, var)
  for row in eachrow(df)

  end
end

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

function permcoDateClean(CRSP_data, dateSymbol)
  tic()
  permcoDateMap = Dict()
  for row in eachrow(CRSP_data)
    try
      push!(permcoDateMap[row[:PERMCO]], row[dateSymbol])
    catch
      permcoDateMap[row[:PERMCO]] = []
      push!(permcoDateMap[row[:PERMCO]], row[dateSymbol])
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
    permdf = CRSP_data[(CRSP_data[:PERMCO].==permco[1]),:]
    for d in Set(permco[2])
      df = permdf[(permdf[dateSymbol].==d),:]
      maxidx = findmax(df[:ME])[2]
      toadd[(df[:PERMNO][maxidx], df[dateSymbol][maxidx])] = (df[:cleanpermco][maxidx], sum(df[:ME]))
      # add the same but for the lines that will have to be removed
      for r in 1:size(df, 1)
        if r != maxidx
          toremove[(df[:PERMNO][r], df[dateSymbol][r])] = df[:cleanpermco][r]
        end
      end
    end
    print("\n$(round((100*cc)/length(duplicateDates), 2))% \n")
  end
  @save "/run/media/nicolas/Research/Data/temp/permcodatemap.jld2" toadd toremove permcoDateMap
  return (toadd, toremove, permcoDateMap)
end


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

function computeROE(df)
  # if ((be+lag(be))/2)>0 then roe=ib/((be+lag(be))/2)
  # if lagbe4>=0 then roeq=%ttm(ibq)/lagbe4
  # if first.gvkey or first.fyr then do; lagbe4=be4
  # be4=%mean_year(beq)
  df[:ROEq] = missing
  df[:ROEq] = Array{Union{Float64, Missing}}(df[:ROEq])
  lagibq = Array{Any}(zeros(3*4))
  lagbe4 = Array{Any}(zeros(3*4))
  mcount, nmcount = 0, 0
  cc=0
  for row in eachrow(df)
    cc+=1
    shift!(lagibq)
    push!(lagibq, row[:ibq])
    shift!(lagbe4)
    push!(lagbe4, row[:ibq])
    if cc>(3*4-1)
      try
        row[:ROEq] = sum(skipmissing(lagibq))/lagbe4[1]
      catch
        row[:ROEq] = missing
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

function computeDE(df)
  # de_ratioq=%mean_year(ltq)/%mean_year(sum(ceqq,pstkq)); /*debt to equity ratio*/
  df[:ceqqpstkq] = df[:ceqq]+df[:PSq]
  lagsltq, lagsceqqpstkq = Array{Any}(zeros(3*4)), Array{Any}(zeros(3*4))
  cc=0
  df[:deq] = missing
  df[:deq] = Array{Union{Float64, Missing}}(df[:deq])
  mcount, nmcount = 0, 0
  for row in eachrow(df)
    cc+=1
    shift!(lagsltq)
    push!(lagsltq, row[:ltq])
    shift!(lagsceqqpstkq)
    push!(lagsceqqpstkq, row[:ceqqpstkq])
    if cc>(3*4-1)
      try
        row[:deq] = mean(skipmissing(lagsltq))/mean(skipmissing(lagsceqqpstkq))
      catch
        row[:deq] = missing
      end
      if ismissing(row[:deq])
        mcount+=1
      else
        nmcount+=1
      end
    end
  end
  return df
end

function month_year(df, dateSymbol)
  df[:MONTH] = 0
  df[:YEAR] = 0
  for row in eachrow(df)
    row[:MONTH] = Dates.month(row[dateSymbol])
    row[:YEAR] = Dates.year(row[dateSymbol])
  end
  return df
end

function computeBreakpoints(res, df, crtdate, vars, dateSymbol)
  for row in eachrow(df)
    if row[dateSymbol]==crtdate && row[:MONTH]==6
      push!(res[1], row[vars[1]])
      push!(res[2], row[vars[2]])
    elseif row[dateSymbol]>crtdate
      break
    end
  end
  return res
end

function assignPortfolio(df, breakpoints, vars, dateSymbol, counter, typesort="5x5", output=String)
  typesort = Symbol("$(typesort)_$(vars[1])_$(vars[2])")
  df[typesort] = missing
  df[typesort] = Array{Union{String, Missing, Float64}}(df[typesort])
  idx=0
  for row in eachrow(df)
    if Dates.month(row[dateSymbol])>6
      idx = Dates.year(row[dateSymbol])-1972
    else
      idx = Dates.year(row[dateSymbol])-1973
    end
    if idx==0
      counter+=1
      print("$(row[:PERMNO]) - $(row[:CRSPDATE])\n")
    else
      t1 = 0
      if row[vars[1]]>breakpoints[1][idx][end]
        t1 = length(breakpoints[1][idx])+1
      else
        cc=0
        for q in breakpoints[1][idx]
          cc+=1
          if row[vars[1]]<q
            t1=cc
            break
          end
        end
      end
      t2 = 0
      if row[vars[2]]>breakpoints[2][idx][end]
        t2 = length(breakpoints[2][idx])+1
      else
        cc=0
        for q in breakpoints[2][idx]
          cc+=1
          if row[vars[2]]<q
            t2=cc
            break
          end
        end
      end
      if output==String
        row[typesort] = "$(t1)_$(t2)"
      elseif output==Float64
        row[typesort] = parse("$(t1).$(t2)")
      end
    end
  end
  return (df, counter)
end


function flattenDF(dicdf, cols, rowprint=50)
  coldic = Dict()
  for var in cols
    coldic[var] = dicdf[var]
  end
  # cc=0
  # coldic = Dict()
  # tic()
  # for permno in dicdf
  #   cc+=1
  #   if cc<250000 #used to be ==1 if you want multiple permnos
  #     for var in cols
  #       coldic[var] = permno[2][var]
  #     end
  #   else
  #     for var in cols
  #       coldic[var] = vcat(coldic[var], permno[2][var])
  #     end
  #   end #if first permno I initialize df
  #   if cc>=length(dicdf)
  #     break
  #   end
  #   if cc%rowprint==0
  #     print("Advancement : $(round(100*cc/length(dicdf), 2))% \n")
  #     toc()
  #     tic()
  #     # break
  #   end
  # end
  # toc()
  return coldic
end



function rfScaling(df, rfdf)
  df[:scaledRet] = NaN
  for row in eachrow(df)
    print(row[:CRSPDATE])
    crtrf = rfdf[rfdf[:date] .== row[:CRSPDATE], :][:value][1]/100
    row[:scaledRet] = 0.9*row[:retadj]+0.1*crtrf
  end
  return df
end


function profitability(df, dateSymbol)
  # profitability Novy-Marx
  df[:grossProfit] = row[:revtq] -(Missings.coalesce.(df[:cogsq],0))/df[:atq]
  # profitability FF
  df[:operatingProfit] = df[:revtq] -(Missings.coalesce.(df[:cogsq],0)+Missings.coalesce.(df[:xintq],0)+Missings.coalesce.(df[:xsgaq],0))/df[:BEq]
  return df
end
