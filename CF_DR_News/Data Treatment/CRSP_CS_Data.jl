push!(LOAD_PATH, "$(pwd())/CF_DR_News/Data Treatment/WRDSmodules")
using CSV, Missings, DataFrames, JLD2, Suppressor, RCall
@rlibrary stlplus
using usefulNestedDF, otherCleaning, customWRDSvariables, Portfolio_Sorting

datebeg = Dates.DateTime(1963,1,1)
dateend = Dates.DateTime(2018,1,1)
freq = Dates.Month(3)
if freq == Dates.Month(3)
  fq = "q"
else
  fq = ""
end
recomputeMerge = false
recomputePERMCO = false

if recomputeMerge
#=================== Load CRSP and Compustat Data ======================#
@suppress_err begin
#= Load Compustat Data ~60sec=#
CSdf = @time loadWRDSdata("/run/media/nicolas/OtherData/home/home/nicolas/Data/WRDS/quarterly 1961 compustat merged(2).csv", [:datadate, :CSDATE])
#= Load CRSP Data : ~200sec =#
CRSPdf = @time loadWRDSdata("/run/media/nicolas/OtherData/home/home/nicolas/Data/WRDS/monthly CRSP 1961.csv", [:date, :CRSPDATE])
end #supress_err


#=================== Compute ME and retadj ======================#
CSdf[Symbol("PS$fq")] = Missings.coalesce.(CSdf[Symbol("pstk$fq")],CSdf[Symbol("pstkr$fq")],CSdf[Symbol("pstkn$fq")],0)
CSdf[Symbol("txditc$fq")] = Missings.coalesce.(CSdf[Symbol("txditc$fq")],0)
CRSPdf = @time dlretOnLine(CRSPdf) #~75sec
CRSPdf = @time ME_retadj(CRSPdf) #~200sec
# For CRSP
consistentVars = [:ME, :RET]
CRSPdf, crtdel = removeMissing!(CRSPdf, consistentVars, true) #271678 rows removed, 3790369 kept
# For Compustat
consistentVars = [:ME, :RET]
CSdf, crtdel = removeMissing!(CSdf, vars, false)


#============ Adjust for double PERMNO on certain PERMCOs =================#
if recomputePERMCO
  toadd, toremove, permcoDateMap = @time permcoDateClean(CRSPdf, :CRSPDATE)
  @save "/run/media/nicolas/Research/Data/temp/permcodatemap.jld2" toadd toremove permcoDateMap
else
  @load "/run/media/nicolas/Research/Data/temp/permcodatemap.jld2" toadd toremove permcoDateMap
end
CRSPdf = permcoMerge(CRSPdf, toadd, toremove)


#============ Transform the stacked DataFrame to a dictionnary =================#
#set false to not recompute
CSmap = @time df_to_PERMNO_Dict(CSdf, :LPERMNO, :CSDATE, 3000, "/run/media/nicolas/Research/Data/temp/CSdfPERMNOquarterly.jld2", false)
CRSPmap = @time df_to_PERMNO_Dict(CRSPdf, :PERMNO, :CRSPDATE, 3000, "/run/media/nicolas/Research/Data/temp/CRSPdfPERMNO.jld2", false)

#=====================#
end # if recomputeMerge
#=====================#

