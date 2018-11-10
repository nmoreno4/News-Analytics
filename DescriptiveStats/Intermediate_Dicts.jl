##################################################################
# Load data
##################################################################
using JLD2, DataFrames, Dates

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")


################# Block 1A ############################################
# a/ Compute the sensitivity of each ptf to NS(HML)
# b/ Compute the sensitivity of each ptf to NS(HML), only for returns
#    and sentiments falling around an EAD.
# - Use always the 2x3 HML sentiment
# - Use 10x10, 5x5 and 2x3 portfolio returns
#######################################################################

JLD2.@load "/run/media/nicolas/Research/SummaryStats/HMLDic.jld2"
ptf2x3 = @time HMLspread(HMLDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false)
ptf2x3EAD = @time HMLspread(HMLDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true)
ptf2x3 = keepSeriesOnly!(ptf2x3)
ptf2x3EAD = keepSeriesOnly!(ptf2x3EAD)
ptf2x3 = HMLspread!(ptf2x3)
ptf2x3EAD = HMLspread!(ptf2x3EAD)
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf2x3.jld2" ptf2x3
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf2x3EAD.jld2" ptf2x3EAD

JLD2.@load "/run/media/nicolas/Research/SummaryStats/bmszdecile.jld2"
specs10x10 = specsids(10)
ptf10x10 = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false, specs10x10)
ptf10x10EAD = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true, specs10x10)
ptf10x10 = keepSeriesOnly!(ptf10x10)
ptf10x10EAD = keepSeriesOnly!(ptf10x10EAD)
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf10x10.jld2" ptf10x10
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf10x10EAD.jld2" ptf10x10EAD

JLD2.@load "/run/media/nicolas/Research/SummaryStats/quintileDic.jld2"
specs5x5 = specsids(5)
ptf5x5 = @time HMLspread(quintileDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false, specs5x5)
ptf5x5EAD = @time HMLspread(quintileDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true, specs5x5)
ptf5x5 = keepSeriesOnly!(ptf5x5)
ptf5x5EAD = keepSeriesOnly!(ptf5x5EAD)
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf5x5.jld2" ptf5x5
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptf5x5EAD.jld2" ptf5x5EAD

JLD2.@load "/run/media/nicolas/Research/SummaryStats/MktDic.jld2"
ptfMkt = @time HMLspread(MktDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false, ([(1,10), (1,10)]))
ptfMktEAD = @time HMLspread(MktDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true, ([(1,10), (1,10)]))
ptfMkt = keepSeriesOnly!(ptfMkt)
ptfMktEAD = keepSeriesOnly!(ptfMktEAD)
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptfMkt.jld2" ptfMkt
JLD2.@save "/run/media/nicolas/Research/SummaryStats/ptfMktEAD.jld2" ptfMktEAD





################# Block 2A ######################################################
# 1/ Filter for news falling around EAD (0, -1:1 and -5:1)
# 2/ Filter for news NOT falling around those EAD (0, -1:1 and -5:1)
# 3/ Do the filter for both all news categories and only RES news
# 4/ Create double entry matrix (Size/BM) of either:
#       a) the sentiment level of the filtered data (compVec = 1)
#       b) the difference in sentiment  between opposing filters (1/ vs. 2/)
#       c) the number of news of the filtered data (news coverage) (compVec = 3)
#       d) the difference in news coverage between opposing filters (1/ vs. 2/)
#################################################################################
idmat = "quintileDic"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/quintileDic.jld2"
specs = specsids(5)
chosenSplit = quintileDic
filtEADmats = Dict()
for filttype in [(0, true), (0, false), (-1:1, true), (-1:1, false), (-5:1, true), (-5:1, false)]
    @time filtEADmats[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], filttype[1], filttype[2], specs)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/$(idmat)_filtEADmats.jld2" filtEADmats
print("EAD filters on ALL news applied")
print(Dates.format(now(), "HH:MM"))

filtEADmatsRES = Dict()
for filttype in [(0, true), (0, false), (-1:1, true), (-1:1, false), (-5:1, true), (-5:1, false)]
    @time filtEADmatsRES[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H_RES", "nbStories_rel100_nov24H_RES", [0,100], filttype[1], filttype[2], specs)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/$(idmat)_filtEADmatsRES.jld2" filtEADmatsRES
print("EAD filters on RES news applied")
print(Dates.format(now(), "HH:MM"))


################# Block 2B ######################################################
# 1/ Filter for news days where the AVG news polarity is between the following
#    ranges: [0perc, 20perc], Any, [80perc, 100perc], negative news days (<0)
# 2/ Do the filter for both ALL news categories and only RES news
# 3/ Apply the filter around EAD (-1:1) to see if there are differences ther too.
# 4/ Create double entry matrix (Size/BM) of either:
#       a) the sentiment level of the filtered data (compVec = 1)
#       b) the difference in sentiment  between opposing filters (1/ vs. 2/)
#       c) the number of news of the filtered data (news coverage) (compVec = 3)
#       d) the difference in news coverage between opposing filters (1/ vs. 2/)
#################################################################################
# idmat = "bmszdecile"
# @time JLD2.@load "/run/media/nicolas/Research/SummaryStats/$(idmat).jld2"
# chosenSplit = resDic

sentfilts = ([0,20], [0,100], [80,100], [-1,0])
filts1  = [([], false, x) for x in sentfilts]
filts2  = [(-1:1, false, x) for x in sentfilts]
filts = [filts1;filts2]

filtPolEADmats = Dict()
for filttype in filts
    @time filtPolEADmats[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H", "nbStories_rel100_nov24H", filttype[3], filttype[1], filttype[2], specs)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/$(idmat)_filtPolEADmats.jld2" filtPolEADmats
print("EAD and Pol filters on ALL news applied")
print(Dates.format(now(), "HH:MM"))

filtPolEADmatsRES = Dict()
for filttype in filts
    @time filtPolEADmatsRES[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H_RES", "nbStories_rel100_nov24H_RES", filttype[3], filttype[1], filttype[2], specs)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/$(idmat)_filtPolEADmatsRES.jld2" filtPolEADmatsRES
print("EAD and Pol filters on RES news applied")
print(Dates.format(now(), "HH:MM"))
