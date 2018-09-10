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


function meansumtakes(tdnews, myvars = ["pos", "neg", "neut", "sentClas", "subjects"])
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
