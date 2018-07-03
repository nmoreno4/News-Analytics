#+ Add Offer an option to do a weighting as a function of the decay
args = ["local", "ptf_5by5_size_value", "1"]
args = map(x->x, ARGS)
push!(LOAD_PATH, "$(pwd())/RelVGnews/myModules")

using helperFunctions
rootpath, datarootpath, logpath = loadPaths(args[1])
using JLD2, FileIO, CSV, nanHandling, Plots, TSfunctions, DataFrames, GLM, helperFunctions

datarootpath = "/run/media/nicolas/OtherData/home/home/nicolas/Data"
rootpath = "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/Data Inputs"
Specification = defineSpec(args[2], args[3])

decayParam = 1
newness = 5
printcol = 100
excludeDays = Dates.Day(0)
offsetexcludeDays = Dates.Month(0)
tFrequence = Dates.Month(1)
pastRollWindow = Dates.Year(0)
minPeriodInterval = Dates.Day(25)
repetFilter = (true, 2)
storyAVG = true

finalMat = DataFrame()
factor = Specification[1][1]
quintile = Specification[1][2]
permNO_to_permID = FileIO.load("$rootpath/permnoToPermId.jld2")["mappingDict"]
weightmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,3]
retmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,1]
volmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,4]
dates = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["dates"]
keptrows = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["keptrows"]
dates = dates[keptrows]
finalMat[:Date] = dates

