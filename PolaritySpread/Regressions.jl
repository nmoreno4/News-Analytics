using PyCall, Statistics, StatsBase, DataFramesMeta, NaNMath, RCall, CSV, DataFrames, JLD2
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")
JLD2.@load "/home/nicolas/Data/finalSeriesDicBis.jld2"
JLD2.@load "/home/nicolas/Data/finalSeriesDic.jld2"
recentperiod = 2017

R"ResultsReg <- list()"

for comb in [(10,1), (5,1), (1,0)]
    @time Rmatrix = constructRmatrix(finalSeriesDicBis, comb[1], comb[2], finalSeriesDic,recentperiod)
    JLD2.@save "/home/nicolas/Data/Rmatrix$(comb[1]).jld2" Rmatrix
end


# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]

JLD2.@load "/home/nicolas/Data/Rmatrix20.jld2"
regressionSessionR(Rmatrix)

ptype = "H"
R"Htestformula = dynformula(
    ret_i_t ~ lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)
             +lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:1)
             +lag(HML, 0:1) + lag(SMB, 0:1) + lag(Mkt_RF, 0:1)
             +lag(RMW, 0:1) +lag(CMA, 0:1)
             |lag(ret_i_t, 1:50))";


function specifyRformula(ptf)
    @rput ptf
    R"testformula = dynformula(as.formula(paste(
        'ret_i_t ~ diff(sent_HML_t)+
                   lag(sent_', ptf, '_t)'
        , sep='')))"
end

function plm(ptf, freq, model, effect)
    R"reg <- plm(testformula, data=eval(parse(text=$ptf)), model=$model, effect=$effect)";
    R"print(summary(reg))";
    R"ResultsReg[[paste('plm', $ptf, $freq, $model, $effect, sep='_')]] = reg"
end


ptf = "H"
@rput ptf
R"Htestformula = dynformula(as.formula(paste('ret_i_t ~ diff(sent_HML_t)+lag(sent_', ptf, '_t)', sep='')))"
R"Htestformula = dynformula(as.formula(paste('ret_i_t ~ diff(sent_HML_t)', sep='')))"
R"Hreg <- plm(Htestformula, data=H, model='within', effect='individual')";
R"print(summary(Hreg))";
R"print(coeftest(Hreg, vcov=vcovHC(Hreg,type='HC4',cluster='group')))";

R"Htestformula = dynformula(
    ret_i_t ~ lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)
             +lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:1)
             +lag(HML, 0:1) + lag(SMB, 0:1) + lag(Mkt_RF, 0:1)
             +lag(RMW, 0:1) +lag(CMA, 0:1)
             |lag(ret_i_t, 1:50))";
@time R"Hreg <- pgmm(ret_i_t ~ lag(sent_HML_t, 0:1)+lag(sent_H_t, 0:1)+lag(sent_i_t, 0:1)
            +lag(RMW, 0:1)+lag(CMA, 0:1)+lag(HML, 0:1) + lag(SMB, 0:1) + lag(Mkt_RF, 0:1)
            |lag(ret_i_t, 1:5), data=H, effect='individual', robust=TRUE)";
R"print(coeftest(Hreg, vcov=vcovHC(Hreg,type='HC4',cluster='group')))";
R"print(summary(Hreg))";
R"Htestformula = dynformula(
    ret_i_t ~ lag(sent_HML_t, 0:3)*isRecent+lag(sent_H_t, 0:3)*isRecent
             +lag(sent_i_t, 0:3)*isRecent+lag(sent_Mkt_t, 0:3)*isRecent
             +lag(HML, 0:3) + lag(SMB, 0:3) + lag(Mkt_RF, 0:3)
             +lag(RMW, 0:3) +lag(CMA, 0:3))";
R"Ltestformula = dynformula(
    ret_i_t ~ lag(sent_HML_t, 0:3)*isRecent+lag(sent_L_t, 0:3)*isRecent
             +lag(sent_i_t, 0:3)*isRecent+lag(sent_Mkt_t, 0:3)*isRecent
             +lag(HML, 0:3) + lag(SMB, 0:3) + lag(Mkt_RF, 0:3)
             +lag(RMW, 0:3) +lag(CMA, 0:3))";
R"Atestformula = dynformula(
    ret_i_t ~ lag(sent_HML_t, 0:3)*isRecent
             +lag(sent_i_t, 0:3)*isRecent+lag(sent_Mkt_t, 0:3)*isRecent
             +lag(HML, 0:3) + lag(SMB, 0:3) + lag(Mkt_RF, 0:3)
             +lag(RMW, 0:3) +lag(CMA, 0:3))";
