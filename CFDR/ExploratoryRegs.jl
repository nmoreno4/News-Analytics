using LoadNewsTS, RegressionFcts, Dates, DataFrames, Statistics, RCall, TSmanip,
    ShiftedArrays, Plots, RollingFunctions

# Load data
TRMIsocial, TRMInewssocial, TRMInews = loadTRMI(Month(1))
CFDR = loadCFDR(filename="results_CFDR_topics_complete")
USREC = loadRecession()
CFDR[:expectedRet] = CFDR[:MktRet] .- CFDR[:unexpectedRet]
TRNA = loadTRNA(Month(1), "VW")
# Join data
CFDR = join(CFDR, USREC, on=:date, kind=:inner)
TRMI = hcat(TRMIsocial, TRMInewssocial, TRMInews, makeunique=true)
TRMI = join(TRMI, CFDR, on=:date, kind=:inner)
TRNA = join(TRNA, TRMI, on=:date, kind=:inner)

#### Residual reg ####
# Compute residuals
vars = [:stockIndexSentiment, :CF]; vNames = [:TRMI_N, :CF]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames)
TRMI[:TRMI_CF_res] = mod[:residuals]
vars = [:stockIndexSentiment, :DR]; vNames = [:DR, :TRMI_N]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames)
TRMI[:TRMI_DR_res] = mod[:residuals]
vars = [:DR, :CF]; vNames = [:DR, :CF]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames)
TRMI[:DR_CF_res] = mod[:residuals]
vars = [:CF, :DR]; vNames = [:CF, :DR]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames)
TRMI[:CF_DR_res] = mod[:residuals]

# Impact of perpendicular TRMI
regnames = ["DR_TRMI_perp", "CF_TRMI_perp", "DR_perp_TRMI", "CF_perp_TRMI"]
regnames = ["$(fn).rds" for fn in regnames]
vars = [:DR, :TRMI_CF_res]; vNames = [:DR, :TRMI_N_perpCF]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames; filename=regnames[1])
vars = [:CF, :TRMI_DR_res]; vNames = [:CF, :TRMI_N_perpDR]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames; filename=regnames[2])
vars = [:DR_CF_res, :stockIndexSentiment_2]; vNames = [:DR_perp, :TRMI_N]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames; filename=regnames[3])
vars = [:CF_DR_res, :stockIndexSentiment_2]; vNames = [:CF_perp, :TRMI_N]
mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames; filename=regnames[4])

# rootdir="/home/nicolas/Documents/CF DR paper/Regressions"
# filenames = ["$rootdir/$fn" for fn in regnames]
# @rput filenames
# R"""
# regs = list()
# for (i in 1:length(filenames)){
#     print(filenames[i])
#     regs[[i]] = readRDS(filenames[i])
# }
# print(regs...)
# """



#### Cumulate returns ####
maxlength = 100
function futureExpectedRet(df, i; var=:MktRet)
    winLength = Month(i)
    res, dates = [[] for i in 1:2]
    for date in ceil(minimum(df[:date]), Month):Month(1):ceil(maximum(df[:date]), Month)
        if i==0
            crtdf = df[findall(df[:date].==date-Day(1)), :]
        else
            crtdf = df[findall((df[:date].<date) .& (df[:date].>=date-winLength)), :]
        end
        push!(res, cumlogret(crtdf[var]))
        push!(dates, date-Day(1))
    end
    return lead(res .* 100, i), dates
end
for i in 0:maxlength
    TRMI[Symbol("MktRet_f$(i)")] = futureExpectedRet(TRMI, i, var=:MktRet)[1]
    TRMI[Symbol("CF_f$(i)")] = futureExpectedRet(TRMI, i, var=:CF)[1]
    TRMI[Symbol("DR_f$(i)")] = futureExpectedRet(TRMI, i, var=:DR)[1]
    TRNA[Symbol("MktRet_f$(i)")] = futureExpectedRet(TRNA, i, var=:MktRet)[1]
    TRNA[Symbol("CF_f$(i)")] = futureExpectedRet(TRNA, i, var=:CF)[1]
    TRNA[Symbol("DR_f$(i)")] = futureExpectedRet(TRNA, i, var=:DR)[1]
