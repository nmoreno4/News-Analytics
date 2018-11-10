using PyCall, Statistics, StatsBase, DataFramesMeta, NaNMath, RCall, CSV, DataFrames, JLD2
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")
# JLD2.@load "/home/nicolas/Data/finalSeriesDicBis.jld2"
# JLD2.@load "/home/nicolas/Data/finalSeriesDic.jld2"
recentperiod = 2017



# for comb in [(1,0)]
#     @time Rmatrix = constructRmatrix(finalSeriesDicBis, comb[1], comb[2], finalSeriesDic,recentperiod)
#     JLD2.@save "/home/nicolas/Data/Rmatrix$(comb[1]).jld2" Rmatrix
# end


# [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t, :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1, :sent_L_tl1, :isL, :isH]



function specifyRformula(ptf, diff=false; lag_sent_i="0:3", lag_sent_Mkt="0:3", lag_sent_ptf="0:3", lag_sent_HML="0:3",
                         lag_ret_i="1:3", lag_ret_Mkt="0", lag_ret_HML="0", lag_ret_SMB="0", lag_ret_CMA="0", lag_ret_RMW="0", lag_ret_Mom="0")
    @rput ptf; @rput lag_sent_i; @rput lag_sent_Mkt; @rput lag_sent_ptf; @rput lag_sent_HML; @rput lag_ret_i; @rput lag_ret_Mkt; @rput lag_ret_HML; @rput lag_ret_SMB; @rput lag_ret_CMA; @rput lag_ret_RMW; @rput lag_ret_Mom;
    if diff
        R"testformula = dynformula(as.formula(paste(
            'ret_i_t ~ diff(sent_HML_t, eval(parse(text=lag_sent_HML)))*isRecent+diff(sent_', ptf, '_t, eval(parse(text=lag_sent_ptf)))*isRecent+diff(sent_i_t, eval(parse(text=lag_sent_i)))+diff(sent_Mkt_t, eval(parse(text=lag_sent_Mkt)))+lag(ret_i_t, eval(parse(text=lag_ret_i)))+lag(Mkt_RF, eval(parse(text=lag_ret_Mkt)))+lag(HML, eval(parse(text=lag_ret_HML)))+lag(SMB, eval(parse(text=lag_ret_SMB)))+lag(Mom, eval(parse(text=lag_ret_Mom)))'
            , sep='')))"
    else
        R"testformula = dynformula(as.formula(paste(
            'ret_i_t ~ lag(sent_HML_t, eval(parse(text=lag_sent_HML)))*isRecent+lag(sent_', ptf, '_t, eval(parse(text=lag_sent_ptf)))*isRecent+lag(sent_Mkt_t, eval(parse(text=lag_sent_Mkt)))+lag(sent_i_t, eval(parse(text=lag_sent_i)))+lag(ret_i_t, eval(parse(text=lag_ret_i)))+lag(Mkt_RF, eval(parse(text=lag_ret_Mkt)))+lag(HML, eval(parse(text=lag_ret_HML)))+lag(SMB, eval(parse(text=lag_ret_SMB)))+lag(Mom, eval(parse(text=lag_ret_Mom)))'
            , sep='')))"
    end
end

R"ResultsReg <- list()"
for freq in [60,20,5]
    filetoload = "/home/nicolas/Data/Rmatrix$freq.jld2"
    @load filetoload Rmatrix
    regressionSessionR(Rmatrix)
    print(freq)
    for ptf in ["H", "L"]
        print(ptf)
        for usediff in [true]
            for lagspec in [("0:6", "0:6","0:6")]
                lag_sent_HML=lagspec[1]; lag_sent_ptf=lagspec[2]; lag_sent_Mkt=lagspec[3]
                specifyRformula(ptf, usediff, lag_sent_Mkt=lag_sent_Mkt, lag_sent_ptf=lag_sent_ptf, lag_sent_HML=lag_sent_HML)
                @time plm(ptf, freq, "within", "individual", usediff, lag_sent_Mkt, lag_sent_ptf, lag_sent_HML);
                # @time adjustVcovBis("NW", ptf, freq, "within", "individual", usediff, lag_sent_Mkt, lag_sent_ptf, lag_sent_HML)
                @time adjustVcovBis("SCC", ptf, freq, "within", "individual", usediff, lag_sent_Mkt, lag_sent_ptf, lag_sent_HML)
            end
        end
    end
