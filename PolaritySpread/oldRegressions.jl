using RCall, JLD2, Statistics, StatsBase, DataFramesMeta, NaNMath, RCall, CSV, DataFrames
JLD2.@load "/home/nicolas/Data/finalSeriesDic.jld2"
R"finalresults <- list()"

for freq in [60,20,10,5,1]
    offset = 1
    if freq==1
        offset=0
    end
    resDF = finalSeriesDic["res_p$(freq)_o$(offset)"]
    resDF[:Hval_Mkt] = resDF[:HvalVW] - resDF[:Mkt_RF]
    z = finalSeriesDic["res_p$(freq)_o$(offset)"][:VWsent_HML]
    zm = hcat(finalSeriesDic["res_p$(freq)_o$(offset)"][:Mkt_RF], finalSeriesDic["res_p$(freq)_o$(offset)"][:SMB],
                    finalSeriesDic["res_p$(freq)_o$(offset)"][:HML], finalSeriesDic["res_p$(freq)_o$(offset)"][:Mom],
                    finalSeriesDic["res_p$(freq)_o$(offset)"][:VWsent_H], finalSeriesDic["res_p$(freq)_o$(offset)"][:VWsent_HML])
    R"library(gmm)"
    R"library(dynlm)"
    @rput z
    @rput zm
    @rput resDF
    @rput freq
    # R"zm <- as.matrix(zm)"
    # R"z <- as.matrix(z)"
    # R"res <- gmm(z~zm,x=zm)"
    # R"summary(res)"
    R"lend = dim(resDF)[1]"
    R"finalresults[[$freq]] = lm(HvalVW[5:lend] ~ Mkt_RF[5:lend] + HML[5:lend] + SMB[5:lend] + Mom[5:lend]
                    + VWsent_H[5:lend] + VWsent_HML[5:lend]
                    + VWsent_H[4:(lend-1)] + VWsent_HML[4:(lend-1)]
                    + VWsent_H[3:(lend-2)] + VWsent_HML[3:(lend-2)]
                    + VWsent_H[2:(lend-3)] + VWsent_HML[2:(lend-3)]
                    + VWsent_H[1:(lend-4)] + VWsent_HML[1:(lend-4)], data=resDF)";
    R"summary(ols.reg)"
end
R"library(stargazer)"
R"stargazer(finalresults[[60]], finalresults[[20]], finalresults[[10]],
            finalresults[[5]], finalresults[[1]], type = 'latex', report=('vc*t'),
            no.space=TRUE)"
