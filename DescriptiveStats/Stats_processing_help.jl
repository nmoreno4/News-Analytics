using DataFrames, RCall, DataFramesMeta, RollingFunctions, ShiftedArrays

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
    return Symbol("$(res[2])_$(res[3])_$(res[1])")
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
            if occursin("Nb", String(var)) #I want to put zeros on days w no news
                res[Symbol("mean_$(var)")] = mean(replace(df[var], missing=>0))
            else
                res[Symbol("mean_$(var)")] = custom_mean_missing(df[var])
            end
        end
        DataFrame(res)
    end
    return a
end

function colmeans_to_dic(a)
    res = Dict()
    for i in names(a)
        if i != :permno
            if occursin("Nb", String(i)) #I want to put zeros on days w no news
                res[i] = mean(replace(a[i], missing=>0))
            else
                res[i] = custom_mean_missing(a[i])
            end
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
        a = ptfDF[vars[i]]
        replace!(a, NaN=>missing)
        a = collect(skipmissing(a))
        res[:,i] = percentile(a, 1:100)
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




function HMLspreads(HMLDic, chosenvars, ws="VW", surprises=false)
    HMLids = [(x,y) for x in [(1,3), (8,10), (4,7)] for y in [(1,5), (6,10)]]

    w_vars = [Symbol("w_$(x)") for x in chosenvars]
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

    if surprises
        res[:surpHML_ALL_RES_60_5] = surpriseSeriesHML(60,5,res[:HML_VW_aggSent_], res[:HML_VW_aggSent_RES])
        res[:surpHML_ALL_RES_20_5] = surpriseSeriesHML(20,5,res[:HML_VW_aggSent_], res[:HML_VW_aggSent_RES])
        res[:surpHML_ALL_RES_60_2] = surpriseSeriesHML(60,2,res[:HML_VW_aggSent_], res[:HML_VW_aggSent_RES])
        res[:surpHML_ALL_RES_20_2] = surpriseSeriesHML(20,2,res[:HML_VW_aggSent_], res[:HML_VW_aggSent_RES])
        res[:surpHML_ALL_RES_60_10] = surpriseSeriesHML(60,10,res[:HML_VW_aggSent_], res[:HML_VW_aggSent_RES])
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


function concat_groupInvariant_vars(c, regDF, firstnew)
    #c is my "raw" DataFrame, regDF is my DataFrame with group-invariant data (e.g. HML spreads, RF, Baker sent, etc...)
    for i in names(regDF)
        c[i] = 0
    end
    @time for i in names(c)
        c[i] = convert(Array{Union{Float64,Missing}}, c[i])
    end
    for row in 1:size(c,1)
        c[row,firstnew:end] = regDF[Int(c[row,:perid]),:]
        if row in [10000,1000000,5000000,10000000]
            print(row)
        end
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



function createPanelDF(ptfDF, HMLDic; runninglags = [250,60,20,5], HMLvars = [:sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES], ptfvars = [:cumret, :aggSent_], tdperiods = (1,3776), surprises = true)
    @time HMLnico = HMLspreads(HMLDic, HMLvars, "VW", surprises)
    FFfactors = loadFFfactors()
    HMLnico[:HML_VW_cumret] = HMLnico[:HML_VW_cumret] .- FFfactors[:RF]
    HMLnico = DataFrame(HMLnico)
    for i in names(HMLnico)
        @time for lag in runninglags
            chosenfct = custom_mean
            if String(i)[end-2:end]=="ret"
                chosenfct = cumret
            end
            HMLnico[Symbol("$(i)_l$(lag)")] = running(chosenfct, HMLnico[i], lag)
        end
    end
    groupInvariants = hcat(FFfactors, HMLnico)

    stackDF = ptfDF[[ptfvars; [:perid, :permno, :wt]]]
    firstnew = size(stackDF, 2)
    print("VWseries")
    ptfSpecific = @time EW_VW_series(ptfDF, [Symbol("ptf_$x") for x in ptfvars], ptfvars)
    ptfSpecific = @time daysWNOead(tdperiods, ptfSpecific, names(ptfSpecific))
    delete!(ptfSpecific, [:perid])
    delete!(stackDF, [:wt])
    names!(ptfSpecific, [Symbol("ptf_$(x)") for x in names(ptfSpecific)])
    groupInvariants = hcat(FFfactors, convert(DataFrame, HMLnico), ptfSpecific)
    delete!(groupInvariants, :Date)
    print("hey")
    stackDF = @time excessRet(stackDF, [:cumret], groupInvariants[:RF])
    paneldf = @time concat_groupInvariant_vars(stackDF, groupInvariants, firstnew)

    return paneldf
