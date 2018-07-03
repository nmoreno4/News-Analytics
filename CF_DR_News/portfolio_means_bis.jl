using CSV, FileIO, TSfunctions, nanHandling, DataFrames, Missings, functionsCRSP
data = CSV.read("/home/nicolas/Data/raw_CRSP_CS_merg_monthly_1970_2015.csv")
data[:DATE] = map(string, data[:DATE])
data[:DATE] = Date(data[:DATE],"yyyymmdd")
for col in names(data)[2:end]
  if col in [:SMB, :HML, :ptf_2by3_size_value]
    data[ismissing.(data[col]), col] = "NA"
  else
    data[ismissing.(data[col]), col] = -9999
  end
end

datarootpath = "/home/nicolas/Data"
tFrequence = Dates.Month(1)
dates = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["dates"]
keptrows = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["keptrows"]
dates = dates[keptrows]
weightmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,3]
PERMNOs = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["PERMNOs"]
PERMNOs = [parse(Int64,string(x)[1:end-2]) for x in PERMNOs[2:end]]
sortedPRMNOs = sortedMapWithIdx(PERMNOs)
function findValueFromSorted(x, val)
  cc = 0
  for i in x[:,1]
    cc+=1
    if i == val
      break
    end
  end
  return x[cc,2]
end

finalMat = DataFrame()

portfolios = [5.1,5.2,5.3,5.4,5.5]#,2.1,2.2,2.3,2.4,2.5,3.1,3.2,3.3,3.4,3.5,4.1,4.2,4.3,4.4,4.5,5.1,5.2,5.3,5.4,5.5]

for ptf in portfolios
  print(ptf)
  ROEvw = []
  DEvw = []
  BEMEvw = []
  retadjvw = []
  ROEew = []
  DEew = []
  BEMEew = []
  retadjew = []
  for d in 1:162
    print(d)
    elem = data[(data[:ptf_5by5_size_value].==ptf)&(data[:DATE].<=dates[d])&(data[:DATE].>vcat(dates[1]-Dates.Month(1), dates)[d]),:]
    ROE = []
    DE = []
    BEME = []
    retadj = []
    wROE = []
    wDE = []
    wBEME = []
    wretadj = []
    for row in 1:size(elem,1)
      if elem[row,:][:ptf_5by5_size_value][1]==ptf
        wcol = findValueFromSorted(sortedPRMNOs, elem[row,:][:PERMNO][1])
        crtweight = weightmat[d, wcol]
        if elem[row,:][:ROE][1] != -9999
          push!(ROE, elem[row,:][:ROE][1])
          push!(wROE, crtweight)
        end
        if elem[row,:][:retadj][1] != -9999
          push!(retadj, elem[row,:][:retadj][1])
          push!(wretadj, crtweight)
        end
        if elem[row,:][:DE_RATIO][1] != -9999
          push!(DE, elem[row,:][:DE_RATIO][1])
          push!(wDE, crtweight)
        end
        if elem[row,:][:BEME][1] != -9999
          push!(BEME, elem[row,:][:BEME][1])
          push!(wBEME, crtweight)
        end
      end
    end
    ROEw = wROE/nansum(wROE)
    push!(ROEvw, nansum(ROEw.*ROE))
    push!(ROEew, nanmean(ROE))
    DEw = wDE/nansum(wDE)
    push!(DEvw, nansum(DEw.*DE))
    push!(DEew, nanmean(DE))
    BEMEw = wBEME/nansum(wBEME)
    push!(BEMEvw, nansum(BEMEw.*BEME))
    push!(BEMEew, nanmean(BEME))
    retadjw = wretadj/nansum(wretadj)
    push!(retadjvw, nansum(retadjw.*retadj))
    push!(retadjew, nanmean(retadj))
  end
  finalMat[Symbol("ROE_VW_$(ptf)")] = ROEvw
  finalMat[Symbol("ROE_EW_$(ptf)")] = ROEew
  finalMat[Symbol("DE_VW_$(ptf)")] = DEvw
  finalMat[Symbol("DE_EW_$(ptf)")] = DEew
  finalMat[Symbol("BEME_VW_$(ptf)")] = BEMEvw
  finalMat[Symbol("BEME_EW_$(ptf)")] = BEMEew
  finalMat[Symbol("retadj_VW_$(ptf)")] = retadjvw
  finalMat[Symbol("retadj_EW_$(ptf)")] = retadjew
end
CSV.write("/home/nicolas/Data/variable_means_$(portfolios).csv", finalMat, header = true, delim =';')