#============ Merge CRSP and Compustat Databases =================#
CSvars = [:CSDATE, :GVKEY, :LINKPRIM, :LIID, :LINKTYPE, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :actq, :atq, :ceqq, :cogsq, :epsfiq, :epspiq, :epspxq, :ibq, :ltq, :revtq, :saleq, :seqq, :txditcq, :xintq, :xsgaq, :exchg, :capxy, :gind, :gsector, :PSq]#, :AGE_Compustat]
CRSPvars = [:CRSPDATE, :PERMNO, :EXCHCD, :TICKER, :COMNAM, :PERMCO, :PRC, :VOL, :RET, :SHROUT, :SPREAD, :RETX, :dlret, :retadj, :ME]#, :retadj, :ME, :weight_port, :ME_dec]
finalOrder = [:PERMNO, :CRSPDATE, :CSDATE, :retadj, :ME, :ibq, :EXCHCD, :TICKER, :COMNAM, :PRC, :VOL, :RET, :SHROUT, :SPREAD, :RETX, :dlret, :CSDATE, :GVKEY, :LINKPRIM, :LIID, :LINKTYPE, :LINKDT, :LINKENDDT, :consol, :popsrc, :tic, :cusip, :conm, :actq, :atq, :ceqq, :cogsq, :epsfiq, :epspiq, :epspxq, :ltq, :revtq, :saleq, :seqq, :txditcq, :xintq, :xsgaq, :capxy, :exchg, :gind, :gsector, :PSq]
if recomputeMerge
  @suppress_err begin
  mergedDF = @time CRSP_CS_merge(CSmap, CRSPmap, CSvars, CRSPvars, finalOrder, 50, freq)
  end
  @save "/run/media/nicolas/Research/Data/temp/finalDFquarterly.jld2" mergedDF
else
  @load "/run/media/nicolas/Research/Data/temp/finalDFquarterly.jld2" mergedDF
end


#============ Compute weight_port for VW =================#
for permno in mergedDF
  mergedDF[permno[1]] = weight_port(permno[2])
end

#============ Get last June and December breakpoint computation =================#
for permno in mergedDF
  mergedDF[permno[1]] = ME_June_Dec(permno[2], :CRSPDATE)
end

#============ Compute BE, BEME and BM_GGq =================#
for permno in mergedDF
  mergedDF[permno[1]] = computeBE(permno[2])
end

#============ Compute ROE, DE, CAPEI and CAPEI5y  =================#
for permno in mergedDF
  mergedDF[permno[1]] = computeROE(permno[2])
  mergedDF[permno[1]] = computeDE(permno[2])
  mergedDF[permno[1]] = computePE(permno[2])
end

#============ Filter for age of CS data  =================#
for permno in mergedDF
  mergedDF[permno[1]] = ageCompustat(permno[2], 2, :CSDATE, true)
end

#============ Remove observations where BE (and thus BEME) are missing  =================#
vars=:BEMEq #also deletes all observations where BEq is missing
rr = []
for permno in mergedDF
  mergedDF[permno[1]], removed = removeMissing!(permno[2], vars, (Float64, Int64), false)
  push!(rr, removed)
end
countRemoved(rr)

#============ Remove observations where ROE are missing  =================#
vars=:ROEq #also deletes all observations where BEq is missing
rr = []
for permno in mergedDF
  mergedDF[permno[1]], removed = removeMissing!(permno[2], vars, (Float64, Int64), false)
  push!(rr, removed)
end
countRemoved(rr)


#============ Remove extreme values for BEME (<0.01 or >100) =================#
rr = []
for permno in mergedDF
  mergedDF[permno[1]], removed = filterExtremeValues(permno[2], :BEMEq, 0.01, 100)
  push!(rr, removed)
end
countRemoved(rr)

#============ Scaling=================#
for permno in mergedDF
  mergedDF[permno[1]] = Scaling(permno[2], "BM", :BEMEq, :ME)
end
for permno in mergedDF
  mergedDF[permno[1]] = Scaling(permno[2], "ROE", :ROEq, :ME)
end

#============ Keep only observations older than July 1972  =================#
rr = []
for permno in mergedDF
  mergedDF[permno[1]], removed = removeearlyDates(permno[2], Dates.Date(1972,6), :CRSPDATE)
  push!(rr, removed)
end
countRemoved(rr)

