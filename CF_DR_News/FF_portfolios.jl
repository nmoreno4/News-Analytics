using CSV, Missings, DataFrames, JLD2

datebeg = Dates.DateTime(1963,1,1)
dateend = Dates.DateTime(2018,1,1)
freq = Dates.Year(1)
recomputeAgeMap = false
recomputePermcoDateSum = false
recomputeWeightPort = false

#==================== Compustat Variables ===============================
/* GVKEY    =                                                           */
/* LIID     =                                                           */
/* LPERMNO  =                                                           */
/* LINKDT   =                                                           */
/* LINKENDDT=                                                           */
/* DATADATE =                                                           */
/* FYEAR    = Fiscal Year                                               */
/* INDFMT   =                                                           */
/* CONSOL   =                                                           */
/* POPSRC   =                                                           */
/* DATAFMT  =                                                           */
/* TIC      = Ticker                                                    */
/* CUSIP    = Currency                                                  */
/* CONM     = Company Name                                              */
/* CURCD    = Currency                                                  */
/* FYR      = Fiscal Year-end                                           */
/* ACT      = Current Assets Total                                      */
/* AT       = Assets Total                                              */
/* CEQ      = Common/Ordinary equity                                    */
/* COGS     = Cost of Good Sold                                         */
/* EBIT     = Earnings Before Interests and Taxes                       */
/* LT       = Liabitlities Total                                        */
/* PSTK     = Preferred/Preference Stock (Capital) - Total              */
/* PSTKC    = Preferred Stock Convertible                               */
/* PSTKL    = Preferred Stock Liquidating Value                         */
/* PSTKN    = Preferred Stock Nonredeemable                             */
/* PSTKR    = Preferred Stock Redeemable                                */
/* PSTKRV   = Preferred Stock Redemption Value                          */
/* RE       = Retained Earnings                                         */
/* REVT     = Revenue Total                                             */
/* SALE     = Sales/Turnover Net                                        */
/* SEQ      = Total Parent Stockholders' Equity                         */
/* TXDITC   = Deferred Taxes and Investment Tax Credit                  */
/* XINT     = Interest and Related Expense - Total                      */
/* XSGA     = Selling, General and Administrative Expense               */
/* EXCHG    = Stock Exchange Code                                       */
/* COSTAT   =                                                           */
/* SICH     = Standard Industrial Classification - Historical           */
/* PRCC_C   = Price Close - Annual - Calendar                           */
/* DVPSP_F  = Dividends per Share/Pay Date - Fiscal                     */
/* MKVALT   = Market Value - Total (Fiscal)                             */
/* GIND     = GIC Industries                                            */
/* GSECTOR  =                                                           */
/* GSUBIND  =                                                           */
/* SIC      =                                                           */
/* SPCINDCD =                                                           */
/* SPCSECCD =                                                           */
/* SPSRC    =                                                           */
======================== CRSP Variables =================================
/* PERMNO  = CRSP Permanent Security Identifier                         */
/* dates   =                                                            */
/* SHRCD   = Share Code                                                 */
/* EXCHCD  = Exchange Code: 1 = NYSE, 2 = NYSE American, 3 = NASDAQ     */
/* NCUSIP  =                                                            */
/* TICKER  = Ticker Symbol                                              */
/* COMNAM  = Company Name                                               */
/* SHRCLS  = Share Class                                                */
/* TSYMBOL = Trading Ticker Symbol on Primary Exchange                  */
/* PRIMEXCH= Primary Exchange Traded: N = NYSE, A = NYSE American, Q = NASDAQ */
/* TRDSTAT = Trading Status: A = Active, H = Halted, S = Suspended, X = Unknown */
/* PERMCO  = CRSP Permanent Company Identifier                          */
/* HEXCD   = Header Exchange Code                                       */
/* CUSIP   =                                                            */
/* DLSTCD  = Delisting Code                                             */
/* PAYDT   = Payment Date (Dividend distribution)                       */
/* DISTCD  = Distribution Code                                          */
/* DIVAMT  = Dividend Cash Amount                                       */
/* SHRENDDT= Shares Outstanding Observation End Date                    */
/* DLRET   = Delisting Return                                           */
/* PRC     = Price                                                      */
/* VOL     = Share Volume (Trading Volume)                              */
/* RET     = Holding Period Return                                      */
/* SHROUT  = Number of Shares Outstanding                               */
/* SPREAD  = Spread Between Bid and Ask                                 */
/* RETX    = Holding Period Return without Dividends                    */

