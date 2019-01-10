module Causality

using RCall, DataFrames, FindFcts
export grangerVARCaus

function grangerVARCaus(Data, x, y, maxlags = 24)
    R"remove(list = ls())"
    X = Data[[:DATE, x, y]]
    X = deleteMissingRows(X, x, y); names!(X, [:date, :x1, :x2])
    @rput X
    R"""
    getmode <- function(v) {
       uniqv <- unique(v)
       uniqv[which.max(tabulate(match(v, uniqv)))]
    }
    require("forecast")
    require("vars")
    require("urca")
    # plot.ts(X)
    jotest=ca.jo(data.frame(X[, "x1"], X[, "x2"]), type="trace", K=2, ecdet="none", spec="longrun")
    critcoint = summary(jotest)@cval[1,3]
    cointStat = summary(jotest)@teststat[1]
    isCointegrated = cointStat>critcoint
    dr1 = ndiffs(X[, "x1"], alpha = 0.05, test = c("adf"))
    dr2 = ndiffs(X[, "x2"], alpha = 0.05, test = c("adf"))
    if (dr1>0  && cointStat<critcoint){
        d.x1 = c(rep(NA,dr1), diff(X[, "x1"], differences = dr1))
    } else {
        d.x1 = X[, "x1"]
    }
    if (dr2>0  && cointStat<critcoint){
        d.x2 = c(rep(NA,dr2), diff(X[, "x2"], differences = dr2))
    } else {
        d.x2 = X[, "x2"]
    }
    dx = na.omit(cbind(d.x1, d.x2))
    # plot.ts(dx)
    modelLag = VARselect(dx, lag.max = $maxlags, type = "both")
    plags = getmode(modelLag$selection)
    varM = VAR(dx, p=plags)
    x1coeffs = as.data.frame(summary(varM)$varresult$d.x1$coefficients)
    x1coeffs$Y = rownames(x1coeffs)
    x2coeffs = as.data.frame(summary(varM)$varresult$d.x2$coefficients)
    x2coeffs$Y = rownames(x2coeffs)
    x1R2 = summary(varM)$varresult$d.x1$adj.r.squared
    x2R2 = summary(varM)$varresult$d.x2$adj.r.squared
    serialcorrel = serial.test(varM, lags.pt = $maxlags, type = "PT.asymptotic")
    x2causex1 = grangertest(d.x1 ~ d.x2, order = plags)
    x1causex2 = grangertest(d.x2 ~ d.x1, order = plags)
    print(x2causex1);
    print(x1causex2);
    """;
    @rget x1causex2
    @rget x2causex1
    @rget isCointegrated
    @rget serialcorrel
    @rget x1coeffs; @rget x2coeffs
    @rget x1R2; @rget x2R2
    @rget dr1; @rget dr2;
    Res = Dict(
            :lagOrder => x1causex2[2,:Res_Df]-x1causex2[1,:Res_Df],
            :isCointegrated => isCointegrated,
            :dr1 => dr1, :dr2 => dr2,
            :Pval_serialcorrel => serialcorrel[:serial][:p_value],
            :Pval_x1causex2 => x1causex2[2, Symbol("Pr(>F)")],
            :Pval_x2causex1 => x2causex1[2, Symbol("Pr(>F)")],
            :x1_VAR_coeffs => x1coeffs,
            :x2_VAR_coeffs => x2coeffs,
            :x1_VAR_R2 => x1R2, :x2_VAR_R2 => x2R2
            )
    return Res
end

end #module