meanROE, stdROE = meanPerPeriod(mergedDF, :ROEq)
meanBEME, stdBEME = meanPerPeriod(mergedDF, :BEMEq)
meanDE, stdDE = meanPerPeriod(mergedDF, :deq)
for permno in mergedDF
  mergedDF[permno[1]] = demean_standardize(permno[2], :ROEq, meanROE, stdROE, :CRSPDATE)
end
for permno in mergedDF
  mergedDF[permno[1]] = demean_standardize(permno[2], :ScaledBEMEq, meanROE, stdROE, :CRSPDATE)
end
for permno in mergedDF
  mergedDF[permno[1]] = demean_standardize(permno[2], :deq, meanROE, stdROE, :CRSPDATE)
end

for permno in mergedDF
  mergedDF[permno[1]] = deseasonalize(permno[2], :ROEq)
end
for permno in mergedDF
  mergedDF[permno[1]] = deseasonalize(permno[2], :ROEq_demeaned)
end
for permno in mergedDF
  mergedDF[permno[1]] = deseasonalize(permno[2], :ROEq_standardized)
end
for permno in mergedDF
  mergedDF[permno[1]] = deseasonalize(permno[2], :ScaledBEMEq_demeaned)
end
for permno in mergedDF
  mergedDF[permno[1]] = deseasonalize(permno[2], :deq_demeaned)
end
mergedDF[35510][:ROEq_demeaned]

#============ Monthly risk-free rates  =================#
kdates = []
for permno in mergedDF
  append!(kdates, mergedDF[permno[1]][:CRSPDATE])
end
kdates = Set(kdates)
riskfree = rfDate("/run/media/nicolas/OtherData/home/home/nicolas/Data/Input data/riskfree.csv", kdates)


#============ Compute scaled returns  =================#
tic()
for permno in mergedDF
  mergedDF[permno[1]] = Scaling(permno[2], "rf", :retadj, :crap, riskfree)
end
toc()
mergedDF[35510][[:weight_port, :ROEq, :Scaledretadj, :CRSPDATE]]


#======= Add a column referencing the year and another the month  ========#
for permno in mergedDF
  mergedDF[permno[1]] = month_year(permno[2], :CRSPDATE)
end


#======= 2x3 portfolio breakpoints  ========#
sortingVars = [:ME_june, :BEMEq]
quintilebreaks = ([0.5], [0.3 0.7])
breakpoints = @time computeBreakpoints(mergedDF, sortingVars, quintilebreaks)
counterc, cc = 0, 0
rowprint = 1*round(length(mergedDF)/100)
# copyDF = deepcopy(mergedDF)
for permno in mergedDF
  cc+=1
  # Pay attention: current starting year is 1971
  mergedDF[permno[1]], counterc = assignPortfolio(permno[2], breakpoints, sortingVars, kdates, "$(length(quintilebreaks[1])+1)x$(length(quintilebreaks[2])+1)", :CRSPDATE, counterc, Float64, 6)
  if cc % rowprint == 0
    print("\n$(round((100*cc)/length(mergedDF), 2))% \n")
  end
end
# mergedDF[14593][[Symbol("$(length(quintilebreaks[1])+1)x$(length(quintilebreaks[2])+1)_$(sortingVars[1])_$(sortingVars[2])"), :ME, :BEMEq, :CRSPDATE]]
# mergedDF[10094], bc = assignPortfolio(copyDF[14593], breakpoints,
#                 sortingVars, kdates,
#                 "$(length(quintilebreaks[1])+1)x$(length(quintilebreaks[2])+1)",
#                 :CRSPDATE, counterc, Float64, 6)
# mergedDF[10094][[Symbol("$(length(quintilebreaks[1])+1)x$(length(quintilebreaks[2])+1)_$(sortingVars[1])_$(sortingVars[2])"),
#                 :ME, :BEMEq, :CRSPDATE]]
# mergedDF[10094][[Symbol("5x5_$(sortingVars[1])_$(sortingVars[2])"),
#                 :ME, :BEMEq, :CRSPDATE]]