end
TRMI[:MktRet] = TRMI[:MktRet] .* 100
TRNA[:MktRet] = TRNA[:MktRet] .* 100
TRMI[:CF] = TRMI[:CF] .* 100
TRNA[:CF] = TRNA[:CF] .* 100
TRMI[:DR] = TRMI[:DR] .* 100
TRNA[:DR] = TRNA[:DR] .* 100

### IRF ###

@rput TRNA
R"""
m1 = lm(CF ~ scale(stockIndexSentiment_2), data=TRNA)
m2 = lm(CF ~ scale(stockIndexSentiment), data=TRNA)
m3 = lm(CF ~ scale(SentALL), data=TRNA)
m4 = lm(CF ~ scale(SentRES), data=TRNA)
stargazer(m1,m2,m3,m4, report = "vc*t")
"""

# ["stockIndexSentiment", "stockIndexSentiment_1", "stockIndexSentiment_2", "SentALL", "SentRES", "SentRESF", "SentNORES"]
withControls = false
for retvar in ["CF", "DR", "MktRet"]
    indVars = ["stockIndexSentiment", "stockIndexSentiment_2", "SentALL", "SentRES"]
    for v in 1:length(indVars)
        newsvar = indVars[v]
        reOrd = [[v]; setdiff(1:length(indVars), [v])]
        indVars = indVars[reOrd]
        if occursin("stockIndexSentiment", newsvar) && !withControls
            df = TRMI
        else
            df = TRNA
        end
        for noCycleControl in [true, false]
            coeff, ci_low, ci_high, tstat, r2 = [[] for i in 1:5]
            for i in 0:maxlength
                if noCycleControl
                    if withControls
                        vars = [Symbol("$(retvar)_f$(i)"); Symbol.(indVars)]; vNames = [[Symbol("MktRet_f$(i)")]; Symbol.(indVars)]
                        zeroVec = [0 for i in vars]
                        mod, confInt = lmR(df, zeroVec, zeroVec, vars, vNames)
                    else
                        vars = [Symbol("$(retvar)_f$(i)"), Symbol("$newsvar")]; vNames = [Symbol("MktRet_f$(i)"), :TRMI_N_perpCF]
                        mod, confInt = lmR(df, [0,0], [0,0], vars, vNames)
                    end
                else
                    if i == 0
                        df[:cumUSREC] = df[:USREC]
                    else
                        df[:cumUSREC] = lead(running(sum, df[:USREC], i), i)
                    end
                    if withControls
                        vars = [Symbol("$(retvar)_f$(i)"); Symbol.(indVars); [:cumUSREC]]; vNames = [[Symbol("MktRet_f$(i)")]; Symbol.(indVars) ; [:USREC]]
                        zeroVec = [0 for i in vars]
                        mod, confInt = lmR(df, zeroVec, zeroVec, vars, vNames)
                    else
                        vars = [Symbol("$(retvar)_f$(i)"), Symbol("$newsvar"), :cumUSREC]; vNames = [Symbol("MktRet_f$(i)"), Symbol(newsvar), :USREC]
                        mod, confInt = lmR(df, [0,0,0], [0,0,0], vars, vNames)
                    end
                end
                # vars = [Symbol("$(retvar)_f$(i)"), Symbol("$newsvar")]; vNames = [Symbol("MktRet_f$(i)"), :TRMI_N_perpCF, :USREC]
                push!(coeff, mod[:coefficients][2,1])
                push!(tstat, mod[:coefficients][2,3])
                push!(r2, mod[:adj_r_squared])
                push!(ci_low, confInt[2,1])
                push!(ci_high, confInt[2,2])
            end
            refline, zero = [-coeff[1] for i in coeff], [0 for i in coeff]
            up, low = [2 for i in coeff], [-2 for i in coeff]

            #########
            plot([coeff], xticks=0:6:maxlength, title = "Cumulated CF/DR ~ TRMI_S", titlefontsize=16,
                    yticks = floor(minimum(ci_low))-2:2:ceil(maximum(ci_high)), labels = "Cumulated CF shocks", color = :blue,
                    xlabel = "Months after news", ylabel = "Cumulated return in %", legend=:topleft, line=1, legendfontsize=10)
            plot!([ci_low, ci_high], labels = "", color = :blue, line = :dot)
            irf = plot!([zero], labels = "", color = :black)
            plot!([coeff], labels = "Cumulated DR shocks", color = :red, legendfontsize=12)
            irf = plot!([ci_low, ci_high], labels = "", color = :red, line = :dot)

            plot([tstat], title = "t-stat of impact of TRMI_S on cumulated CF/DR", color=:blue, xticks=0:6:maxlength, legend=:topleft,
                            xlabel = "Months after news", ylabel = "t-stat", labels = "CF impact", titlefontsize=16, legendfontsize=10)
            tplot = plot!([low, up], labels = "", color = :black)
            tplot = plot!([tstat], labels = "DR impact", color = :red, yticks=-8:1:8, legendfontsize=12)

            r2plot = plot([r2], title = "Adjusted R2 of impact of TRMI_S on cumulated CF/DR", labels="CF impact", xticks=0:6:maxlength,
                    xlabel = "Months after news", ylabel = "Adj R2", color=:blue, titlefontsize=16, legend=:topleft, legendfontsize=10)
            r2plot = plot!([r2], color=:red, labels="DR impact", legendfontsize=12, yticks=0:0.05:0.95)

            finalplot = plot(irf, tplot, r2plot, layout = (3,1), size = (1000, 1500))
            savefig(finalplot, "/home/nicolas/cycle_TRMI_S.png")
            #########

            IRFplot = plot([coeff, ci_low, ci_high, refline, zero], xticks=0:6:maxlength, title = "Cumulated $(retvar) ~ $newsvar / Cycle=$(!noCycleControl)",
                    yticks = floor(minimum(ci_low))-2:1:ceil(maximum(ci_high)), labels = "",
                    xlabel = "Months after news", ylabel = "Cumulated return in %", legend=:topleft, line=1, legendfontsize=6)
            if retvar=="CF"
                filepath = "/home/nicolas/Documents/CF DR paper/IRF/$(newsvar)_acf.png"
                R"""
                a <- acf($(df[Symbol(newsvar)]))
                png($(filepath))
                plot(a)
                dev.off()
                """
            elseif retvar=="DR"
                filepath = "/home/nicolas/Documents/CF DR paper/IRF/$(newsvar)_pacf.png"
                R"""
                b <- pacf($(df[Symbol(newsvar)]))
                png($(filepath))
                plot(b)
                dev.off()
                """
            end
            png(IRFplot, "/home/nicolas/Documents/CF DR paper/IRF/$(newsvar)_$(retvar)_irf_Cyc$(!noCycleControl)_contr$(withControls).png")
            tstatplot = plot([tstat, low, up], title = "t-stat of impact of $newsvar on cumulated CF/DR",
                            xlabel = "Months after news", ylabel = "t-stat", labels = "", titlefontsize=10)
            png(tstatplot, "/home/nicolas/Documents/CF DR paper/IRF/$(newsvar)_$(retvar)_tstat_Cyc$(!noCycleControl)_contr$(withControls).png")
            r2plot = plot([r2], title = "Adjusted R2 of impact of $newsvar on cumulated $(retvar) / Cycle=$(!noCycleControl)",
                            xlabel = "Months after news", ylabel = "Adj R2", labels = "", titlefontsize=10)
            png(r2plot, "/home/nicolas/Documents/CF DR paper/IRF/$(newsvar)_$(retvar)_R2_Cyc$(!noCycleControl)_contr$(withControls).png")
        end
    end