end


# ("0", "0","0"), ("0:1", "0:1","10"), ("0:3", "0:3","0:3"), ("0:1", "0:1","0:1"),

R"stargazer(ResultsReg[['plm_L_5_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_5_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_5_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_5_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_5_FALSE_0:1_0:1_0:1_within_individual']], ResultsReg[['plm_L_5_FALSE_0:1_0:1_0:1_within_individual']], type = 'latex', report=('vc*t'),
          se = list(ResultsReg[['coeftest_NW_L_5_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_NW_L_5_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_L_5_FALSE_0:1_0:1_0:1']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_FALSE_0:1_0:1_0:1']][,'Std. Error']) )"

R"stargazer(ResultsReg[['plm_H_60_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_60_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_H_20_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_20_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_H_5_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_5_FALSE_0:6_0:6_0:6_within_individual']],
        se = list(ResultsReg[['coeftest_SCC_H_60_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_60_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC__H_20_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_20_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_H_5_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][,'Std. Error']),
        title = 'Regre',
        type = 'latex',
        report=('vc*t'),
        no.space=TRUE,
        dep.var.caption = 'ret_{i,t}',
        dep.var.labels = c('Quart.^{(Val)}', 'Quart.^{(Gro)}', 'Month.^{(Val)}', 'Month.^{(Gro)}', 'Week.^{(Val)}', 'Week.^{(Gro)}'),
        font.size = 'footnotesize',
        column.sep.width = '1pt',
        digits = 2,
        initial.zero = FALSE )"



R"stargazer(ResultsReg[['plm_H_60_TRUE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_60_TRUE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_H_20_TRUE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_20_TRUE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_H_5_TRUE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_5_TRUE_0:6_0:6_0:6_within_individual']],
        se = list(ResultsReg[['coeftest_SCC_H_60_TRUE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_60_TRUE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC__H_20_TRUE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_20_TRUE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_H_5_TRUE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_TRUE_0:6_0:6_0:6']][,'Std. Error']),
        title = 'Regre',
        type = 'latex',
        report=('vc*t'),
        no.space=TRUE,
        dep.var.caption = 'ret_{i,t}',
        dep.var.labels = c('Quart.^{(Val)}', 'Quart.^{(Gro)}', 'Month.^{(Val)}', 'Month.^{(Gro)}', 'Week.^{(Val)}', 'Week.^{(Gro)}'),
        font.size = 'footnotesize',
        column.sep.width = '1pt',
        digits = 2,
        initial.zero = FALSE )"



R"stargazer(ResultsReg[['plm_H_60_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_60_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_H_20_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_20_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_H_5_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_5_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_H_1_FALSE_0:3_0:3_0:3_within_individual']], ResultsReg[['plm_L_1_FALSE_0:3_0:3_0:3_within_individual']],
        se = list(ResultsReg[['coeftest_NW_H_60_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_L_60_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW__H_20_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_L_20_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_H_5_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_L_5_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_H_1_FALSE_0:3_0:3_0:3']][,'Std. Error'], ResultsReg[['coeftest_NW_L_1_FALSE_0:3_0:3_0:3']][,'Std. Error']),
        title = 'Regression of individual stock returns against past lags of the stocks sentiment, past lags of the market sentiment,
                past lags of the Value (Growth) portfolio sentiment and past lags of the spread (HML) between Value and Growth stocks.
                The excess market return, HML, SMB and Momentum factors were used as control variables as well as two lags of the stocks
                return. We use all stocks listed on the NYSE, AMEX and NASDAQ between January 2003 and December 2017. To account for changes
                in the importance of the sentiment spread we use a dummy for the recent period (post-2011) where factor investing and style-dedicated
                ETFs started gaining steam. t-stats are reported in brackets. The construction of the sentiment indices are described in Appendix I.',
        type = 'text',
        report=('vc*t'),
        no.space=TRUE,
        covariates.labels = c('Quart. ret_{i,t}^{(Val)}', 'Quart. ret_{i,t}^{(Gro)}', 'Month. ret_{i,t}^{(Val)}', 'Month. ret_{i,t}^{(Gro)}', 'Week. ret_{i,t}^{(Val)}', 'Week. ret_{i,t}^{(Gro)}', 'Day. ret_{i,t}^{(Val)}', 'Day. ret_{i,t}^{(Gro)}'),
        font.size = 'footnotesize',
        column.sep.width = '1pt',
        digits = 2,
        star.cutoffs = c(0.05, 0.01, 0.001),
        initial.zero = FALSE )"

        title = 'Regression of individual stock returns against past lags of the stocks sentiment, past lags of the market sentiment,
                past lags of the Value (Growth) portfolio sentiment and past lags of the spread (HML) between Value and Growth stocks.
                The excess market return, HML, SMB and Momentum factors were used as control variables as well as two lags of the stocks
                return. We use all stocks listed on the NYSE, AMEX and NASDAQ between January 2003 and December 2017. To account for changes
                in the importance of the sentiment spread we use a dummy for the recent period (post-2011) where factor investing and style-dedicated
                ETFs started gaining steam. t-stats are reported in brackets. The construction of the sentiment indices are described in Appendix I.',

# add.lines = list(c('Controls', 'Mkt-rf, HML,\nSMB, Mom,\nlag(ret_i, 1:2)'),
dep.var.labels = c('', ''),
keep = c(''),
omit.table.layout = 'sn'
keep = c(),
dep.var.labels = c('S^{HML}_{t0}', 'S^{HML}_{t-1}', 'S^{i}_{t0}', 'S^{i}_{t-1}', 'S^{Val}_{t0}', 'S^{Val}_{t-1}', 'S^{Gro}_{t0}', 'S^{Gro}_{t-1}'),


R"summary(ResultsReg[['plm_H_5_FALSE_0:6_0:6_0:6_within_individual']])"

R"stargazer(ResultsReg[['plm_L_5_FALSE_0:6_0:6_0:6_within_individual']], ResultsReg[['plm_L_5_FALSE_0:6_0:6_0:6_within_individual']], type = 'latex',
          se = list(ResultsReg[['coeftest_NW_L_5_FALSE_0:6_0:6_0:6']][,'Std. Error'], ResultsReg[['coeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][,'Std. Error']),
          add.lines = list(c(rownames(ResultsReg[['summarycoeftest_NW_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']])[1],
                             round(ResultsReg[['summarycoeftest_NW_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']][1, 'p-value'], 2),
                             round(ResultsReg[['summarycoeftest_NW_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']][1, 'p-value'], 2)),
                           c(rownames(ResultsReg[['summarycoeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']])[2],
                             round(ResultsReg[['summarycoeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']][2, 'p-value'], 2),
                             round(ResultsReg[['summarycoeftest_SCC_L_5_FALSE_0:6_0:6_0:6']][['diagnostics']][2, 'p-value'], 2)) ))"



usediff = false
lag_sent_Mkt="0:5"; lag_sent_ptf="0:10"; lag_sent_HML="0:10"
specifyRformula("L", usediff, lag_sent_Mkt=lag_sent_Mkt, lag_sent_ptf=lag_sent_ptf, lag_sent_HML=lag_sent_HML)
@time plm("L", 20, "within", "individual", usediff, lag_sent_Mkt, lag_sent_ptf, lag_sent_HML);
@time adjustVcov("SCC", "L", 20, "within", "individual", usediff, lag_sent_Mkt, lag_sent_ptf, lag_sent_HML)

# @time hausmantest("H", 20);
R"summary(ResultsReg$plm_H)"
@time R"print(coeftest(ResultsReg$plm_H, vcov=vcovNW(ResultsReg$plm_H)))";
@time R"print(coeftest(ResultsReg$plm_H, vcov=vcovSCC(ResultsReg$plm_H)))";
R"ResultsReg$sum"
R"summary(ResultsReg$plm_L)"


R"ResultsReg[['plm_L_20_within_individual']]"

R"ResultsReg[[a]]"


















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
