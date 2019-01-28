using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2, Windsorize,
      TSmap, Plots, CSV, TrendCycle, Misc, FindFcts, DataStructures, ShiftedArrays,
      RegressionTables, FixedEffectModels, FixedEffects, CovarianceMatrices, RDatasets,
      HypothesisTests

@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_ALL.jld2"
NSMat = NSMat["ALL"][NSMat["ALL"][:date].>=Dates.Date(2013,1,1),:]
ALL = [:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0]
RES = [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0]
RESF = [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0]

WS = "VW"
newsTopics = (RESF,RES)
# add the possibility to use the me in t-3
NSMat[:dailyRebal] = @time rebalPeriods(NSMat, :date; everyday=true )
NSMat[:driftW] = @time everyDayWeights(NSMat, WS)
LTspan, STspan = Dates.Month(2), Dates.Day(3)
LT2ST3 = @time NSsuprise(NSMat, LTspan,  STspan, 1,1,"EAD", newsTopics)