===================== Notes on Preferred stocks =========================
/* In calculating Book Equity, incorporate Preferred Stock (PS) values */
/*  use the redemption value of PS, or the liquidation value           */
/*    or the par value (in that order) (FF,JFE, 1993, p. 8)            */
/* Use Balance Sheet Deferred Taxes TXDITC if available                */

===================== Notes on Preferred stocks =========================
/* Flag for number of years in Compustat (<2 likely backfilled data)   */

===================== Variables to keep from Compustat ==================
AT ACT LT  TXDITC SEQ PSTK CEQ SEQ PSTK PSTKL PSTKRV  REVT COGS XINT XSGA
RE EBIT SALE
=========================================================================

=========================================================================
1- Load data from CRSP into DataFrame
2- Trasform dates into julia date format
=========================================================================#
CRSPdf = @time loadWRDSdata("/home/nicolas/Data/WRDS/yearly 1961 FF compustat merged.csv")

#=========================================================================
1- Map each PERMNO to its first observation date. (PERMNO -> DateTime(oldest))
2- Add a column recording the age since first observation
3- Remove observations younger than 2 years (because might be backfilled data)
=========================================================================#
if recomputeAgeMap
  firstObsMap = Dict()
  cc = 0
  for permno in Set(yearly_data[:LPERMNO])
    cc+=1
    df = yearly_data[(yearly_data[:LPERMNO].==permno),:]
    firstObsMap[permno] = minimum(df[:DATE])
    print("$(cc/length(Set(yearly_data[:LPERMNO]))) \n")
  end
  @save "/home/nicolas/Data/temp/firstObsMap.jld2" firstObsMap
else
  @load "/home/nicolas/Data/temp/firstObsMap.jld2" firstObsMap
end
yearly_data[:AGE_Compustat] = yearly_data[:DATE]
cc = 0
rowstodelete = Int[]
for row in eachrow(yearly_data)
  cc+=1
  row[:AGE_Compustat] = row[:DATE]-firstObsMap[row[:LPERMNO]]
  if Dates.Year(row[:AGE_Compustat])<Dates.Year(2) || (!ismissing(row[:at]) && row[:at] <=0) || ismissing(row[:at])
    push!(rowstodelete, cc)
  end
end
deleterows!(yearly_data, rowstodelete)
maximum(yearly_data[:AGE_Compustat]) #for control


#=================== Compustat variable computation ======================
!!!!!!!!!!!!!!!!!ASK BORIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
There is something weird with the addition/substraction of PS in CEQ_/BE
!!!!!!!!!!!!!!!!!ASK BORIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
status
1- Assign a value to PS (either pstk, pstkl, pstkrv or 0 in this order of preference).
2- To follow Fama French 1993, add Preferred stocks to common equity
3- Add TXDITC to adjust for tax deferrals:
    This item represents the accumulated tax deferrals due to
    timing differences between the reporting of revenues and expenses
    for financial statements and tax forms and investment tax credit.
    This item is part of Liabilities LT
4- Define share equity as Stockholders equity preferrably, then CEQ_ and BKV
5- Compute BE as Share equity + tax deferrals - preferred shares
=========================================================================#
PS = Missings.coalesce.(yearly_data[:pstk],yearly_data[:pstkl],yearly_data[:pstkrv],0)
CEQ_ = yearly_data[:ceq]+PS
TXDITC = Missings.coalesce.(yearly_data[:txditc],0)
BKV = yearly_data[:at] - yearly_data[:lt]
SHE = Missings.coalesce.(yearly_data[:seq], CEQ_, BKV)
yearly_data[:BE] = SHE + TXDITC - PS
#Check out for observations where BE = 0


#=========================================================================
Refernce the year to compute ME of June t and ME of December t-1
=========================================================================#
for d in yearly_data[:DATE]
  if Dates.month(d)>=7
    yearly_data[:YEAR_ME_June] = Dates.year(d)
  else
    yearly_data[:YEAR_ME_June] = Dates.year(d)-1
  end
end
for d in yearly_data[:DATE]
  if Dates.month(d)>=7
    yearly_data[:YEAR_ME_BM] = Dates.year(d)-1
  else
    yearly_data[:YEAR_ME_BM] = Dates.year(d)-2
  end
end

#=========================================================================
Regroup whole dataframe by PERMNO and sort by date
=========================================================================#
CSdfPERMNO = Dict()
cc=0
for row in eachrow(yearly_data)
  cc+=1
  try
    push!(CSdfPERMNO[row[:LPERMNO]], Array(row))
  catch
    CSdfPERMNO[row[:LPERMNO]] = DataFrame(Array(row))
    names!(CSdfPERMNO[row[:LPERMNO]], names(yearly_data))
  end
  if cc % 30000 == 0
    print("\n$(round((100*cc)/size(yearly_data,1), 2))% \n")
  end