end

mod, confInt = lmR(TRMI, [0,0], [0,0], vars, vNames; diffs=[0,0])

### Correl matrix ###
cor(TRMI[:stockIndexSentiment_2], TRMI[:DR])
cor(TRMI[:stockIndexSentiment_2], TRMI[:CF])
cor(TRMI[:CF], TRMI[:DR])

# Cumulative return reg


X = hcat(TRMIsocial, TRMInewssocial, TRMInews, makeunique=true)
X = join(X, CFDR, on=:date, kind=:inner)
Y = join(TRNA, X, on=:date, kind=:inner)

@rput X
R"""
lag = 0
lead = 2
sz = dim(X)[1]
print(summary(lm(CF[(1+lag):(sz-lead)] ~ stockIndexSentiment_1[(1+lag):(sz-lead)] + diff(stockIndexSentiment_1), data=X)))
print(summary(lm(DR[(1+lag):(sz-lead)] ~ stockIndexSentiment_1[(1+lag):(sz-lead)] + diff(stockIndexSentiment_1), data=X)))
print(summary(lm(CF[(1+lag):(sz-lead)] ~ diff(stockIndexSentiment_1), data=X)))
print(summary(lm(DR[(1+lag):(sz-lead)] ~ diff(stockIndexSentiment_1), data=X)))
"""

