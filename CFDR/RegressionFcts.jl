module RegressionFcts
using DataFrames, RCall, ShiftedArrays
export lmR


function leadlagCompute(lags, leads)
    adjlags = [maximum(lags)]; adjleads = [maximum(leads)]
    for (l, f) in zip(lags, leads)
        if !(0 in [l, f])
            error("One of lead or lag must be zero")
        end
        push!(adjlags, maximum(lags)+f-l); push!(adjleads, maximum(leads)+l-f)
    end
    return (adjlags, adjleads)
end

function lmR(X, lags, leads, vars, vNames; showSummary=true, diffs = 0, filename="test.rds", rootdir="/home/nicolas/Documents/CF DR paper/Regressions")
    vars = String.(vars)
    vNames = String.(vNames)
    if length(vars)>10
        error("The maximum number of regressors currently accepted is 9.")
    end
    if lags[1] != 0
        error("Independent variable must not be lagged!")
    end
    sz = size(X, 1)
    for i in 1:length(vNames)
        if i>1 && lags[i]>0
            i>1 ? vNames[i]="$(vNames[i])_l$(lags[i])" : nothing
        elseif i>1 && leads[i]>0
            i>1 ? vNames[i]="$(vNames[i])_f$(leads[i])" : nothing
        end
    end
    for d in 2:length(diffs)
        if diffs!=0 && diffs[d]>0
            lags[d] = lags[d]+diffs[d]
            # print(X[Symbol(vars[d])] - lag(X[Symbol(vars[d])], diffs[d]))
            # X[vars[d]] = convert(Array{Union{Float64,Missing}}, X[Symbol(vars[d])])
            X[Symbol("$(vars[d])_diff$(diffs[d])")] = X[Symbol(vars[d])] - lag(X[Symbol(vars[d])], diffs[d])
            vars[d] = "$(vars[d])_diff$(diffs[d])"
        end
    end
    regressors = "$(vNames[2])"
    if length(vNames)>2
        for vName in vNames[3:end]
            regressors = "$(regressors) + $(vName)"
        end
    end
    @rput X; @rput sz; @rput vars; @rput vNames
    lags, leads = leadlagCompute(lags[2:end], leads[2:end])
    filepath = "$rootdir/$filename"
    if length(vars) == 2
        R"""
        print(vars[1])
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        mod = lm( a ~ b)
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 3
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        mod = lm( a ~ b + c )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 4
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        mod = lm( a ~ b + c + d )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 5
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =  scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        mod = lm( a ~ b + c + d + e )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 6
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =   scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =   scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =   scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =   scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        f =   scale(unlist(X[vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])])
        mod = lm( a ~ b + c + d + e + f )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod['call'][2][[1]][2] = $regressors
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 7
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =  scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        f =  scale(unlist(X[vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])])
        g =  scale(unlist(X[vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])])
        mod = lm( a ~ b + c + d + e + f + g )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod['call'][2][[1]][2] = $regressors
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 8
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =  scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        f =  scale(unlist(X[vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])])
        g =  scale(unlist(X[vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])])
        h =  scale(unlist(X[vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])])
        mod = lm( a ~ b + c + d + e + f + g + h )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod['call'][2][[1]][2] = $regressors
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 9
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =  scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        f =  scale(unlist(X[vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])])
        g =  scale(unlist(X[vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])])
        h =  scale(unlist(X[vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])])
        i =  scale(unlist(X[vars[9]], use.names=FALSE)[(1+$lags[9]):(sz-$leads[9])])
        mod = lm( a ~ b + c + d + e + f + g + h + i )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod['call'][2][[1]][2] = $regressors
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        save(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    elseif length(vars) == 10
        R"""
        a =  unlist(X[vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  scale(unlist(X[vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])])
        c =  scale(unlist(X[vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])])
        d =  scale(unlist(X[vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])])
        e =  scale(unlist(X[vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])])
        f =  scale(unlist(X[vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])])
        g =  scale(unlist(X[vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])])
        h =  scale(unlist(X[vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])])
        i =  scale(unlist(X[vars[9]], use.names=FALSE)[(1+$lags[9]):(sz-$leads[9])])
        j =  scale(unlist(X[vars[10]], use.names=FALSE)[(1+$lags[10]):(sz-$leads[10])])
        mod = lm( a ~ b + c + d + e + f + g + h + i + j )
        confInt = confint(mod)
        names(mod['coefficients'][[1]]) = c("Intercept", vNames[2:length(vNames)])
        mod['call'][1][[1]] = paste(vNames[1], $regressors, sep=" ~ ")
        mod['call'][2][[1]][2] = $regressors
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        saveRDS(mod, file=$filepath)
        """
        @rget mod; @rget confInt
        return mod, confInt
    end
end


end #module