end

for permno in CSdfPERMNO
  sort!(permno[2], cols = [:DATE])
end


#=========================================================================
Load CRSP data and format the dates to julia DateTime
=========================================================================#
CRSP_data = @time readtable("/home/nicolas/Data/WRDS/monthly CRSP 1961.csv")
dates = String[]
for d in CRSP_data[:date]
  push!(dates, string(d))
end
CRSP_data[:DATE] = DateTime(dates,"yyyymmdd")

#=========================================================================
Delisting returns are indicated on separated lines.
Put the delisting return on the row of the date of occurence and delete
redundant lines.
=========================================================================#
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

#=========================================================================
1- Keep only data from the NYSE, AMEX or NASDAQ
2- Delete rows where the observation is missing for the return
=========================================================================#
cc = 0
rowstodelete = Int[]
for row in eachrow(CRSP_data)
  cc+=1
  if !(!ismissing(row[:EXCHCD]) && row[:EXCHCD] in [1,2,3]) || ismissing(row[:RET]) || typeof(parse(row[:RET]))!=Float64
    push!(rowstodelete, cc)
  end
end
deleterows!(CRSP_data, rowstodelete)

#=========================================================================
1- Compute return adjusted for delisting
2- Compute ME as price*Shares_outstanding (divided by factor 1000)
=========================================================================#
CRSP_data[:retadj] = NaN
CRSP_data[:ME] = NaN
for row in eachrow(CRSP_data)
  row[:retadj] = (1+parse(row[:RET]))*(1+row[:dlret])-1
  row[:ME] = abs(row[:PRC])*row[:SHROUT]
end
#Check for observations where ME = 0


#=========================================================================
There are cases when the same firm (permco) has two or more
securities (permno) at same date. For the purpose of ME for
the firm, we aggregated all ME for a given permco, date. This
aggregated ME will be assigned to the Permno with the largest ME

Create a dictionnary with all PERMCO-DATES pairs
=========================================================================#
permcoDateMap = Dict()
for row in eachrow(CRSP_data)
  try
    push!(permcoDateMap[row[:PERMCO]], row[:DATE])
  catch
    permcoDateMap[row[:PERMCO]] = []
    push!(permcoDateMap[row[:PERMCO]], row[:DATE])
  end
end
#=========================================================================
Function returning true if val is to be found in iterable x more than once
=========================================================================#
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
#=========================================================================
Create a dictionnary with all PERMCO-DATES pairs *duplicates*
=========================================================================#
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
#=========================================================================
Assign a unique id to each row to be able to find the row back later
when filtering the dataframe.
=========================================================================#
CRSP_data[:cleanpermco] = NaN
cc=0
for row in eachrow(CRSP_data)
  cc+=1
  row[:cleanpermco] = cc
end
#=========================================================================
Find maximum ME for permno for each PERMCO-DATE duplicate and assign to it
the sum of all MEs of the duplicates.
Delete the other rows, which were not max ME and have a duplicate.
=========================================================================#
toadd = Dict()
toremove = Dict()
cc = 0
if recomputePermcoDateSum
  for permco in duplicateDates
    cc+=1
    permdf = CRSP_data[(CRSP_data[:PERMCO].==permco[1]),:]
    for d in Set(permco[2])
      df = permdf[(permdf[:DATE].==d),:]
      maxidx = findmax(df[:ME])[2]
      toadd[(df[:PERMNO][maxidx], df[:DATE][maxidx])] = (df[:cleanpermco][maxidx], sum(df[:ME]))
      # add the same but for the lines that will have to be removed
      for r in 1:size(df, 1)
        if r != maxidx
          toremove[(df[:PERMNO][r], df[:DATE][r])] = df[:cleanpermco][r]
        end
      end
    end
    print("\n$(round((100*cc)/length(duplicateDates), 2))% \n")
  end
  @save "/run/media/nicolas/Research/Data/temp/permcodatemap.jld2" toadd toremove
else
  @load "/run/media/nicolas/Research/Data/temp/permcodatemap.jld2" toadd toremove
end