R"pooltest(Htestformula, data=H, model='within')"
R"pooltest(Atestformula, data=A, model='pooling')"
R"pooltest(Ltestformula, data=L, model='within')"
R"Hreg <- plm(Htestformula, data=H, model='within')"
R"print(summary(Hreg))";
R"print(coeftest(Hreg, vcov=vcovHC(Hreg,type='HC0',cluster='group')))";
# R"print(stargazer(coeftest(Hreg, vcov=vcovHC(H,type='HC0',cluster='group'))))";
R"Lreg <- plm(Ltestformula, data=L, model='within')"
R"print(summary(Lreg))";
R"print(coeftest(Lreg, vcov=vcovHC(Lreg,type='HC0',cluster='group')))";
# R"print(stargazer(Lreg))";

Hmatrix =  Rmatrix[Rmatrix[:isH] .== 1.0, :];
Lmatrix =  Rmatrix[Rmatrix[:isL] .== 1.0, :];
@rput Rmatrix
@rput Hmatrix
@rput Lmatrix
# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]
R"library(plm)"
R"A <- plm::pdata.frame(Rmatrix, index=c('permno', 'td'))";
R"H <- plm::pdata.frame(Hmatrix, index=c('permno', 'td'))";
R"L <- plm::pdata.frame(Lmatrix, index=c('permno', 'td'))";
# R"reg = plm::plm(ret_i_t ~  lag(sent_L_t,0) + lag(sent_L_t,1) + lag(sent_L_t,2) + lag(sent_L_t,3) + lag(sent_L_t,4) + lag(sent_L_t,5) + lag(sent_L_t,6) + lag(sent_L_t,13) + lag(sent_L_t,7) + lag(sent_L_t,8) + lag(sent_L_t,9) + lag(sent_L_t,10) + lag(sent_L_t,11) + lag(sent_L_t,12)
#                             + lag(sent_HML_t,0) + lag(sent_HML_t,1) + lag(sent_HML_t,2) + lag(sent_HML_t,3) + lag(sent_HML_t,4) + lag(sent_HML_t,5) + lag(sent_HML_t,6)
#                             + lag(sent_i_t,0) + lag(sent_i_t,1) + lag(sent_i_t,2) + lag(sent_i_t,3) + lag(sent_i_t,4) + lag(sent_i_t,5) + lag(sent_i_t,6)
#                             + sent_Mkt_t + ret_HML_t + ret_Mkt_t,
#             data = L, model='within', effect='twoways')"
# R"print(summary(reg))";
# R"reg = plm::plm(ret_i_t ~  lag(sent_H_t,0) + lag(sent_H_t,1) + lag(sent_H_t,2) + lag(sent_H_t,3) + lag(sent_H_t,4) + lag(sent_H_t,5) + lag(sent_H_t,6) + lag(sent_H_t,13) + lag(sent_H_t,7) + lag(sent_H_t,8) + lag(sent_H_t,9) + lag(sent_H_t,10) + lag(sent_H_t,11) + lag(sent_H_t,12)
#                             + lag(sent_HML_t,0) + lag(sent_HML_t,1) + lag(sent_HML_t,2) + lag(sent_HML_t,3) + lag(sent_HML_t,4) + lag(sent_HML_t,5) + lag(sent_HML_t,6)
#                             + lag(sent_i_t,0) + lag(sent_i_t,1) + lag(sent_i_t,2) + lag(sent_i_t,3) + lag(sent_i_t,4) + lag(sent_i_t,5) + lag(sent_i_t,6)
#                             + sent_Mkt_t + ret_HML_t + ret_Mkt_t,
#             data = H, model='within', effect='twoways')"
# R"print(summary(reg))";
R"pooltest(ret_i_t~sent_HML_t, data=H, model='within')"
R"testformula = dynformula(ret_i_t~lag(sent_HML_t, 0:3)*isRecent
                            +lag(sent_i_t, 0:3)*isRecent
                            +lag(HML, 0:3) + lag(SMB, 0:3) + lag(Mkt_RF, 0:3)
                            +lag(RMW, 0:3) +lag(CMA, 0:3))"
# R"plmtest(testformula, data=H, effect='twoways', type='ghm')"
R"g <- plm(testformula, data=H, model='random', effect='time')"
# R"g <- pgmm(ret_i_t~sent_i_t + sent_H_t, data = 'L')"
R"print(summary(g))";

R"gw <- plm(testformula, data=H, model='within')"
R"gr <- plm(testformula, data=H, model='random')"
R"phtest(gw, gr)"

