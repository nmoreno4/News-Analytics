# using RCall, DataFrames, Statistics
# @rlibrary RPostgres
# @rlibrary DBI

# function FF_factors_download(daterange = ["01/01/2016", "12/31/2017"], datatable = "FACTORS_DAILY")
#     #or FACTORS_MONTHLY
#     @rput daterange
#     @rput datatable
#     R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
#                       host='wrds-pgdata.wharton.upenn.edu',
#                       port=9737,
#                       user='mlam',
#                       password='M@riel@mbertu193807',
#                       sslmode='require',
#                       dbname='wrds')"
#     R"res <- DBI::dbSendQuery(wrds, paste(\"SELECT * FROM\", datatable,
#                           \"WHERE date between '\", daterange[1], \"' and '\", daterange[2], \"'\"))"
#     R"FFfactors <- DBI::dbFetch(res, n=-1)"
#     R"DBI::dbClearResult(res)"
#     R"DBI::dbDisconnect(wrds)"
#     @rget FFfactors
#     return FFfactors
# end

using Statistics

exppen = x->1/exp(x)
#function to compute my custom spread. 1=>pos, 2=>neut, 3=>neg
spread = x-> (1-x[2])*(x[1]-x[3])
function rowmat2array(X)
    res = Any[]
    for row in 1:size(X,1)
        push!(res, Array{Float64,1}(X[row,:]))
    end
    return res
end


