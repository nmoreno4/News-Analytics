using CSV, Missings, DataFrames, JLD2, Suppressor

###!!!!! Download DLSTDT from CRSP

#= Quotaing Vuolateenha (2002)
First, I require all firms to have a December
fiscal-year end of t - 1, in order to align accounting variables across firms.
Second, a firm must have t - 1, t - 2, and t - 3 book equity available, where
t denotes time in years. Third, I require t - 1 and t - 2 net income and
long-term debt data.
A number of CRSP data requirements must also be satisfied. A valid market-
equity figure must be available for t - 1, t - 2, and t - 3. I require that there
is a valid trade during the month immediately preceding the period t return.
This requirement ensures that the return predictability is not spuriously
induced by stale prices or other similar market microstructure issues. I also
require at least one monthly return observation during each of the preceding
five years, from t - 1 to t - 5. In addition, I screen out clear data errors and
mismatches by excluding firms with t - 1 market equity less than $10 mil-
lion and book-to-market more than 100 or less than 1/100.
If no return data are available, I substitute zeros for both returns and div-
idends
 =#

datebeg = Dates.DateTime(1963,1,1)
dateend = Dates.DateTime(2018,1,1)
freq = Dates.Month(3)
recomputeAgeMap = false
recomputePermcoDateSum = false
recomputeWeightPort = false

@suppress_err begin
#= Load Compustat Data ~60sec=#
CSdf = @time loadWRDSdata("/home/nicolas/Data/WRDS/quarterly 1961 compustat merged(2).csv", [:datadate, :CSDATE])
#= Load CRSP Data : ~200sec =#
CRSPdf = @time loadWRDSdata("/home/nicolas/Data/WRDS/monthly CRSP 1961.csv", [:date, :CRSPDATE])
end #supress_err

CSdf[:PSq] = Missings.coalesce.(CSdf[:pstkq],CSdf[:pstkrq],CSdf[:pstknq],0)
CSdf[:txditcq] = Missings.coalesce.(CSdf[:txditcq],0)
CRSPdf = @time dlretOnLine(CRSPdf) #~75sec
CRSPdf = @time sameRowVarComp(CRSPdf) #~200sec
vars = [:ME, :RET]
CRSPdf, crtdel = removeMissing(CRSPdf, vars, true) #271678 rows removed, 3790369 kept
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
    row[:ME] = valtoadd[valcc]
    valcc+=1
  end
end
deleterows!(CRSPdf, linestoremove)


vars = [:atq]
CSdf, crtdel = removeMissing(CSdf, vars, false)

for i in names(CSdf)
  print("$i \n")
end

CSmap = @time df_to_PERMNO_Dict(CSdf, :LPERMNO, :CSDATE, 3000, "/run/media/nicolas/Research/Data/temp/CSdfPERMNOquarterly.jld2", false)
CRSPmap = @time df_to_PERMNO_Dict(CRSPdf, :PERMNO, :CRSPDATE, 3000, "/run/media/nicolas/Research/Data/temp/CRSPdfPERMNO.jld2", false)

typeof(CSmap[35510][:atq])
for i in names(CRSPmap[35510])
  print("$i \n")
end
#!!!! Add EXCHCD !!!!

# CSvars = [:CSDATE, :GVKEY, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :act, :at, :ceq, :cogs, :ebit, :lt, :pstk, :pstkl, :pstkrv, :revt, :sale, :seq, :txditc, :xint, :xsga, :exchg]#, :AGE_Compustat]
CSvars = [:CSDATE, :GVKEY, :LINKPRIM, :LIID, :LINKTYPE, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :actq, :atq, :ceqq, :cogsq, :epsfiq, :epspiq, :epspxq, :ibq, :ltq, :revtq, :saleq, :seqq, :txditcq, :xintq, :xsgaq, :exchg, :capxy, :gind, :gsector, :PSq]#, :AGE_Compustat]
# !!!! Careful : order of variables is important (must be the same as in df)
CRSPvars = [:CRSPDATE, :PERMNO, :EXCHCD, :TICKER, :COMNAM, :PERMCO, :PRC, :VOL, :RET, :SHROUT, :SPREAD, :RETX, :dlret, :retadj, :ME]#, :retadj, :ME, :weight_port, :ME_dec]
# finalOrder = [:PERMNO, :DATE, :retadj, :ME, :exchg, :TICKER, :COMNAM, :PRC, :VOL, :SHROUT, :SPREAD, :weight_port, :ME_dec, :GVKEY, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :act, :at, :ceq, :cogs, :ebit, :lt, :pstk, :pstkl, :pstkrv, :revt, :sale, :seq, :txditc, :re, :xint, :xsga, :AGE_Compustat]
# finalOrder = [:PERMNO, :CRSPDATE, :CSDATE, :exchg, :TICKER, :COMNAM, :PRC, :VOL, :SHROUT, :SPREAD, :GVKEY, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :act, :at, :ceq, :cogs, :ebit, :lt, :pstk, :pstkl, :pstkrv, :revt, :sale, :seq, :txditc, :xint, :xsga]
finalOrder = [:PERMNO, :CRSPDATE, :CSDATE, :retadj, :ME, :ibq, :EXCHCD, :TICKER, :COMNAM, :PRC, :VOL, :RET, :SHROUT, :SPREAD, :RETX, :dlret, :CSDATE, :GVKEY, :LINKPRIM, :LIID, :LINKTYPE, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :actq, :atq, :ceqq, :cogsq, :epsfiq, :epspiq, :epspxq, :ltq, :revtq, :saleq, :seqq, :txditcq, :xintq, :xsgaq, :capxy, :exchg, :gind, :gsector, :PSq]