#=========================================================================
/* The next step does 2 things:                                        */
/* - Create weights for later calculation of VW returns.               */
/*   Each firm's monthly return RET t will  be weighted by             */
/*   ME(t-1) = ME(t-2) * (1 + RETX (t-1))                              */
/*     where RETX is the without-dividend return.                      */
/* - Create a File with December t-1 Market Equity (ME)                */
=========================================================================#
if recomputeWeightPort
  dfPERMNO = Dict()
  cc=0
  for row in eachrow(CRSP_daCompustatta)
    cc+=1
    try
      push!(dfPERMNO[row[:PERMNO]], Array(row))
    catch
      dfPERMNO[row[:PERMNO]] = DataFrame(Array(row))
      names!(dfPERMNO[row[:PERMNO]], names(CRSP_data))
    end
    if cc % 30000 == 0
      print("\n$(round((100*cc)/size(CRSP_data,1), 2))% \n")
    end
  end

  for permno in dfPERMNO
    sort!(permno[2], cols = [:DATE])
  end

  pastLME, pastCumretx, pastWeight_port, pastMe_base, pastME, pastMe_dec =  NaN, NaN, NaN, NaN, NaN, NaN
  for permno in dfPERMNO
    permno[2][:LME], permno[2][:cumretx], permno[2][:weight_port], permno[2][:ME_base], permno[2][:ME_dec] = NaN, NaN, NaN, NaN, NaN
    cc = 0
    for row in eachrow(permno[2])
      cc+=1
      # If this is the very first observation for this permno
      if cc==1
        row[:LME] = row[:ME]/(1+parse(row[:RETX]))
        row[:cumretx] = 1+parse(row[:RETX])
        row[:ME_base] = row[:LME]
        row[:weight_port] = NaN
      # If this is not the very first observation for the Permno but we are in july
      # and need to consider rebalancing
      elseif cc > 1 && Dates.month(row[:DATE])==7
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
      row[:ME_dec] = pastMe_dec
      if Dates.month(row[:DATE])==12 && row[:ME]>0
        row[:ME_dec] = row[:ME]
      end
      pastMe_dec = row[:ME_dec]
    end
    a = permno[2]
  end
  @save "/run/media/nicolas/Research/Data/temp/dfPERMNO.jld2" dfPERMNO
else
  @load "/run/media/nicolas/Research/Data/temp/dfPERMNO.jld2" dfPERMNO
end


#================== Merging CRSP and Compustat ===========================
=========================================================================#
CSvars = [:GVKEY, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :act, :at, :ceq, :cogs, :ebit, :lt, :pstk, :pstkl, :pstkrv, :revt, :sale, :seq, :txditc, :re, :xint, :xsga, :exchg, :AGE_Compustat]
# !!!! Careful : order of variables is important (must be the same as in df)
CRSPvars = [:DATE, :PERMNO, :TICKER, :COMNAM, :PRC, :VOL, :SHROUT, :SPREAD, :retadj, :ME, :weight_port, :ME_dec]
finalOrder = [:PERMNO, :DATE, :retadj, :ME, :exchg, :TICKER, :COMNAM, :PRC, :VOL, :SHROUT, :SPREAD, :ME, :weight_port, :ME_dec, :GVKEY, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :act, :at, :ceq, :cogs, :ebit, :lt, :pstk, :pstkl, :pstkrv, :revt, :sale, :seq, :txditc, :re, :xint, :xsga, :AGE_Compustat]
finalDF = Dict()
deccount = 0
othercount = 0
junecount = 0
for i in names(CSdfPERMNO[35510])
  print("$i \n")
end
for i in CSdfPERMNO
  for j in i[2][:DATE]
    if Dates.month(j)==12
      deccount+=1
    elseif Dates.month(j)==6
      junecount+=1
    else
      othercount+=1
    end
  end