end



function createPanelDFsurprise(ptfDF, HMLnico, Mktnico; runninglags = [250,60,20,5], HMLvars = [:sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES], ptfvars = [:cumret, :aggSent_], tdperiods = (1,3776), surprises = true)
    FFfactors = loadFFfactors()
    HMLnico[:HML_VW_cumret] = HMLnico[:HML_VW_cumret] .- FFfactors[:RF]
    HMLnico = DataFrame(HMLnico)
    for i in names(HMLnico)
        @time for lag in runninglags
            chosenfct = custom_mean
            if String(i)[end-2:end]=="ret"
                chosenfct = cumret
            end
            HMLnico[Symbol("$(i)_l$(lag)")] = running(chosenfct, HMLnico[i], lag)
        end
    end
    groupInvariants = hcat(FFfactors, HMLnico, DataFrame(Mktnico))

    stackDF = ptfDF[[ptfvars; [:perid, :permno, :wt]]]
    firstnew = size(stackDF, 2)
    print("VWseries")
    ptfSpecific = @time EW_VW_series(ptfDF, [Symbol("ptf_$x") for x in ptfvars], ptfvars)
    ptfSpecific = @time daysWNOead(tdperiods, ptfSpecific, names(ptfSpecific))
    delete!(ptfSpecific, [:perid])
    delete!(stackDF, [:wt])
    names!(ptfSpecific, [Symbol("ptf_$(x)") for x in names(ptfSpecific)])
    groupInvariants = hcat(groupInvariants, ptfSpecific)
    delete!(groupInvariants, :Date)
    print("hey")
    stackDF = @time excessRet(stackDF, [:cumret], groupInvariants[:RF])
    paneldf = @time concat_groupInvariant_vars(stackDF, groupInvariants, firstnew)

    return paneldf
end





function panelReg(a)
    regfactors = [String(x) for x in names(a)]
    @rput regfactors
    R"regspec <- as.formula(paste(paste(regfactors[3], '~', sep=''), paste(regfactors[4:length(regfactors)], collapse='+')))"
    @rput a
    R"library(plm)"
    R"E <- pdata.frame(a, index=c('permno', 'perid'))"
    try
        R"mod <- plm(regspec, data = E, model = 'within')"
    catch
        R"mod <- plm(regspec, data = E, model = 'within')"
    end
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



function createdoublesort(ptfDF, cvar1 = Symbol("aggSent__-5_-1"), cvar2 = Symbol("aggSent__-60_-1"))
    ptfDF = buckets_assign(ptfDF, cvar1, 10:10:100)
    ptfDF = buckets_assign(ptfDF, cvar2, 10:10:100)
    ptfDF[:doublefreqsort] = 0
    for row in 1:size(ptfDF,1)
        if ptfDF[Symbol("$(cvar1)_bucket")][row]<=5 && ptfDF[Symbol("$(cvar2)_bucket")][row]<=5
            ptfDF[:doublefreqsort][row] = 1
        elseif ptfDF[Symbol("$(cvar1)_bucket")][row]<=5 && ptfDF[Symbol("$(cvar2)_bucket")][row]>5
            ptfDF[:doublefreqsort][row] = 2
        elseif ptfDF[Symbol("$(cvar1)_bucket")][row]>5 && ptfDF[Symbol("$(cvar2)_bucket")][row]<=5
            ptfDF[:doublefreqsort][row] = 3
        elseif ptfDF[Symbol("$(cvar1)_bucket")][row]>5 && ptfDF[Symbol("$(cvar2)_bucket")][row]>5
            ptfDF[:doublefreqsort][row] = 4
        end
    end
    return ptfDF
end



