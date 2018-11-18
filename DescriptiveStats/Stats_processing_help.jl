using DataFrames, RCall, DataFramesMeta, RollingFunctions

function rename_event(symb,topics=["RES"])
    substrings = split(String(symb) ,r"[\[\]()]")
    res = String["","",""]
    for substr in substrings
        if length(substr)>2
            try
                if occursin("sent" , substr) && occursin("nbStories" , substr)
                    res[2] = "aggSent"
                elseif occursin("sent" , substr)
                    res[2] = "sumSent"
                elseif occursin("nbSto" , substr)
                    res[2] = "nbStories"
                elseif occursin("dailyret" , substr)
                    res[2] = "ret"
                elseif typeof(eval(Meta.parse("[$substr]")))==Vector{Int64}
                    lims = eval(Meta.parse("[$substr]"))
                    res[1] = "$(lims[1])_$(lims[2])"
                end
            catch
                error(substr)
            end
            for topic in topics
                if occursin(topic, substr)
                    res[3] = topic
                end
            end
        end
    end
    return Symbol("$(res[2])$(res[3])_$(res[1])")
end

function keepgoodcolumns(ptfDF, topics)
    if :permno_1 in names(ptfDF)
        delete!(ptfDF, :permno_1)
    end
    for i in names(ptfDF)
        if countmissing(ptfDF[i])[2]==0
            delete!(ptfDF, i)
        end
        if String(i)[end-1:end]=="_1"
            rename!(ptfDF, i=>rename_event(i, topics))
        end
    end
    return ptfDF
end

function bystockmeans(ptfDF, vars)
    a = by(ptfDF, :permno) do df
        res = Dict()
        for var in vars
            res[Symbol("mean_$(var)")] = custom_mean_missing(df[var])
        end
        DataFrame(res)
    end
    res = Dict()
    for i in names(a)
        if i != :permno
            res[i] = custom_mean_missing(a[i])
        end
    end
    return res
end

function by_means(ptfDF, vars, groupvar)
    a = by(ptfDF, groupvar) do df
        res = Dict()
        for var in vars
            res[Symbol("mean_$(var)")] = custom_mean_missing(df[var])
        end
        DataFrame(res)
    end
    return a
end

function colmeans_to_dic(a)
    res = Dict()
    for i in names(a)
        if i != :permno
            res[i] = custom_mean_missing(a[i])
        end
    end
    return res
end


function concat_ts_timmerman!(means_td_sent, ts_timmerman, sz, var)
    if sz in keys(ts_timmerman)
        ts_timmerman[sz] = hcat(ts_timmerman[sz], means_td_sent[var])
    else
        ts_timmerman[sz] = means_td_sent[var]
    end
end



function ptfEWmean(dicDF)
    X = 0
    for ptf in 1:5
        ts = Float64[]
        for row in 1:size(dicDF[ptf], 1)
            push!(ts, custom_mean(dicDF[ptf][row,:]))
        end
        if ptf==1
            X = ts
        else
            try
                X = hcat(X, ts)
            catch
                error("$(size(X)) - $(size(ts))")
            end
        end
    end
    X = replace(X, missing=>0)
    return X = replace(X, NaN=>0)
end


function timmerman(X, freq)
    #Use 10/6/3/2 as the block length if data is measured in daily/monthly/quarterly/annual returns.
    @rput X
    @rput freq
    R"library(monotonicity)"
    R"Y = monoRelation(X, bootstrap = 1000, increasing=T, difference = F, freq)"
    R"Z = monoRelation(X, bootstrap = 1000, increasing=F, difference = F, freq)"
    @rget Y; @rget Z
    return (Y, Z)
end