end
CSdfPERMNO[35510][:DATE]
c = 0
d = 0
ctot = 0
crtrow = 0
CRSProw = 0
CScount = 0
boundserrorcount = 0
permno = 0
# dfPERMNO[14193][:DATE]
# CSdfPERMNO[14193][:DATE]
noCRSPdata = 0
emptydf = 0
CRSPdf=0
for permno in CSdfPERMNO
  ctot+=1
  CScount = 1
  CSdf = permno[2]
  try
    CRSPdf = dfPERMNO[CSdf[:LPERMNO][1]]
    emptydf = 1
  catch
    noCRSPdata+=1
    emptydf = 0
  end

  CRSPcount = 0
  if emptydf==1
    for CRSProw in eachrow(CRSPdf)
      CRSPcount+=1
      if CScount<size(CSdf, 1)
        maxdate = CSdf[:DATE][CScount+1]
      else
        # Make beginning/end of dates CRSP/CS match properly
        try
          maxdate = CSdf[:DATE][CScount]+freq
        catch excep
          if isa(excep, BoundsError)
            boundserrorcount+=1
            break
          end
        end
      end
      # print("$(CSdf[:DATE][CScount]) - $(CSdf[:DATE][CScount]) - $(CRSProw[:DATE]) \n \n")
      if CRSProw[:DATE] in CSdf[:DATE][CScount]:maxdate
        #+ other filter conditions linkprim etc?
        crtrow = []
        cc=0
        for el in Array(CRSProw)
          cc+=1
          if names(CRSProw)[cc] in CRSPvars
            push!(crtrow, el)
            # if !ismissing(el) && typeof(el)==DateTime
            #   push!(crtrow, el)
            # elseif !ismissing(el)
            #   push!(crtrow, el[1])
            # else
            #   push!(crtrow, missing)
            # end
          end
        end
        cc=0
        for el in Array(CSdf[CScount, :])
          cc+=1
          if names(CSdf[CScount, :])[cc] in CSvars
            push!(crtrow, el)
            # if !ismissing(el) && typeof(el)==DateTime
            #   push!(crtrow, el)
            # elseif !ismissing(el)
            #   push!(crtrow, el[1])
            # else
            #   push!(crtrow, missing)
            # end
          end
        end

        #First check if dataframe is empty
        #Then check if allrows is empty
        #Then add if possible
        try
          push!(finalDF[permno[1]],crtrow)
          c+=1
        catch excep
          if isa(excep, KeyError)
            finalDF[CRSProw[:PERMNO]] = DataFrame(crtrow)
            names!(finalDF[CRSProw[:PERMNO]], vcat(CRSPvars,CSvars), makeunique=true)
            finalDF[CRSProw[:PERMNO]][:SPREAD] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:SPREAD])
            finalDF[CRSProw[:PERMNO]][:xint] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:xint])
            finalDF[CRSProw[:PERMNO]][:VOL] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:VOL])
            finalDF[CRSProw[:PERMNO]][:xsga] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:xsga])
            finalDF[CRSProw[:PERMNO]][:ceq] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:ceq])
            finalDF[CRSProw[:PERMNO]][:act] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:act])
            finalDF[CRSProw[:PERMNO]][:re] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:re])
            finalDF[CRSProw[:PERMNO]][:ebit] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:ebit])
            finalDF[CRSProw[:PERMNO]][:cogs] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:cogs])
            finalDF[CRSProw[:PERMNO]][:txditc] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:txditc])
            finalDF[CRSProw[:PERMNO]][:revt] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:revt])
            finalDF[CRSProw[:PERMNO]][:sale] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:sale])
            finalDF[CRSProw[:PERMNO]][:seq] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:seq])
            finalDF[CRSProw[:PERMNO]][:at] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:at])
            finalDF[CRSProw[:PERMNO]][:lt] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:lt])
            finalDF[CRSProw[:PERMNO]][:pstk] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:pstk])
            finalDF[CRSProw[:PERMNO]][:pstkl] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:pstkl])
            finalDF[CRSProw[:PERMNO]][:pstkrv] = Array{Union{Float64, Missing}}(finalDF[CRSProw[:PERMNO]][:pstkrv])
            d+=1
          elseif isa(excep, ArgumentError)
            #Change dataframe column types
          end
          print("CScount: $CScount \n CRSPcount: $CRSPcount \n")
          print(excep)
        end
        # if allrows = 0
        #   allrows = crtrow
        #   d+=1
        # else
        #
        # end #if first obs of permno

      elseif CRSProw[:DATE]>maxdate
        # I'm already too far in the dates and they will only keep getting older anyways
        CScount+=1
      end
    end # the CRSP rows to compare to current CS year row
    try
      finalDF[permno[1]] = finalDF[permno[1]][finalOrder]
    catch except
      if isa(except, KeyError)
        print("$(permno[1]) has no CRSP data for the CS date(s)")
      end
    end
  end
  if ctot%1000==0
    print("Advancement : $(round(ctot/length(CSdfPERMNO), 2))")
  end
end

Array{Union{Float64, Missing}}(dfPERMNO[35510][:SPREAD])[:DATE]
#check for rows of CRSP that were excluded
finalDF[14193]
for i in names(dfPERMNO[35510])
  print("$i \n")
end

dfPERMNO[35510][:DATE][5] in CSdfPERMNO[35510][:DATE][3]:dfPERMNO[35510][:DATE][7]
CSdfPERMNO[10094][:DATE][7]:CSdfPERMNO[10094][:DATE][7]+freq

function countMissing(x)
  cc = 0
  for i in x
    if ismissing(i)
      cc+=1
    end
  end
  return cc
end

countMissing(CRSP_data[:ME])


using Plots
plotlyjs()
plot(CRSP_data[:retadj])
using StatsBase
h = fit(Histogram, CRSP_data[:ME], 0:100:20000)
plot(h)
minimum(CRSP_data[:ME])