function regToCsv(rowvar, resdic, depvars, eadchoice, ds, sousdic)
    resmat = ones(Float64, 10,10)
    for i in resdic
        id = i[1]
        # val, sz = parse(Int, "$id"[1]), parse(Int, "$id"[2])
        sz, val = id[1], id[2]
        try
            resmat[val,sz] = i[2][sousdic][:coefficients][rowvar,Symbol("t-value")]
        catch
            print("key $sousdic missing")
        end
    end
    CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/regs/$(eadchoice)/ds_$(ds)_r$(rowvar)_$(depvars).csv", DataFrame(resmat))
end

























function computemeans(aggDicFreq, quintileids, resWead, eads, varsformeans, pastsentTopicClass = true, dsspan=0:4)
    for id in quintileids
        print("PTF: $id \n")
        val, sz = parse(Int, "$id"[1]), parse(Int, "$id"[2])
        ptfDF = copy(aggDicFreq[id])
        ptfDF = keepgoodcolumns(ptfDF, ["", "RES", "CMPNY", "MRG", "RESF"])
        ptfDF[:everyEAD] = 1
        ptfDF[:aggSent_CMPNY] = ptfDF[:sum_perSent_CMPNY] ./ ptfDF[:sum_perNbStories_CMPNY]
        ptfDF[:aggSent_MRG] = ptfDF[:sum_perSent_MRG] ./ ptfDF[:sum_perNbStories_MRG]
        ptfDF[:aggSent_RESF] = ptfDF[:sum_perSent_RESF] ./ ptfDF[:sum_perNbStories_RESF]

        namesWNOminus = [Symbol(replace(replace(replace(String(x), "t_-"=>"t__-"), "-"=>"m"), "ret_"=>"cumret_")) for x in names(ptfDF)]
        names!(ptfDF, namesWNOminus)


        for top in pastsentTopicClass
            print("pastsentTopicClass: $top \n")
            ptfDF = createdoublesort(ptfDF, Symbol("aggSent_$(top)_m5_m1"), Symbol("aggSent_$(top)_m60_m1"))
            # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m20_m1"), 10:10:100)
            # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m60_m1"), 10:10:100)
            # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m120_m1"), 10:10:100)


            for ds in dsspan
                resWead = @time meansdsspan(resWead, ptfDF, ds, eads, varsformeans, sz, val)
            end #for ds
        end
    end
    return resWead
end



function meansdsspan(resWead, ptfDF, ds, ead, varsformeans, sz, val)
    if ds==0
        provbuckfDF = ptfDF
    else
        provbuckfDF = ptfDF[ptfDF[:doublefreqsort].==ds,:]
    end
    for ead in eads
        provbuckfDF[ead] = replace(provbuckfDF[ead], missing=>0)
        provtfDF = provbuckfDF[provbuckfDF[ead].==1,:]
        for i in varsformeans
            # if i == :cumret
            #     provtfDF = provtfDF[provtfDF[:doublefreqsort].>0,:]
            # end
            try
                means_stock_sent = by_means(provtfDF, [i], :permno)
                resWead[ead][ds][i][val,sz] = colmeans_to_dic(means_stock_sent)[Symbol("mean_$(i)")]
                quintile = val*10+sz
                if !(quintile in keys(resmats["series_$(i)"]))
                    resWead[ead][ds]["series_$(i)"][quintile] = Dict()
                end
                resWead[ead][ds]["series_$(i)"][quintile] = means_stock_sent[Symbol("mean_$(i)")]
            catch crterror
                # print("$ds $i $ead \n")
                # print("$(by_means(provtfDF, [i], :permno))")
                # for i in names(means_stock_sent)
                #     print("\n$i    ")
                # end
                # error(crterror)
                push!(provtfDF, zeros(size(provtfDF,2))) #Array{Union{Missing, Float64},1}(missing,size(provtfDF,2))
                means_stock_sent = by_means(provtfDF, [i], :permno)
                resWead[ead][ds][i][val,sz] = colmeans_to_dic(means_stock_sent)[Symbol("mean_$(i)")]
                quintile = val*10+sz
                if !(quintile in keys(resmats["series_$(i)"]))
                    resWead[ead][ds]["series_$(i)"][quintile] = Dict()
                end
                resWead[ead][ds]["series_$(i)"][quintile] = means_stock_sent[Symbol("mean_$(i)")]
            end
        end
    end
    return resWead
end