R"plmtest(testformula, data=H, effect='individual', type='honda')"

R"zz <- pggls(testformula, data=H, model='within')"
R"print(summary(zz))";

R"reg60H <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = H, effect = 'time', model = 'onestep')"
R"print(summary(reg60H), robust=TRUE)";
R"reg60L <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_L_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = L, effect = 'individual', model = 'onestep')"
R"print(summary(reg60L))";
R"rm(list=ls())"





perlength = 20
offset = 1
@time Rmatrix20 = constructRmatrix(finalSeriesDicBis, perlength, offset, finalSeriesDic,recentperiod)
JLD2.@save "/home/nicolas/Data/Rmatrix20.jld2" Rmatrix20
Rmatrix = Rmatrix20
Hmatrix =  Rmatrix[Rmatrix[:isH] .== 1.0, :];
Lmatrix =  Rmatrix[Rmatrix[:isL] .== 1.0, :];
@rput Rmatrix
@rput Hmatrix
@rput Lmatrix
# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]
R"library(plm)"
R"library(lmtest)"
R"A <- plm::pdata.frame(Rmatrix, index=c('permno', 'td'))";
R"H <- plm::pdata.frame(Hmatrix, index=c('permno', 'td'))";
R"L <- plm::pdata.frame(Lmatrix, index=c('permno', 'td'))";

R"testformula = dynformula(ret_i_t~lag(sent_HML_t, 0:12)+lag(sent_H_t, 0:12)
                            +lag(sent_i_t, 0:12)
                            +lag(HML, 0:12) + lag(SMB, 0:12) + lag(Mkt_RF, 0:12)
                            +lag(RMW, 0:12) +lag(CMA, 0:12))"

R"reg20H <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = H, effect = 'individual', model = 'onestep')"

R"reg20H <- plm(testformula, data=H, model='within', effect='time')"
R"print(summary(reg20H))";
R"print(coeftest(reg20H, vcov=vcovHC(reg20H,type='HC0',cluster='group')))";

R"testformula<-ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)"
R"pooltest(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3), data=H, model='within')"
R"reg20L <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_L_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = L, effect = 'individual', model = 'onestep')"
R"print(summary(reg20L))";


perlength = 5
offset = 1

@time Rmatrix5 = constructRmatrix(finalSeriesDicBis, perlength, offset, finalSeriesDic)
JLD2.@save "/home/nicolas/Data/Rmatrix5.jld2" Rmatrix5
Hmatrix =  Rmatrix[Rmatrix[:isH] .== 1.0, :];
Lmatrix =  Rmatrix[Rmatrix[:isL] .== 1.0, :];
@rput Rmatrix
@rput Hmatrix
@rput Lmatrix


# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]
R"library(plm)"
R"A <- plm::pdata.frame(Rmatrix, index=c('permno', 'td'))";
R"H <- plm::pdata.frame(Hmatrix, index=c('permno', 'td'))";
R"L <- plm::pdata.frame(Lmatrix, index=c('permno', 'td'))";
R"reg5H <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = H, effect = 'individual', model = 'onestep')"
R"print(summary(reg60H))";
R"reg5L <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_L_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = L, effect = 'individual', model = 'onestep')"
R"print(summary(reg60L))";



perlength = 1
offset = 0

@time Rmatrix = constructRmatrix(finalSeriesDicBis, perlength, offset, finalSeriesDic)

Hmatrix =  Rmatrix[Rmatrix[:isH] .== 1.0, :];
Lmatrix =  Rmatrix[Rmatrix[:isL] .== 1.0, :];
@rput Rmatrix
@rput Hmatrix
@rput Lmatrix


# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]
R"library(plm)"
R"A <- plm::pdata.frame(Rmatrix, index=c('permno', 'td'))";
R"H <- plm::pdata.frame(Hmatrix, index=c('permno', 'td'))";
R"L <- plm::pdata.frame(Lmatrix, index=c('permno', 'td'))";
R"reg1H <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_H_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = H, effect = 'individual', model = 'onestep')"
R"print(summary(reg1H))";
R"reg1L <- pgmm(ret_i_t~lag(sent_HML_t, 0:3)+lag(sent_L_t, 0:3)+lag(sent_i_t, 0:3)+lag(sent_Mkt_t, 0:3)
                    |lag(ret_HML_t, 1:2)+lag(ret_Mkt_t, 1:3)+lag(ret_i_t, 1:3),
                    data = L, effect = 'individual', model = 'onestep')"
R"print(summary(reg1L))";
