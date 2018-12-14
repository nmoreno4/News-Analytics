using Distributed


@everywhere function VWeight(v, namestoVW)
    # res = Dict()
    # v = v[isnotmissing.(v[:cumret]),:]
    # v = v[isnotmissing.(v[:wt]),:]
    totweight = sum(v[:wt])
    stockweight = v[:wt] ./ totweight
    return sum(v[namestoVW] .* stockweight)
end

@everywhere function EWeight(v, namestoVW)
    res = Dict()
    # v = v[isnotmissing.(v[:cumret]),:]
    # v = v[isnotmissing.(v[:wt]),:]
    totweight = custom_sum(v[:wt])
    stockweight = custom_mean(v[:wt]) ./ totweight
    return custom_sum(v[namestoVW] .* stockweight)
end

function custom_mean(X, retval=1)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==1
        return retval
    else
        return mean(collect(skipmissing(X)))
    end
end

function isnotmissing(x)
    return !ismissing(x)
end

function custom_sum(X, retval=0)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==0
        return retval
    else
        return sum(collect(skipmissing(X)))
    end
end


function mysimdiff(X,Y)
    b = zeros(length(X))
    b[Y] .= 1
    a = ones(length(X)) .- b
    return convert(Array{Bool}, a)
end


@everywhere function submatrixIdx(stocklist, permnosIDs)
    idxstokeep = Int[]
    for stock in stocklist
        if stock in keys(permnosIDs)
            append!(idxstokeep, permnosIDs[stock])
        end
    end
    return idxstokeep
end



"""
Sometimes I'd want to have just all the stock's IDs, for instance when I filter by period for example.
I can also filter to get all observations of a stock where it gets news.
"""
function valueFilterIdxs(valtofilt, filternewsdays, data)

    permnolist = sort(collect(Set(data[valtofilt])))
    permnoIDs = Dict()

    for permno in permnolist
        permnoIDs[permno] = Int[]
    end

    for row in 1:size(data, 1)
        if filternewsdays
            if data[row,:sum_perNbStories_]>0
                push!(permnoIDs[data[row,valtofilt]], row)
            end
        else
            push!(permnoIDs[data[row,valtofilt]], row)
        end
    end

    return permnoIDs
end



"""
returns ranges (i.e. indices to split the data).
"""
function partition_array_indices(nb_data::Int, nb_data_per_chunk::Int)
    nb_chunks = ceil(Int, nb_data / nb_data_per_chunk)
    ids = UnitRange{Int}[]
    for which_chunk = 1:nb_chunks
        id_start::Int = 1 + nb_data_per_chunk * (which_chunk - 1)
        id_end::Int = id_start - 1 + nb_data_per_chunk
        if id_end > nb_data
            id_end = nb_data
        end
        push!(ids, id_start:id_end)
    end
    return ids
end




function initialPopulation(permnosIDs, nBuckets)
    allstocks = collect(keys(permnosIDs))
    allstocks = allstocks[randperm(length(allstocks))]
    split_ranges = partition_array_indices(length(allstocks),Int(ceil(length(allstocks)/nBuckets)))
    Population = Dict()
    for i in 1:length(split_ranges)
        Population[i] = allstocks[split_ranges[i]]
    end
    return Population
end




@everywhere function filtercrtDF(crtstocks, permnosIDs, dataDF, LeftOverMarket)
    ptfidxs = submatrixIdx(crtstocks, permnosIDs);
    ptfdf = dataDF[ptfidxs,:];
    if LeftOverMarket
        complementaryidxs = symdiff(1:size(dataDF,1), ptfidxs);
        mktdf = dataDF[complementaryidxs,:];
    else
        mktdf = dataDF
    end;
    return ptfdf, mktdf
end
