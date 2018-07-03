using CSV, FileIO, TSfunctions, nanHandling, DataFrames, Missings, functionsCRSP
data = CSV.read("/home/nicolas/Data/raw_CRSP_CS_merg_monthly_1970_2015.csv")
data[:DATE] = map(string, data[:DATE])
data[:DATE] = Date(data[:DATE],"yyyymmdd")
FF = CSV.read("/home/nicolas/Data/FF/FF_Factors.CSV")
RF = FF[:RF]

datarootpath = "/home/nicolas/Data"
tFrequence = Dates.Month(1)
dates = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["dates"]
keptrows = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["keptrows"]
dates = dates[keptrows]
weightmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,3]
PERMNOs = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["PERMNOs"]
PERMNOs = [parse(Int64,string(x)[1:end-2]) for x in PERMNOs[2:end]]
sortedPRMNOs = sortedMapWithIdx(PERMNOs)

chosenDates = DateTime(1970,2,1):Dates.Month(1):DateTime(2016,7,1)
for date in chosenDates
  elem = data[(data[:DATE].<=date)&(data[:DATE].>date-Dates.Month(1)),:]
end
