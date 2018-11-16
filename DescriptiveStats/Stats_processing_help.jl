using DataFrames, RCall

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
            push!(ts, custom_mean_missing(dicDF[ptf][row,:]))
        end
        if ptf==1
            X = ts
        else
            X = hcat(X, ts)
        end
    end
    return X
end


function timmerman(X)
    #Use 10/6/3/2 as the block length if data is measured in daily/monthly/quarterly/annual returns.
    @rput X
    R"library(monotonicity)"
    R"Y = monoRelation(X, bootstrap = 1000, increasing=T, difference = F, 3)"
    @rget Y
    return Y
end