function savetimmermann(resWead)
    dfs = Dict()
    for ead in resWead
        try
            size(dfs[ead[1]])
        catch
            dfs[ead[1]] = Dict()
        end
        for ds in ead[2]
            try
                size(dfs[ead[1]][ds[1]])
            catch
                dfs[ead[1]][ds[1]] = Dict()
            end
            for result in ds[2]
                try
                    size(dfs[ead[1]][ds[1]][result[1]])
                catch
                    dfs[ead[1]][ds[1]][result[1]] = Dict()
                end
                if typeof(result[1])==Symbol
                    dfs[ead[1]][ds[1]][result[1]]["5x5"] = result[2]
                else
                    X = ptfEWmean(result[2])
                    @time MR = timmerman(X, 2)
                    dfs[ead[1]][ds[1]][result[1]]["timm"] = MR
                end
            end
        end
    end
    return dfs
end





function addtstats(a, b, var=0)
    szpairs = ([11,15], [21,25], [31,35], [41,45], [51,55])
    valpairs = ([11,51], [12,52], [13,53], [14,54], [15,55])
    for ptfpairs in (szpairs, valpairs)
        res = Union{Missing,Float64}[]
        for i in 1:length(ptfpairs)
            if length(a)==2
                try
                    v1 = replace(a[1][ptfpairs[i][1]] .- a[2][ptfpairs[i][1]], missing=>0)
                    v2 = replace(a[1][ptfpairs[i][2]] .- a[2][ptfpairs[i][2]], missing=>0)
                catch
                    foo = a[1][ptfpairs[i][1]]
                    bar = a[2][ptfpairs[i][1]]
                    commonlength = minimum([length(foo), length(bar)])
                    v1 = replace(foo[1:commonlength] .- bar[1:commonlength], missing=>0)
                    foo = a[1][ptfpairs[i][2]]
                    bar = a[2][ptfpairs[i][2]]
                    commonlength = minimum([length(foo), length(bar)])
                    v2 = replace(foo[1:commonlength] .- bar[1:commonlength], missing=>0)
                end
            else
                v1 = replace(a[ptfpairs[i][1]], missing=>0)
                v2 = replace(a[ptfpairs[i][2]], missing=>0)
            end
            if length(v1)==0
                print(length(a))
            end
            push!(res, Rttest(v1, v2))
        end
        if ptfpairs[1] == [11,15]
            b = hcat(b, res)
        else
            b = vcat(b, [res;missing]')
        end
    end
    return b
end



function Rttest(x, y)
    try
        @rput x ; @rput y
        R"library(ggpubr)"
        R"a = t.test(x, y)$statistic"
        @rget a
        return a
    catch
        return missing
    end
end



function concatspecststats(spec, varsformeans)
    res = []
    for i in varsformeans
        mat = spec[i]
        ser = spec["series_$(i)"]
        matWtstat = addtstats(ser,mat)
        if res==[]
            res = matWtstat
        else
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, matWtstat)
        end
    end
    return res
end



function concatspecststatsDiffs(spec1, spec2, varsformeans)
    res = []
    for i in varsformeans
        mat = spec1[i] .- spec2[i]
        ser = (spec1["series_$(i)"], spec2["series_$(i)"])
        matWtstat = addtstats(ser,mat, i)
        if res==[]
            res = matWtstat
        else
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, matWtstat)
        end
    end
    return res
end




function concatspecststatsDiffsTopics(spec, varsformeans, reftopic)
    res = []
    for i in varsformeans
        mat = spec[i] .- spec[reftopic]
        ser = (spec["series_$(i)"], spec["series_$(reftopic)"])
        matWtstat = addtstats(ser,mat)
        if res==[]
            res = matWtstat
        else
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, convert(Array{Union{Float64,Missing}}, ones(6)).*missing)
            res = hcat(res, matWtstat)
        end
    end
    return res
end



function surpriseSeriesDF(ptfDF, LTwindow, STwindow, LTvar, STvar)
    LTsent = replace(running(custom_sum, ptfDF[LTvar[1]], LTwindow) ./ running(custom_sum,ptfDF[LTvar[2]], LTwindow), NaN=>missing)
    STsent = replace(running(custom_sum, ptfDF[STvar[1]], STwindow) ./ running(custom_sum,ptfDF[STvar[2]], STwindow), NaN=>missing)
    res = STsent .- LTsent
    return res
end

