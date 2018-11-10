using JLD2, Dates, Plots, GLM, DataFrames, RegressionTables, PlotThemes
using Plots.PlotMeasures
theme(:solarized_light)

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")


################# Block 1A ############################################
# a/ Compute the sensitivity of each ptf to NS(HML)
# b/ Compute the sensitivity of each ptf to NS(HML), only for returns
#    and sentiments falling around an EAD.
# - Use always the 2x3 HML sentiment
# - Use 10x10, 5x5 and 2x3 portfolio returns
#######################################################################

JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf2x3.jld2"
JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf2x3EAD.jld2"
JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf10x10.jld2"
JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf10x10EAD.jld2"
JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf5x5.jld2"
JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptf5x5EAD.jld2"
# JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptfMkt.jld2"
# JLD2.@load "/run/media/nicolas/Research/SummaryStats/ptfMktEAD.jld2"


βmat = ones(10,10)
# regtable(ols; renderSettings = asciiOutput(), below_statistic=:tstat)
for val in 1:10
    for sz in 1:10
        data = DataFrame(A = ptf10x10[val*100+sz]["VWret"], B = ptf2x3["HMLsent"])
        ols = lm(@formula(A ~ B), data)
        tstats = coeftable(ols).cols[3]
        βmat[val,sz] = tstats[2]
    end
end
βmatsq = βmat .* βmat
theme(:solarized)
gr()
p = heatmap(βmat, show = true, gridlinewidth=50, tickfontsize=30, titlefontsize=30, guidefontsize = 30, xtickfont = font(16, "Courier"), size=(1200,1200), title="hello", xlabel="Size", ylabel="Value")
print(mean(βmat))
print(mean(βmatsq))
savefig(p,"/home/nicolas/myplot7.png")




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
#quintileDic, bmszdecile
JLD2.@load "/run/media/nicolas/Research/SummaryStats/quintileDic_filtPolEADmats.jld2"
# | VWsent | EWsent | nb of stories in ptf at date (with filter) | nb of stocks in ptf at date (no filter)
# | nb of stocks with news at date (with filter) | nb of stocks in ptf at date (with filter)
specs = specsids(5)

filtpairs = [[(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]
# filtpairs = [[(0, true), (0, false)], [(-1:1, true), (-1:1, false)], [(-5:1, true), (-5:1, false)], [(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]

sentfilts = ([0,100], [0,20], [80,100], [-1,0])
filts1  = [([], false, x) for x in sentfilts]
filts2  = [(-1:1, false, x) for x in sentfilts]
filts = [filts1;filts2]
filtpairs1 = [(filts[i], filts[1]) for i in 2:4]
filtpairs2 = [(filts[i], filts[5]) for i in 6:8]
filtpairs = [filtpairs1;filtpairs2]
a = []
pyplot()
let i=0
for filtpair in filtpairs
    i+=1
    # filtPolEADmats[0] = 0
    amat = valszCondMeanEAD(filtPolEADmats[filtpair[1]], filtPolEADmats[filtpair[2]], specs, [3,3])
    p = heatmap(amat,  clim=(0.02:0.3), titlefontcolor=:red, colorbar_title="diff sent", color=:coolwarm, margin=10mm, tickfontsize=15, titlefontsize=15, guidefontsize = 15, xtickfont = font(15, "Courier"), size=(1200,1200), title="hello", xlabel="Size", ylabel="Value")
    savefig(p,"/home/nicolas/relcov$(i)_$(filtpair).png")
    push!(a, amat)
end
end

myrounding =x->round(x;digits=2)
X = myrounding.(a[1])
colname = ["S$(x)" for x in 1:10]
rowname = ["V$(x)" for x in 1:10]
@rput X; @rput rowname; @rput colname
R"library(Hmisc)"
R"res = as.data.frame(X)"
R"colnames(res) <-colname"
R"rownames(res) <-rowname"
R"res = latex(res, file='')"
@rget res



# Do proper differnces
# Do quintiles
# Compute t-stats
# Compute Patton timmermann
R"library(monotonicity)"
R"monoRelation(X)"