#5by5 : 1.1, 5.1
#10by10 : 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 2, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.0, 4.2, 4.3, 4.4, 5.0, 5.1, 5.2, 5.3, 6.0, 7.0, 7.1, 8.0, 8.1, 9.0, 9.1
spec=Specification[1]
for spec in Specification
  factor = spec[1]
  quintile = spec[2]

  if quintile == ["H","M","L"]
    JLD2.@load "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/AllStocks.jld2" sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat posMat negMat neutMat #volumeMat
    JLD2.@load "$datarootpath/CRSP/$tFrequence/AllStocks.jld2" chosenIdx
  else
    JLD2.@load "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/$(factor)_$(quintile).jld2" sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat posMat negMat neutMat #volumeMat
    JLD2.@load "$datarootpath/CRSP/$tFrequence/$(factor)_$(quintile).jld2" chosenIdx
  end

  finalWmat=Array{Float64}(size(retmat))*0
  alldesiredCols=[]
  for row in 1:size(diffPosNegRel,1)
    desiredCols = concernedStocks(row, chosenIdx[1])
    push!(alldesiredCols, desiredCols)
    totalMarketCap = nansum(weightmat[row, desiredCols])
    finalWmat[row, desiredCols] = weightmat[row, desiredCols]./totalMarketCap
  end

  finalMat[Symbol("EW_ret_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, retmat, "EW")
  finalMat[Symbol("VW_ret_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, retmat, "VW")
  # finalMat[Symbol("NVW_ret_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*retmat[:, :])
  finalMat[Symbol("EW_vol_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, volmat, "EW")
  finalMat[Symbol("VW_vol_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, volmat, "VW")
  # finalMat[Symbol("NVW_vol_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*volmat[:, :])
  finalMat[Symbol("EW_sentClas_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, sentClasMat, "EW")
  finalMat[Symbol("VW_sentClas_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, sentClasMat, "VW")
  # finalMat[Symbol("NVW_sentClas_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*sentClasMat[:, :])
  finalMat[Symbol("EW_sentClasRel_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, sentClasMatRel, "EW")
  finalMat[Symbol("VW_sentClasRel_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, sentClasMatRel, "VW")
  # finalMat[Symbol("NVW_sentClasRel_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*sentClasMatRel[:, :])
  finalMat[Symbol("EW_diffPosNeg_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, diffPosNeg, "EW")
  finalMat[Symbol("VW_diffPosNeg_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, diffPosNeg, "VW")
  # finalMat[Symbol("NVW_diffPosNeg_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*diffPosNeg[:, :])
  finalMat[Symbol("EW_diffPosNegRel_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, diffPosNegRel, "EW")
  finalMat[Symbol("VW_diffPosNegRel_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, diffPosNegRel, "VW")
  # finalMat[Symbol("NVW_diffPosNegRel_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*diffPosNegRel[:, :])
  finalMat[Symbol("EW_novelty_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, noveltyMat, "EW")
  finalMat[Symbol("VW_novelty_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, noveltyMat, "VW")
  # finalMat[Symbol("NVW_novelty_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*noveltyMat[:, :])
  finalMat[Symbol("EW_pos_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, posMat, "EW")
  finalMat[Symbol("VW_pos_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, posMat, "VW")
  # finalMat[Symbol("NVW_novelty_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*noveltyMat[:, :])
  finalMat[Symbol("EW_neg_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, negMat, "EW")
  finalMat[Symbol("VW_neg_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, negMat, "VW")
  # finalMat[Symbol("NVW_novelty_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*noveltyMat[:, :])
  finalMat[Symbol("EW_neut_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, neutMat, "EW")
  finalMat[Symbol("VW_neut_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, neutMat, "VW")
  # finalMat[Symbol("NVW_novelty_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*noveltyMat[:, :])
  finalMat[Symbol("EW_count_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, storiesCountMat, "EW")
  finalMat[Symbol("VW_count_$(factor)_$(quintile)")] = averagePeriod(finalWmat, alldesiredCols, storiesCountMat, "VW")
  # finalMat[Symbol("NVW_novelty_$(factor)_$(quintile)")] = nansum(monthlyDriftWeight(newsVolumeMat).*noveltyMat[:, :])
end #for spec

using RCall
a = finalMat[Symbol("VW_novelty_$(factor)_HH")]
b = finalMat[Symbol("VW_novelty_$(factor)_LH")]
c = finalMat[Symbol("VW_novelty_$(factor)_HL")]
d = finalMat[Symbol("VW_novelty_$(factor)_LL")]
h = finalMat[Symbol("VW_novelty_$(factor)_5.1")]
i = finalMat[Symbol("VW_novelty_$(factor)_5.2")]
j = finalMat[Symbol("VW_novelty_$(factor)_5.3")]
k = finalMat[Symbol("VW_novelty_$(factor)_5.4")]
l = finalMat[Symbol("VW_novelty_$(factor)_5.5")]
a = finalMat[Symbol("VW_vol_$(factor)_HH")]
b = finalMat[Symbol("VW_vol_$(factor)_LH")]
c = finalMat[Symbol("VW_vol_$(factor)_HL")]
d = finalMat[Symbol("VW_vol_$(factor)_LL")]
h = finalMat[Symbol("VW_vol_$(factor)_5.1")]
i = finalMat[Symbol("VW_vol_$(factor)_5.2")]
j = finalMat[Symbol("VW_vol_$(factor)_5.3")]
k = finalMat[Symbol("VW_vol_$(factor)_5.4")]
l = finalMat[Symbol("VW_vol_$(factor)_5.5")]
a = finalMat[Symbol("VW_sentClas_$(factor)_HH")]
b = finalMat[Symbol("VW_sentClas_$(factor)_LH")]
c = finalMat[Symbol("VW_sentClas_$(factor)_HL")]
d = finalMat[Symbol("VW_sentClas_$(factor)_LL")]
h = finalMat[Symbol("VW_sentClas_$(factor)_5.1")]
i = finalMat[Symbol("VW_sentClas_$(factor)_5.2")]
j = finalMat[Symbol("VW_sentClas_$(factor)_5.3")]
k = finalMat[Symbol("VW_sentClas_$(factor)_5.4")]
l = finalMat[Symbol("VW_sentClas_$(factor)_5.5")]
a = finalMat[Symbol("EW_count_$(factor)_HH")]
b = finalMat[Symbol("EW_count_$(factor)_LH")]
c = finalMat[Symbol("EW_count_$(factor)_HL")]
d = finalMat[Symbol("EW_count_$(factor)_LL")]
h = finalMat[Symbol("EW_count_$(factor)_5.1")]
i = finalMat[Symbol("EW_count_$(factor)_5.2")]
j = finalMat[Symbol("EW_count_$(factor)_5.3")]
k = finalMat[Symbol("EW_count_$(factor)_5.4")]
l = finalMat[Symbol("EW_count_$(factor)_5.5")]
mean([mean(h), mean(i), mean(j), mean(k), mean(l)])
mean(h)
mean(i)
mean(j)
mean(k)
nanmean(l)
mean([mean(c), mean(d)])
mean([mean(a), mean(b)])
mean([mean(c[1:60]), mean(d[1:60])])
mean([mean(a[1:60]), mean(b[1:60])])
mean([mean(c[60:75]), mean(d[60:75])])
mean([mean(a[60:75]), mean(b[60:75])])
mean([mean(c[75:164]), mean(d[75:164])])
mean([mean(a[75:164]), mean(b[75:164])])
e = mean(hcat(a,b),2)[1:163]
f = mean(hcat(c,d),2)[1:163]
@rput a
@rput b
@rput c
@rput d
@rput e
@rput f
Date = dates[1:163]
@rput Date
R"plot(a, type='l')"
R"lines(b, col=2)"
R"lines(c, col=3)"
R"lines(d, col=4)"
R"plot(e ~ Date, type='l', ylab='Polarity', lwd=2, cex.lab=2, cex.axis=2, cex.main=2, cex.sub=2, col = 4, ylim=c(-0.05, 0.2))"
R"lines(f ~ Date, col=2, lwd=2)"
R"legend('topleft', c('Value polarity', 'Growth Polarity'), col=c(4,2), lty = c(1,1), lwd=c(2,2))"
R"title('Sentiment index', cex.lab=2, cex.axis=1.3, cex.main=2, cex.sub=2)"
R"t.test(e,f)"

mkpath("$datarootpath/News Analytics Series/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)")
CSV.write("$datarootpath/News Analytics Series/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/$(args[2])_$(args[3]).csv", finalMat, header = true, delim =';')
print("Done!")

# FF = CSV.read("$datarootpath/FF/FF_Factors.CSV")[475:648,:]
# FF_5by5 = CSV.read("$datarootpath/FF/5by5_VW.csv")[475:648,:]
# data = hcat(FF, finalMat)[1:162,:]
#
# quintile="LH"
# FFp = "SMALL_HiBM"
# a = data[Symbol("VW_ret_$(factor)_$(quintile)")]
# plot(a-data[:RF]/100)
# plot!(data[Symbol(FFp)]/100)
# cor(a, data[Symbol(FFp)]/100)
# # plot(ret2tick(a-FF[:RF]/100,1))
# plot(ret2tick(a))
# plot!(ret2tick(data[Symbol(FFp)]/100,1))
#
# GLM.glm(@formula(VW_ret_ptf_2by3_size_value_HH ~ BIG_HiBM), data, Normal(), IdentityLink())
#
# for col in 2:size(FF,2)
#   FF[:,col] = FF[:,col]/100
# end
#
# a = []
# for i in 1:174
#   push!(a, mean([finalMat[Symbol("VW_ret_$(factor)_LH")][i], finalMat[Symbol("VW_ret_$(factor)_LL")][i]]))
# end

# finalMat = finalMat[:,2:end]
# plotlyjs()
# plot(ret2tick(finalMat[:VW_ret_HML_H]-finalMat[:VW_ret_HML_L]))
# plot(ret2tick(finalMat[:VW_ret_HML_H]))
# plot!(ret2tick(finalMat[:VW_ret_SMB_L]-finalMat[:VW_ret_HML_H]))
# plot!(ret2tick(finalMat[:VW_ret_Inv_L]-finalMat[:VW_ret_Inv_H]))
# plot!(ret2tick(finalMat[:VW_ret_OP_Prof_H]-finalMat[:VW_ret_OP_Prof_L]))
# plot!(ret2tick(finalMat[:VW_ret_Inv_H]-finalMat[:VW_ret_HInv_L]))
#
# factor = Specification[1][1]
# quintile = Specification[1][2]
# retmatA = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["mat"][:,:,1]
# datesA = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["dates"]
# keptrowsA = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["keptrows"]
# datesA = datesA[keptrowsA]
# sentClasMatA = FileIO.load("$rootpath/Data Inputs/TRNA_$(factor)_$(quintile).jld2")["sentClasMat"]
#
# factor = Specification[2][1]
# quintile = Specification[2][2]
# retmatB = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["mat"][:,:,1]
# datesB = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["dates"]
# keptrowsB = FileIO.load("$rootpath/Data Inputs/CRSP$(factor)_$(quintile).jld2")["keptrows"]
# datesB = datesB[keptrowsB]
# sentClasMatB = FileIO.load("$rootpath/Data Inputs/TRNA_$(factor)_$(quintile).jld2")["sentClasMat"]
#
# ATS = avgNaNmat(sentClasMatA)[1:156]
# BTS = avgNaNmat(sentClasMatB)[1:156]
# ArTS = avgNaNmat(retmatA)[1:156]
# BrTS = avgNaNmat(retmatB)[1:156]
#
# plotlyjs()
# plot(ret2tick(ArTS-BrTS, 100))
#
# data = DataFrame(ValSent=ATS, GrowthSent=BTS, ValRet=ArTS, GrowthRet=BrTS, retSpread=ArTS-BrTS, sentSpread = ATS-BTS)
# data = DataFrame(ValSent=finalMat[:,6], GrowthSent=finalMat[:,18], ValRet=finalMat[:,2], GrowthRet=finalMat[:,14], retSpread=finalMat[:,2]-finalMat[:,14], sentSpread = finalMat[:,6]-finalMat[:,18])
#
# OLS = glm(@formula(ValSent ~ sentSpread), data, Normal(), IdentityLink())
# print(OLS)
