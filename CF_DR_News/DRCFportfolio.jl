args = ["local", "ptf_2by3_size_value", "1"]
args = map(x->x, ARGS)
if args[1]=="CECI"
  push!(LOAD_PATH, "/CECI/home/ulg/affe/nmoreno/CodeGood/RelVGnews/myModules")
end
using helperFunctions
rootpath, datarootpath, logpath = loadPaths(args[1])
using JLD2, FileIO, nanHandling, CSV, dataframeFunctions, DataFrames, Stats, TSfunctions

Specification = defineSpec(args[2], args[3])
tFrequence = Dates.Month(1)

finalMat = DataFrame()

factor = Specification[1][1]
quintile = Specification[1][2]

bizarre = []

permNO_to_permID = FileIO.load("$rootpath/permnoToPermId.jld2")["mappingDict"]
PERMNOs = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["PERMNOs"]
weightmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,3]
PERMNOs = [parse(Int64,string(x)[1:end-2]) for x in PERMNOs[2:end]]
dates = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["dates"]
keptrows = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["keptrows"]
dates = dates[keptrows]
retmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,1]
volmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,4]

for spec in Specification
  print("============================== $spec =====================================")
  factor = spec[1]
  quintile = spec[2]

  if quintile == ["H","M","L"]
    # JLD2.@load "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/AllStocks.jld2" sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat #volumeMat
    JLD2.@load "$datarootpath/CRSP/$tFrequence/AllStocks.jld2" chosenIdx
  else
    # JLD2.@load "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/$(factor)_$(quintile).jld2" sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat #volumeMat
    JLD2.@load "$datarootpath/CRSP/$tFrequence/$(factor)_$(quintile).jld2" chosenIdx
  end

  x = []
  for d in 1:length(dates)
    crtdate =[]
    sId = 0
    for stock in chosenIdx[1]
      sId+=1
      if d in stock
        push!(crtdate, sId)
      end
    end #for stock
    push!(x,crtdate)
  end

  CF_DR_raw = CSV.read("$datarootpath/CF DR News/report_1970news.csv", header = true, delim =',')
  CF_DR_raw[:DATE] = map(string, CF_DR_raw[:DATE])
  CF_DR_raw[:DATE] = Date(CF_DR_raw[:DATE],"yyyymm")

  Dpermnos = collect(Set(CF_DR_raw[:PERMNO]))

  CF_mat, DR_mat = createDateLabelDF(PERMNOs, dates), createDateLabelDF(PERMNOs, dates)

  nbData = Float64[]
  # Go over all unique companies for which we have CF and DR news
  cAdv = 0
  for permno in Dpermnos
    cAdv+=1
    print("$cAdv \n")
    # Keep all lines matching the PERMNO
    provDF = CF_DR_raw[(CF_DR_raw[:PERMNO].==permno),:]
    # Go over all dates for returns
    for d in 1:length(dates)
      # find all stocks in x for which I have a return on that date
      crtStocks = PERMNOs[nanindex(retmat[d,x[d]], true)]
      if permno in crtStocks
        elem = provDF[(provDF[:DATE].<dates[d])&(provDF[:DATE].>vcat(dates[1]-Dates.Month(1), dates)[d]),:]
        if size(elem,1)>0
          if elem[:news_CF][1]<100 || elem[:news_CF][1]>-100
            CF_mat[CF_mat[:Date].==dates[d], Symbol(permno)] = elem[:news_CF][1]
            DR_mat[DR_mat[:Date].==dates[d], Symbol(permno)] = elem[:news_DR][1]
          else
            push!(bizarre, (elem[:news_CF], elem[:news_DR], permno, dates[d]))
          end
        end
      end #if the stock is part of the desired portfolio
    end #for dates
    push!(nbData, size(provDF,1))
  end #for permno

  finalMat[Symbol("CF_EW_$(factor)_$(quintile)")] = avgNaNmat(df_to_array(CF_mat, 1:size(CF_mat,1), 2:size(CF_mat,2)))
  finalMat[Symbol("CF_VW_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(weightmat).*df_to_array(CF_mat, 1:size(CF_mat,1), 2:size(CF_mat,2)))
  finalMat[Symbol("DR_EW_$(factor)_$(quintile)")] = avgNaNmat(df_to_array(DR_mat, 1:size(DR_mat,1), 2:size(DR_mat,2)))
  finalMat[Symbol("DR_VW_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(weightmat).*df_to_array(DR_mat, 1:size(DR_mat,1), 2:size(DR_mat,2)))
end
CSV.write("$(datarootpath)/news_CF_DR_$(Specification).csv", finalMat, header = true, delim =';')
# finalMat[Symbol("Date")] = dates
#
# using Plots
# plotlyjs()
# plot(finalMat[Symbol("DR_EW_$(factor)_$(quintile)")])
# plot(finalMat[:CF_VW_HML_H]-finalMat[:CF_VW_HML_L])
#
# cor(finalMat[:CF_VW_HML_H][1:156], finalMat[:DR_VW_HML_H][1:156])
