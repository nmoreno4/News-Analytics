args = ["local", "all", "6"]

using helperFunctions
rootpath, datarootpath, logpath = loadPaths(args[1])
using JLD2, FileIO, nanHandling, CSV, dataframeFunctions, DataFrames, Stats, TSfunctions

Specification = [("ptf_2by3_size_value", "HH"), ("ptf_2by3_size_value", "LH")]
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