function meansumtakes_OLD(tdnews, myvars = ["pos", "neg", "neut", "sentClas", "subjects"])
    dicvars = [myvars; ["rel_$(var)" for var in myvars[1:end-1]]; ["novrel_$(var)" for var in myvars[1:end-1]]]
    storyvec =  Dict{String, Any}(zip(dicvars, [[] for x in dicvars]))
    storyvec["storyID"] = []
    storyvec["novrel_spread"], storyvec["rel_spread"], storyvec["spread"] = [], [], []
    for story in tdnews[2]
        push!(storyvec["novrel_spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')).*story[2]["relevance"].*exppen.(story[2]["Nov24H"]))
        push!(storyvec["rel_spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')).*story[2]["relevance"])
        push!(storyvec["spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')))
        push!(storyvec["subjects"],collect(Set(collect(Base.Iterators.Flatten(story[2]["subjects"])))))
        push!(storyvec["storyID"],story[1])
        for var in myvars
            if var != "subjects"
                push!(storyvec["$(var)"],story[2]["$(var)"])
                push!(storyvec["rel_$(var)"],story[2]["$(var)"].*story[2]["relevance"])
                push!(storyvec["novrel_$(var)"],story[2]["$(var)"].*story[2]["relevance"].*exppen.(story[2]["Nov24H"]))
            end
        end
    end
    storykeys = collect(keys(storyvec))
    for i in 1:length(storykeys)
        if storykeys[i] != "subjects" && storykeys[i] != "storyID"
            storyvec["mean_$(storykeys[i])"] = Float64[mean(vec) for vec in storyvec[storykeys[i]]]
            storyvec["sum_$(storykeys[i])"] = Float64[sum(vec) for vec in storyvec[storykeys[i]]]
        end
    end
    return storyvec
end


function meansumtakes(tdnews, myvars = ["pos", "neg", "neut", "sentClas", "subjects"], relthresh=90, novspan="3D")
    dicvars = [myvars; ["$(var)_merger" for var in myvars[1:end-1]]; ["$(var)_res" for var in myvars[1:end-1]];
                ["$(var)_rel$(relthresh)" for var in myvars[1:end-1]]; ["$(var)_rel$(relthresh)nov$(novspan)" for var in myvars[1:end-1]];
                ["$(var)_nov$(novspan)" for var in myvars[1:end-1]]; ["rel_$(var)" for var in myvars[1:end-1]];
                ["novrel_$(var)" for var in myvars[1:end-1]]]
    storyvec =  Dict{String, Any}(zip(dicvars, [[] for x in dicvars]))
    storyvec["storyID"] = String[]
    storyvec["novrel_spread"], storyvec["rel_spread"], storyvec["spread"] = [], [], []
    storyvec["spread_merger"], storyvec["spread_res"] = [], []
    storyvec["spread_rel$(relthresh)nov$(novspan)"], storyvec["spread_rel$(relthresh)"], storyvec["spread_nov$(novspan)"] = [], [], []
    dzielinski = Float64[]
    for story in tdnews[2]
        relidx = Int[]
        novidx = Int[]
        mergeridx = Int[]
        resultidx = Int[]
        for i in 1:length(story[2]["relevance"])
            if story[2]["relevance"][i]>relthresh/100
                push!(relidx, i)
            end
            if story[2]["Nov$(novspan)"][i]==0
                push!(novidx, i)
            end
            if "N2:RES" in story[2]["subjects"][i]
                push!(resultidx, i)
            end
            if "N2:MRG" in story[2]["subjects"][i]
                push!(mergeridx, i)
            end
            if story[2]["sentClas"][i] == 1 && story[2]["relevance"][i]>relthresh/100 && story[2]["Nov$(novspan)"][i]==0
                push!(dzielinski, 1*story[2]["pos"][i])
            elseif story[2]["sentClas"][i] == -1 && story[2]["relevance"][i]>relthresh/100 && story[2]["Nov$(novspan)"][i]==0
                push!(dzielinski, -1*story[2]["neg"][i])
            end
        end
        relnovidx = intersect(relidx, novidx)
        #
        push!(storyvec["novrel_spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')).*story[2]["relevance"].*exppen.(story[2]["Nov24H"]))
        push!(storyvec["rel_spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')).*story[2]["relevance"])
        push!(storyvec["spread"],spread.(rowmat2array([story[2]["pos"]';story[2]["neut"]';story[2]["neg"]']')))
        if length(relnovidx)>0
            push!(storyvec["spread_rel$(relthresh)nov$(novspan)"],spread.(rowmat2array([story[2]["pos"][relnovidx]';story[2]["neut"][relnovidx]';story[2]["neg"][relnovidx]']')))
        end
        if length(relidx)>0
            push!(storyvec["spread_rel$(relthresh)"],spread.(rowmat2array([story[2]["pos"][relidx]';story[2]["neut"][relidx]';story[2]["neg"][relidx]']')))
        end
        if length(novidx)>0
            push!(storyvec["spread_nov$(novspan)"],spread.(rowmat2array([story[2]["pos"][novidx]';story[2]["neut"][novidx]';story[2]["neg"][novidx]']')))
        end
        if length(mergeridx)>0
            push!(storyvec["spread_merger"],spread.(rowmat2array([story[2]["pos"][mergeridx]';story[2]["neut"][mergeridx]';story[2]["neg"][mergeridx]']')))
        end
        if length(resultidx)>0
            push!(storyvec["spread_res"],spread.(rowmat2array([story[2]["pos"][resultidx]';story[2]["neut"][resultidx]';story[2]["neg"][resultidx]']')))
        end
        push!(storyvec["subjects"],collect(Set(collect(Base.Iterators.Flatten(story[2]["subjects"])))))
        push!(storyvec["storyID"],story[1])
        for var in myvars
            if var != "subjects" && var != "spread_rel$(relthresh)nov$(novspan)" && var != "spread_rel$(relthresh)" && var != "spread_nov$(novspan)"
                push!(storyvec["$(var)"],story[2]["$(var)"])
                push!(storyvec["rel_$(var)"],story[2]["$(var)"].*story[2]["relevance"])
                push!(storyvec["novrel_$(var)"],story[2]["$(var)"].*story[2]["relevance"].*exppen.(story[2]["Nov24H"]))
                if length(relnovidx)>0
                    push!(storyvec["$(var)_rel$(relthresh)nov$(novspan)"],story[2]["$(var)"][relnovidx])
                end
                if length(relidx)>0
                    push!(storyvec["$(var)_rel$(relthresh)"],story[2]["$(var)"][relidx])
                end
                if length(novidx)>0
                    push!(storyvec["$(var)_nov$(novspan)"],story[2]["$(var)"][novidx])
                end
                if length(mergeridx)>0
                    push!(storyvec["$(var)_merger"],story[2]["$(var)"][mergeridx])
                end
                if length(resultidx)>0
                    push!(storyvec["$(var)_res"],story[2]["$(var)"][resultidx])
                end
            end
        end
    end
    if length(storyvec["spread_rel$(relthresh)"])==0
        for var in myvars
            delete!(storyvec, "$(var)_rel$(relthresh)")
        end
        delete!(storyvec, "spread_rel$(relthresh)")
    end
    if length(storyvec["spread_nov$(novspan)"])==0
        for var in myvars
            delete!(storyvec, "$(var)_nov$(novspan)")
        end
        delete!(storyvec, "spread_nov$(novspan)")
    end
    if length(storyvec["spread_rel$(relthresh)nov$(novspan)"])==0
        for var in myvars
            delete!(storyvec, "$(var)_rel$(relthresh)nov$(novspan)")
        end
        delete!(storyvec, "spread_rel$(relthresh)nov$(novspan)")
    end
    if length(storyvec["spread_merger"])==0
        for var in myvars
            delete!(storyvec, "$(var)_merger")
        end
        delete!(storyvec, "spread_merger")
    end
    if length(storyvec["spread_res"])==0
        for var in myvars
            delete!(storyvec, "$(var)_res")
        end
        delete!(storyvec, "spread_res")
    end
    storykeys = collect(keys(storyvec))
    for i in 1:length(storykeys)
        if storykeys[i] != "subjects" && storykeys[i] != "storyID"
            storyvec["mean_$(storykeys[i])"] = Float64[mean(vec) for vec in storyvec[storykeys[i]] if length(vec)>0]
            storyvec["sum_$(storykeys[i])"] = Float64[sum(vec) for vec in storyvec[storykeys[i]] if length(vec)>0]
        end
    end
    storyvec["dzielinski_rel$(relthresh)nov$(novspan)"] = sum(dzielinski)
    return storyvec
end


function tuplerize(X)
    X = Array{Any}(X)
    for i in 1:length(X)
        X[i] = tuple(X[i]...)
    end
    return X
end



function splitDic(mydic, n=10)
    res = (Dict(zip(1:n, [[] for x in 1:n])))
    i = 1
    for entry in mydic
        push!(res[i], entry)
        if i == n
            i=1
        else
            i+=1
        end
    end
    return res
end





# tdnews = ResultDic[4295860884][210]
# story = tdnews["210-nTOR294110"]
#
# @time for posel in story["pos"]
#     push!(sumpos, posel)
# end
#
# X = storyvec["pos"]
# @time meanX = [sum(vec) for vec in X]
#
# using JLD2, Statistics
# JLD2.@load "/home/nicolas/Data/Intermediate/tdnews.jld2"
# storyvec = Dict(zip(myvars, [[] for x in myvars]))
# for story in tdnews
#     for var in myvars
#         push!(storyvec["$(var)"],story[2]["$(var)"])
#     end
# end
# isequal(Dict("pos"=>[], "neg"=>[]),Dict(zip(myvars, repeat(Any[[]],length(myvars)))))