#======= 5x5 portfolio breakpoints  ========#
sortingVars = [:ME_june, :BEMEq]
quintilebreaks =([0.2 0.4 0.6 0.8], [0.2 0.4 0.6 0.8])
breakpoints = @time computeBreakpoints(mergedDF, sortingVars, quintilebreaks)
counterc, cc = 0, 0
rowprint = 1*round(length(mergedDF)/100)
# copyDF = deepcopy(mergedDF)
for permno in mergedDF
  cc+=1
  # Pay attention: current starting year is 1971
  mergedDF[permno[1]], counterc = assignPortfolio(permno[2], breakpoints, sortingVars, kdates, "$(length(quintilebreaks[1])+1)x$(length(quintilebreaks[2])+1)", :CRSPDATE, counterc, Float64, 6)
  if cc % rowprint == 0
    print("\n$(round((100*cc)/length(mergedDF), 2))% \n")
  end
end

@save "/run/media/nicolas/Research/Data/temp/mergedDF.jld2" mergedDF

#=============== Save the Data  =================#
varstokeep = [:PERMNO, Symbol("5x5_$(sortingVars[1])_$(sortingVars[2])"), :ROEq_stl_standardized, :ROEq_stl, :ROEq, :ROEq_stl_demeaned, :ROEq_demeaned, :ROEq_standardized, :deq, :CAPEIq, :BEMEq_stl_standardized, :BEMEq_stl, :BEMEq, :BEMEq_stl_demeaned, :BEMEq_demeaned, :BEMEq_standardized, Symbol("2x3_$(sortingVars[1])_$(sortingVars[2])"), :CAPEIq5y, :retadj, :BEMEq, :ME, :VOL, :SPREAD, :weight_port, :YEAR, :MONTH, :scaledRet, :BM_GGq]
varstokeep = [:PERMNO, Symbol("5x5_$(sortingVars[1])_$(sortingVars[2])"), :MONTH, :YEAR, :Scaledretadj, :ROEq_stl, :ScaledBEMEq_demeaned, :ScaledBEMEq_standardized, :ROEq_demeaned, :ROEq_standardized, :deq, :ScaledBEMEq, :deq_demeaned, :deq_standardized, :ROEq_demeaned_stl, :ROEq_standardized_stl, :ScaledBEMEq_demeaned_stl, :deq_demeaned_stl]
finalDF = testDF(mergedDF, varstokeep, 600,2)
function testDF(mergedDF, varstokeep, span=600, kstart=2)
  totempty = 0
  kend = kstart+span
  finalDF = flattenDF(mergedDF[collect(keys(mergedDF))[1]], varstokeep)
  for permnocount in 1:ceil(length(mergedDF)/span)
      print(permnocount)
    # First DF in the span
    flatDF = flattenDF(mergedDF[collect(keys(mergedDF))[kstart]], varstokeep)
    # All following permnos in the span
    for permno in collect(keys(mergedDF))[kstart+1:kend]
      if size(mergedDF[permno],1)>0
        crtflatDF = flattenDF(mergedDF[permno], varstokeep)
        for var in varstokeep
          try
            flatDF[var] = vcat(flatDF[var], crtflatDF[var])
          catch
            print("$(flatDF) - $permno \n")
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
@save "/run/media/nicolas/Research/Data/temp/mergedDF.jld2" finalDF

a = finalDF[varstokeep[1]]
for vname in varstokeep[2:end]
  a = hcat(a, finalDF[vname])
end
a = DataFrames.DataFrame(a)
names!(a, varstokeep)
CSV.write("/run/media/nicolas/OtherData/home/home/nicolas/Data/Input data/june1973dec2017_detrend.csv", a)

a = CSV.read("/home/nicolas/Data/Input data/june1972dec2017.csv")
kdates = Set(a[:CRSPDATE])

@load "/run/media/nicolas/Research/Data/temp/FFratios1972filtered.jld2" mergedDF
