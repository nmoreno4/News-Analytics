using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2,
      TSmap, Plots, CSV, TrendCycle, Misc

iArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
RetMat = gatherData((1,3776), ["permno", "date", "retadj", "me"], iArrays)

# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/Ret_FF_all_3.jld2" RetMat
# @time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_FF_all_3.jld2" NSMat