function daysWNOead(tdperiods, means_td_sent, vars)
    allperidDF = Dict()
    for var in vars
        res = Union{Float64, Missing}[]
        j=1
        for i in tdperiods[1]:tdperiods[2]
            if !(i in means_td_sent[:perid])
                push!(res, 0)
            else
                push!(res, means_td_sent[var][j])
                j+=1
            end
        end
        allperidDF[var] = res
    end
    allperidDF[:perid] = collect(tdperiods[1]:tdperiods[2])
    return DataFrame(allperidDF)
end


function cdf_variable(ptfDF, vars, ptf)
    res = ones(Float64, 100, length(vars))
    for i in 1:length(vars)
        res[:,i] = percentile(collect(skipmissing(ptfDF[vars[i]])), 1:100)
    end
    res = DataFrame(res)
    names!(res, vars)
    CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/cdf_$(ptf)_$(vars).csv", DataFrame(res))
    return res
end



function buckets_assign(ptfDF, cvar, cperc)
    ptfDF[Symbol("$(cvar)_bucket")] = 0
    bkpoints = percentile(collect(skipmissing(ptfDF[cvar])), cperc)
    pushfirst!(bkpoints, -999999999999)
    for bp in 2:length(bkpoints)
        for row in 1:length(ptfDF[cvar])
            if !(ismissing(ptfDF[cvar][row])) && bkpoints[bp-1] < ptfDF[cvar][row] <= bkpoints[bp]
                ptfDF[Symbol("$(cvar)_bucket")][row] = bp-1
            end
        end
    end
    return ptfDF
end




function HMLspreads(HMLDic, chosenvars, ws="VW")
    HMLids = [(x,y) for x in [(1,3), (8,10), (4,7)] for y in [(1,5), (6,10)]]

    w_vars = [Symbol("w_$(x)") for x in chosenvars]
    print(chosenvars)
    SL = EW_VW_series(HMLDic[HMLids[1]], w_vars, chosenvars)
    BL = EW_VW_series(HMLDic[HMLids[2]], w_vars, chosenvars)
    SH = EW_VW_series(HMLDic[HMLids[3]], w_vars, chosenvars)
    BH = EW_VW_series(HMLDic[HMLids[4]], w_vars, chosenvars)


    XW_vars = [Symbol("$(ws)_$(x)") for x in chosenvars]
    res = Dict()
    for i in 1:length(XW_vars)
        H_VW = (replace(SH[XW_vars[i]], missing=>0) .+ replace(BH[XW_vars[i]], missing=>0)) ./ 2
        L_VW = (replace(SL[XW_vars[i]], missing=>0) .+ replace(BL[XW_vars[i]], missing=>0)) ./ 2
        res[Symbol("HML_$(XW_vars[i])")] = H_VW .- L_VW
    end

    return res
end


function loadFFfactors()
    FFfactors = CSV.read("/run/media/nicolas/Research/FF/dailyFactors.csv")[1:3776,:]
    FFfactors[:Date] = 1:3776
    for i in names(FFfactors)[2:end]
        FFfactors[i] = FFfactors[i] ./ 100
    end
    return FFfactors
end


function concat_groupInvariant_vars(c, regDF)
    #c is my "raw" DataFrame, regDF is my DataFrame with group-invariant data (e.g. HML spreads, RF, Baker sent, etc...)
    for i in names(regDF)
        c[i] = 0
    end
    for i in names(c)
        c[i] = convert(Array{Union{Float64,Missing}}, c[i])
    end
    for row in 1:size(c,1)
        c[row,5:end] = regDF[Int(c[row,:perid]),:]
    end
    return c
end



function excessRet(c, vars, RFvec)
    for i in vars
        for row in 1:size(c,1)
            c[row,i] = c[row,i] - RFvec[Int(c[row,:perid])]
        end
    end
    return c
end