function surpriseSeriesHML(LTwindow, STwindow, LTvar, STvar)
    LTsent = replace(running(custom_mean, LTvar, LTwindow), NaN=>missing)
    STsent = replace(running(custom_mean, STvar, STwindow), NaN=>missing)
    res = STsent .- LTsent
    return res
end



function fillmissing(cdf, tdsymb, valsymb, tdperiods)
    b = Array{Union{Float64,Missing}}(missing, tdperiods[2]-tdperiods[1]+1)
    for i in 1:size(cdf,1)
        b[Int(cdf[i,tdsymb])] = cdf[i,valsymb]
    end
    return b
end




function computesurprises(ptfDF, vars, windows)
    @time a = by(ptfDF, :permno) do df
        res = Dict()
        tokeep = df[:perid]
        for var in vars
            LTvar, STvar = var[1], var[2]
            for win in windows
                LTwindow, STwindow = win[1], win[2]
                if excluderecent
                    LTwVec = ones(Union{Float64}, LTwindow)
                    LTwVec[end-STwindow+1:end] .= 0
                else
                    LTwVec = ones(Union{Float64}, LTwindow)
                end
                A = fillmissing(df, :perid, LTvar[1], tdperiods)
                B = fillmissing(df, :perid, LTvar[2], tdperiods)
                LTsent = replace(running(custom_sum, A, LTwindow, LTwVec) ./ running(custom_sum,B, LTwindow, LTwVec), NaN=>missing)
                A = fillmissing(df, :perid, STvar[1], tdperiods)
                B = fillmissing(df, :perid, STvar[2], tdperiods)
                STsent = replace(running(custom_sum, A, STwindow) ./ running(custom_sum,B, STwindow), NaN=>missing)
                res[Symbol("$(var)_$(win)")] = LTsent[tokeep] .- STsent[tokeep]
            end
        end
        res[:bmdecile] = df[:bmdecile]
        res[:sizedecile] = df[:sizedecile]
        DataFrame(res)
    end
    return a
end



function marketSurprises(ptfDF, LTspecs, STspecs, ws)
    allvars = []
    for cspecs in (LTspecs, STspecs)
        for (x,y) in cspecs
            push!(allvars, y)
        end
    end
    ptfvars = Set(allvars)
    prov = EW_VW_series(ptfDF, [Symbol("mkt_$x") for x in ptfvars], ptfvars)
    mktsurprises = Dict()
    for (LTspec,STspec) in zip(LTspecs, STspecs)
        LTwindow, STwindow = LTspec[1], STspec[1]
        LTvar, STvar =  LTspec[2], STspec[2]
        LTwVec = ones(Union{Float64}, LTwindow)
        LTwVec[end-STwindow+1:end] .= 0
        LTnews = running(custom_mean, convert(Array{Union{Float64,Missing}}, prov[Symbol("$(ws)_$(LTvar)")]), LTwindow, LTwVec)
        STnews = running(custom_mean, convert(Array{Union{Float64,Missing}}, prov[Symbol("$(ws)_$(STvar)")]), STwindow)
        mktsurprises[Symbol("LT$(LTwindow)|$(LTvar)_ST$(STwindow)|$(STvar)")] = replace(LTnews .- STnews, NaN=>missing)
    end
    return mktsurprises
end




function lagbypermno(ptfDF, lagvars, lagspans)
    print("Did you sort the DF by [:permno, :perid] ???")
    @time a = by(ptfDF, :permno) do df
        res = Dict()
        for var in lagvars
            for span in lagspans
                res[Symbol("$(var)_l$(span)")] = lag(df[var], span)
            end
        end
        DataFrame(res)
    end
    return hcat(ptfDF, a)
end


function mktretbypermno(ptfDF, lagvars, lagspans, type = "lead")
    print("Did you sort the DF by [:permno, :perid] ???")
    @time a = by(ptfDF, :permno) do df
        res = Dict()
        for var in lagvars
            for span in lagspans
                a = running(cumret, df[var], span)
                if type == "lead"
                    res[Symbol("$(var)_$(type)$(span)")] = lead(a, span)
                elseif type == "lag"
                    res[Symbol("$(var)_$(type)$(span)")] = lead(a, span)
                end
            end
        end
        DataFrame(res)
    end
    return hcat(ptfDF, a)
end
