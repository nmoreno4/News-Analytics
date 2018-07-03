#This code is a bit clumsy and could need to be uplifted a bit.
using JLD2, FileIO, nanHandling, DataFrames, CSV

Specification = [("ptf_2by3_size_value", "HH"), ("ptf_2by3_size_value", "LH")]
rootpath = "/home/nicolas/CodeGood"
datarootpath = "/home/nicolas/Data"

finalMat = DataFrame()

factor = Specification[1][1]
quintile = Specification[1][2]
for spec in Specification
  factor = spec[1]
  quintile = spec[2]
  dates = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["dates"]
  keptrows = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["keptrows"]
  dates = dates[keptrows]
  #load labels of whole datframe (i.e. symbols, among which is date)
  PERMNOs = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["PERMNOs"]
  PERMNOs = [parse(Int64,string(x)[1:end-2]) for x in PERMNOs[2:end]]
  retmat = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["mat"][:,:,1]
  weightmat = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["mat"][:,:,3]

  CF_DR_raw = CSV.read("$rootpath/Data Inputs/firm_CFDR_news.csv")
  CF_DR_raw[:DATE] = map(string, CF_DR_raw[:DATE])
  CF_DR_raw[:DATE] = Date(CF_DR_raw[:DATE],"yyyymm")

  Dpermnos = collect(Set(CF_DR_raw[:PERMNO]))

  noCRSPdata, nbNoCFDRnews, avgCF, avgDR = [], [], [], []
  tic()
  for row in 1:size(retmat, 1)
    if row>1
      provDF = CF_DR_raw[(CF_DR_raw[:DATE].<dates[row])&(CF_DR_raw[:DATE].>dates[row-1]),:]
    else
      provDF = CF_DR_raw[(CF_DR_raw[:DATE].<dates[row]),:]
    end #If first date
    matchIdx = collect(1:length(PERMNOs))
    deleteat!(matchIdx, nanindex(retmat[row,:]))
    crtPERMNOs = PERMNOs[matchIdx]
    rowIdxs = []
    todelete = []
    i=0
    for permno in crtPERMNOs
      i+=1 # to find the permnos for which I have no data
      # find the row numbers of the CF and DR news between the dates for the given permno
      frow = find(x->(x==permno), provDF[:PERMNO])
      if length(frow)>0 #if I found a matching data
        push!(rowIdxs, frow[1])
        naDF = provDF[(provDF[:PERMNO].==permno)&(isnan(provDF[:news_DR])),:]
        # print(size(naDF, 1)-length(frow))
        # print("\n")
        if size(naDF,1)==length(frow)
          # print(size(naDF))
          # print(rowIdxs)
          # print(permno)
          # print(dates[row])
          push!(todelete, i)
        end
      else
        push!(todelete, i)
      end
    end #for crtPERMNOs
    wMatchIdx = deleteat!(copy(matchIdx), todelete)
    print("$(length(wMatchIdx)) - $(length(matchIdx))")
    # Check the percentage of permnos for which I have no data
    push!(noCRSPdata, (length(crtPERMNOs)-length(rowIdxs))/length(crtPERMNOs))
    crtCF, crtDR, NAcrtCF, NAcrtDR = [], [], [], []
    for idx in rowIdxs
      if isnan(provDF[:news_CF][idx]) && isnan(provDF[:news_DR][idx])
        push!(NAcrtCF, provDF[:news_CF][idx])
        push!(NAcrtDR, provDF[:news_DR][idx])
      elseif !(isnan(provDF[:news_CF][idx])) && !(isnan(provDF[:news_DR][idx]))
        push!(crtCF, provDF[:news_CF][idx])
        push!(crtDR, provDF[:news_DR][idx])
      else
        print("shit")
      end
    end
    if length(crtCF)==length(wMatchIdx)
      print("\na: $(length(NAcrtCF))\n")
    else
      print("\nb: $(length(NAcrtCF))\n")
    end
    push!(nbNoCFDRnews, length(NAcrtDR)/length(rowIdxs))
    wVec = weightmat[row,:][wMatchIdx]./sum(weightmat[row,:][wMatchIdx])
    length(wVec)
    if length(crtCF)==0
      print("No news: $(row)\n")
    else
      print(length(crtCF))
      print(length(wVec))
      push!(avgCF, sum(crtCF.*wVec))
      push!(avgDR, sum(crtDR.*wVec))
    end
  end #for row
  toc()
  finalMat[Symbol("news_CF_$(factor)_$(quintile)")] = avgCF
  finalMat[Symbol("news_DR_$(factor)_$(quintile)")] = avgDR
end

CSV.write("$(datarootpath)/news_CF_DR.csv", finalMat, header = true, delim =';')


using Plots
plotlyjs()
plot(dates[2:156],finalMat[:news_CF_HML_H][2:156])
plot!(dates[2:156],finalMat[:news_DR_HML_H][2:156])
plot!(dates[2:156],finalMat[:news_CF_HML_L][2:156])
plot!(dates[2:156],finalMat[:news_DR_HML_L][2:156])