function createPanelDF(ptfDF, HMLDic; runninglags = [250,60,20,5], HMLvars = [:sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES], ptfvars = [:cumret, :aggSent_], tdperiods = (1,3776))
    HMLnico = HMLspreads(HMLDic, HMLvars)
    FFfactors = loadFFfactors()
    HMLnico[:HML_VW_cumret] = HMLnico[:HML_VW_cumret] .- FFfactors[:RF]
    HMLnico = DataFrame(HMLnico)
    for i in names(HMLnico)
        for lag in runninglags
            chosenfct = custom_mean
            if String(i)[end-2:end]=="ret"
                chosenfct = cumret
            end
            HMLnico[Symbol("$(i)_l$(lag)")] = running(chosenfct, HMLnico[i], lag)
        end
    end
    groupInvariants = hcat(FFfactors, HMLnico)

    stackDF = ptfDF[[:aggSent_, :cumret, :perid, :permno, :wt]]
    ptfSpecific = EW_VW_series(ptfDF, [Symbol("ptf_$x") for x in ptfvars], ptfvars)
    print(names(ptfSpecific))
    print("A")
    ptfSpecific = daysWNOead(tdperiods, ptfSpecific, names(ptfSpecific))
    print(names(ptfSpecific))
    print("B")
    delete!(ptfSpecific, [:perid])
    delete!(stackDF, [:wt])
    names!(ptfSpecific, [Symbol("ptf_$(x)") for x in names(ptfSpecific)])
    print(names(ptfSpecific))
    groupInvariants = hcat(FFfactors, DataFrame(HMLnico), ptfSpecific)
    delete!(groupInvariants, :Date)
    stackDF = excessRet(stackDF, [:cumret], groupInvariants[:RF])
    paneldf = concat_groupInvariant_vars(stackDF, groupInvariants)

    return paneldf
end




function panelReg(a)
    regfactors = [String(x) for x in names(a)]
    @rput regfactors
    R"regspec <- as.formula(paste(paste(regfactors[3], '~', sep=''), paste(regfactors[4:length(regfactors)], collapse='+')))"
    @rput a
    R"library(plm)"
    R"E <- pdata.frame(a, index=c('permno', 'perid'))"
    R"mod <- plm(regspec, data = E, model = 'within')"
    R"res = summary(mod)"
    R"coeffcols = colnames(summary(mod)$coefficients)"
    R"coeffrows = rownames(summary(mod)$coefficients)"
    @rget res; @rget coeffcols; @rget coeffrows
    res[:coefficients] = DataFrame(res[:coefficients])
    names!(res[:coefficients], Symbol.(coeffcols))
    oldcols = names(res[:coefficients])
    res[:coefficients][:depvars] = coeffrows
    res[:coefficients] = res[:coefficients][[:depvars; oldcols]]
    return res
end




function EW_VW_series(aggDF, newcols, symbs, wt=:wt, perSymb=:perid)
    wtSUM = by(aggDF, perSymb) do df
        DataFrame(wtSUM = custom_sum(df[:wt]))
    end
    wtSUM=Dict(zip(wtSUM[perSymb], wtSUM[:wtSUM]))
    # print(@with(aggDF, cols(sentSymb) + cols(wt)))
    for ncol in newcols
        aggDF[ncol] = Array{Union{Float64,Missing}}(missing, length(aggDF[perSymb]))
    end
    df2 = @byrow! aggDF begin
        @newcol wtSUM::Array{Union{Float64,Missing}}
        :wtSUM = wtSUM[:perid]
    end
    for (symb, coln) in zip(symbs, newcols)
        df2[coln] = @with(df2, cols(symb) .* (cols(wt) ./ cols(:wtSUM)) )
    end
    resDF = by(df2, perSymb) do df
        res = Dict()
        for (symb, coln) in zip(symbs, newcols)
            res[Symbol("VW_$(symb)")] = custom_sum_missing(df[coln])
            res[Symbol("EW_$(symb)")] = custom_mean_missing(df[symb])
        end
        DataFrame(res)
    end
    delete!(aggDF, newcols)
    sort!(resDF, perSymb)
    return resDF
    # return resDF[[:perid, :VWsent, :VWret, :VWcov, :EWsent, :EWret, :EWcov]]
end
