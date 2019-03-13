module RegressionFcts
using DataFrames, RCall
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

function lmR(X, lags, leads, vars, vNames; showSummary=true)
    if length(vars)>10
        error("The maximum number of regressors currently accepted is 9.")
    end
    sz = size(X, 1)
    for i in 1:length(vNames)
        if lags[i]>0
            i>1 ? vNames[i]="$(vNames[i])_l$(lags[i])" : nothing
        elseif leads[i]>0
            i>1 ? vNames[i]="$(vNames[i])_f$(leads[i])" : nothing
        end
    end
    print(vNames)
    @rput X; @rput sz
    lags, leads = leadlagCompute(lags, leads)
    if length(vars) == 2
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$leads[2]):(sz-$lags[2])]
        mod = lm( a ~ b)
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 3
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        mod = lm( a ~ b + c )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 4
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        mod = lm( a ~ b + c + d )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 5
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        e =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        f =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        mod = lm( a ~ b + c + d + e )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 6
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        e =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        f =  unlist(X[$vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])]
        mod = lm( a ~ b + c + d + e + f )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 7
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        e =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        f =  unlist(X[$vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])]
        g =  unlist(X[$vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])]
        mod = lm( a ~ b + c + d + e + f + g )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 8
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        e =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        f =  unlist(X[$vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])]
        g =  unlist(X[$vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])]
        h =  unlist(X[$vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])]
        mod = lm( a ~ b + c + d + e + f + g + h )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 9
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        e =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        f =  unlist(X[$vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])]
        g =  unlist(X[$vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])]
        h =  unlist(X[$vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])]
        i =  unlist(X[$vars[9]], use.names=FALSE)[(1+$lags[9]):(sz-$leads[9])]
        mod = lm( a ~ b + c + d + e + f + g + h + i )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    elseif length(vars) == 10
        R"""
        a =  unlist(X[$vars[1]], use.names=FALSE)[(1+$lags[1]):(sz-$leads[1])]
        b =  unlist(X[$vars[2]], use.names=FALSE)[(1+$lags[2]):(sz-$leads[2])]
        c =  unlist(X[$vars[3]], use.names=FALSE)[(1+$lags[3]):(sz-$leads[3])]
        d =  unlist(X[$vars[4]], use.names=FALSE)[(1+$lags[4]):(sz-$leads[4])]
        e =  unlist(X[$vars[5]], use.names=FALSE)[(1+$lags[5]):(sz-$leads[5])]
        f =  unlist(X[$vars[6]], use.names=FALSE)[(1+$lags[6]):(sz-$leads[6])]
        g =  unlist(X[$vars[7]], use.names=FALSE)[(1+$lags[7]):(sz-$leads[7])]
        h =  unlist(X[$vars[8]], use.names=FALSE)[(1+$lags[8]):(sz-$leads[8])]
        i =  unlist(X[$vars[9]], use.names=FALSE)[(1+$lags[9]):(sz-$leads[9])]
        j =  unlist(X[$vars[10]], use.names=FALSE)[(1+$lags[10]):(sz-$leads[10])]
        mod = lm( a ~ b + c + d + e + f + g + h + i + j )
        names(mod['coefficients'][[1]]) = c("Intercept", $vNames[2:length($vNames)])
        mod = summary(mod)
        if ($showSummary){
            print(mod)
        }
        """
        @rget mod
        return mod
    end
end

end #module