@suppress_err begin
mergedDF = @time CRSP_CS_merge(CSmap, CRSPmap, CSvars, CRSPvars, finalOrder, 50, freq)
end
#77024, 27756, 43597, 20853
@load "/run/media/nicolas/Research/Data/temp/finalDFquarterly.jld2" mergedDF
# @load @time "/run/media/nicolas/Research/Data/temp/finalDFquarterly.jld2" mergedDF


#compute ME and adjret
# tic()
# for permno in mergedDF
#   mergedDF[permno[1]] = sameRowVarComp(permno[2])
# end
# toc()

#remove rows of missing at, RET,... and filter for EXCHCD: NYSE, AMEX, NASDAQ only
# vars = [:atq, :RET]
# tic()
# totdeleted = 0
# cc=0
# for permno in mergedDF
#   cc+=1
#   print(permno[1])
#   mergedDF[permno[1]], crtdel = removeMissing(permno[2], vars, true)
#   totdeleted+=crtdel
#   if cc%50==0
#     print("Advancement : $(round(100*cc/length(mergedDF), 2))% \n")
#   end
# end
# toc()



#compute weight_port
tic()
for permno in mergedDF
  mergedDF[permno[1]] = weight_port(permno[2])
end
toc()

tic()
for permno in mergedDF
  mergedDF[permno[1]] = ME_June_Dec(permno[2], :CRSPDATE)
end
toc()
mergedDF[35510][[:CRSPDATE, :ME_june, :ME_dec, :ME, :retadj]]


#compute BE
tic()
for permno in mergedDF
  mergedDF[permno[1]] = computeBE(permno[2])
end
toc()
mergedDF[35510][:BM_GGq]

#compute ROE
tic()
for permno in mergedDF
  mergedDF[permno[1]] = computeROE(permno[2])
end
toc()
mergedDF[35510][[:CRSPDATE]]


#compute D/E
tic()
cc=0
for permno in mergedDF
  mergedDF[permno[1]] = computeDE(permno[2])
end
toc()

#compute P/E
tic()
cc=0
for permno in mergedDF
  mergedDF[permno[1]] = computePE(permno[2])
end
toc()

mergedDF[35510][[:CAPEIq5y, :ROEq, :BEq, :CAPEIq, :CRSPDATE]]


#Compustat AGE
tic()
for permno in mergedDF
  mergedDF[permno[1]] = ageCompustat(permno[2], Dates.Year(2))
end
toc()
mergedDF[35510][[:CRSPDATE, :ME_june, :ME_dec, :ME, :retadj]]


tmis = 0
for permno in mergedDF
  for i in permno[2][:ibq]
    if ismissing(i)
      tmis+=1
    end
  end
  # tmis+=size(permno[2], 1)
end

tic()
vars=:BEMEq #also deletes all observations where BEq is missing
rr = []
for permno in mergedDF
  mergedDF[permno[1]], removed = removeMissing(permno[2], vars, false)
  push!(rr, removed)
end
toc()
tot = 0
tdel = 0
for i in rr
  tot+=i[2]
  tdel+=i[1]
end

rr = []
tic()
for permno in mergedDF
  mergedDF[permno[1]], removed = removeearlyDates(permno[2], Dates.Date(1972,7), :CRSPDATE)
  push!(rr, removed)
end
toc()

## Compute scaled returns
tic()
for permno in mergedDF
  mergedDF[permno[1]] = rfScaling(permno[2], riskfree)
end
toc()


#compute portfolio breakpoints and classification
tic()
for permno in mergedDF
  mergedDF[permno[1]] = month_year(permno[2], :CRSPDATE)
end
toc()


allyears = []
vars = [:ME_june, :BEMEq]
for y in 1973:2017
  tic()
  res = [[],[]]
  for permno in mergedDF
    res = computeBreakpoints(res, permno[2], y, vars, :YEAR)
  end
  toc()
  push!(allyears, res)