A = CFDR[CFDR[:USREC].==1,:]
B = CFDR[CFDR[:USREC].==0,:]
@rput CFDR; @rput A; @rput B
R"""
print(summary(lm(sprtrn ~ CF + DR, data=CFDR)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=CFDR)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=A)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=B)))
"""
cor(CFDR[:CF], CFDR[:DR])

plot(ret2tick(Y[:DR]))

for i in names(Y)
    print("$i \n")
end

cor(Y[:stockIndexSentiment_1], Y[:SentALL])
vfloat(x) = convert(Array{Float64}, x)
plot(autocor(vfloat(Y[:stockIndexSentiment])))
plot!(autocor(vfloat(Y[:stockIndexSentiment_1])))
plot!(autocor(vfloat(Y[:stockIndexSentiment_2])))
plot(Y[:stockIndexSentiment])
plot!(Y[:DR])
@rput X
R"acf(Y[,'stockIndexUncertainty'])"
R"""
lag = 1
lead = 0
sz = dim(Y)[1]
print(summary(lm(DR[(1+lag):(sz-lead)]~stockIndexSentiment_1[(1+lead):(sz-lag)]*SentALL[(1+lead):(sz-lag)], data=Y)))
print(summary(lm(CF~stockIndexSentiment_1*SentALL, data=Y)))
print(summary(lm(CF[(1+lag):(sz-lead)]~diff(stockIndexSentiment_1)*diff(SentALL), data=Y)))
"""
R"""
sz = dim(Y)[1]
print("AAA")
print(summary(lm(CF~SentALL, data=Y)))
print("BBB")
print(summary(lm(CF[2:sz]~diff(SentALL), data=Y)))
print("CCC")
print(summary(lm(CF[2:sz]~SentALL[1:sz-1], data=Y)))
print("DDD")
print(summary(lm(DR~SentALL, data=Y)))
print("EEE")
print(summary(lm(DR[2:sz]~diff(SentALL), data=Y)))
print("FFF")
print(summary(lm(DR[2:sz]~SentALL[1:sz-1], data=Y)))
"""


names(X)
lags = [1,2,0]
leads = [0,0,1]
vars = ["CF", "stockIndexSentiment_1", "stockIndexSentiment_1"]
vNames = ["CF", "TRMI_NS_sent", "TRMI_NS_sent"]
lmR(X, lags, leads, vars, vNames, true)