end

breakpoints = [[],[]]
for y in allyears
  vec = Float64[]
  for i in y[1]
    if !ismissing(i)
      push!(vec, i)
    end
  end
  push!(breakpoints[1], quantile(vec, [0.2 0.4 0.6 0.8]))
  vec = Float64[]
  for i in y[2]
    if !ismissing(i)
      push!(vec, i)
    end
  end
  push!(breakpoints[2], quantile(vec, [0.2 0.4 0.6 0.8]))
end


tic()
vars = [:ME_june, :BEMEq]
counterc = 0
for permno in mergedDF
  mergedDF[permno[1]], counterc = assignPortfolio(permno[2], breakpoints, vars, :CRSPDATE, counterc, "5x5", Float64)
end
toc()
mergedDF[84277], a = removeMissing(mergedDF[84277], :BEMEq, false)
mergedDF[35510][Symbol("$(typesort)_$(vars[1])_$(vars[2])")]
#!!!!!!!!!!!! Check if breakpoints are forward-looking or on the right day
mergedDF[35510][:gsector]

typesort="5x5"
varstokeep = [:CRSPDATE, :PERMNO, Symbol("$(typesort)_$(vars[1])_$(vars[2])"), :ROEq, :deq, :CAPEIq, :CAPEIq5y, :retadj, :BEMEq, :ME, :VOL, :SPREAD, :gsector, :weight_port]
varstokeep = [:PERMNO, Symbol("$(typesort)_$(vars[1])_$(vars[2])"), :ROEq, :deq, :CAPEIq, :CAPEIq5y, :retadj, :BEMEq, :ME, :VOL, :SPREAD, :weight_port, :YEAR, :MONTH]
varstokeep = [:PERMNO, Symbol("5x5_$(vars[1])_$(vars[2])"), :ROEq, :deq, :CAPEIq, :CAPEIq5y, :retadj, :BEMEq, :ME, :VOL, :SPREAD, :weight_port, :YEAR, :MONTH, :scaledRet, :BM_GGq, Symbol("2x3_$(vars[1])_$(vars[2])")]


span = 600
kstart = 2
kend = kstart+span
totempty = 0
finalDF = @time flattenDF(mergedDF[collect(keys(mergedDF))[1]], varstokeep)
for permnocount in 1:ceil(length(mergedDF)/span)
  flatDF = flattenDF(mergedDF[collect(keys(mergedDF))[kstart]], varstokeep)
  print(kstart)
  for permno in collect(keys(mergedDF))[kstart:kend]
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
  # if permnocount == 5
  #   break
  # end
end


a = finalDF[varstokeep[1]]
for vname in varstokeep[2:end]
  a = hcat(a, finalDF[vname])
end
a = DataFrames.DataFrame(a)
names!(a, varstokeep)
CSV.write("/home/nicolas/Data/Input data/june1973dec2017NEW.csv", a)

a = CSV.read("/home/nicolas/Data/Input data/june1972dec2017.csv")
kdates = Set(a[:CRSPDATE])

@save "/run/media/nicolas/Research/Data/temp/FFratios1972filtered.jld2" mergedDF
@load "/run/media/nicolas/Research/Data/temp/FFratios1972filtered.jld2" mergedDF


#Vuolteenhao (2002) uses rolled over 1-month T-Bills from Abbotson Associates
riskfree = CSV.read("/home/nicolas/Data/Input data/riskfree.csv")
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
mergedDF[35510][:retadj]
riskfree[:date][3300]==mergedDF[35510][:CRSPDATE][3]

@time riskfree[riskfree[:date] .== Dates.Date(mergedDF[35510][:CRSPDATE][3]), :][2][1]
@time riskfree[riskfree[:date] .== Dates.DateTime(1990,3,30), :][2][1]

for i in names(mergedDF[35510])
  print("$i \n")
end

flatDF = mergedDF[35510]
for permno in mergedDF
  if permno[1]!=35510
    flatDF = [flatDF; permno[2]]
  end
end

#remove trend and seasonality

#interpolate quarterly variables to monthly

#compute variables averages per portfolio



















































########################################
#2x3 portfolios
########################################
sortingVars = [:ME_june, :BEMEq]
breakpoints = @time computeBreakpoints(mergedDF, sortingVars, [0.3 0.7])

tic()
counterc = 0
cc=0
rowprint = round(length(mergedDF)/100)
for permno in mergedDF
  cc+=1
  mergedDF[permno[1]], counterc = assignPortfolio(permno[2], breakpoints, sortingVars, :CRSPDATE, counterc, "2x3", Float64, 6, 1972)
  if cc % rowprint == 0
    print("\n$(round((100*cc)/size(mergedDF,1), 2))% \n")
  end
end
toc()
