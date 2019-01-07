module FindFcts
using DataFrames

export isin_IDX, notIn, isin_IDX_old, filterSubDfSum, deleteMissingRows



"""
    filterSubDfSum(data::DataFrame, X::Symbol, Y::Symbol, thresh::Number, showrejected::Bool=true)

### Description
Deletes all entries in *data* for a value of *X* (e.g. a permno) where the sum
of the *Y* for the subdataframe of *X* is above *thresh*.

### Arguments
- `data::DataFrame`: A DataFrame containing at least a column named *:X* and another named *:Y*.
- `X::Symbol`: a Symbol for the column on which to make subDataframes.
- `Y::Symbol`: a Symbol for the column requering a to reach thresh by each subdataframe.
- `thresh::Number`: The threshold for the sum to reach.
- ` showrejected::Bool=false`: True if you want to compute and return the list of X that were rejected.

### Returns
- `filteredData::DataFrame` : The dataframe where all X have a sum of Y exceeding thresh.
"""
function filterSubDfSum(data::DataFrame, X::Symbol, Y::Symbol, thresh::Number, showrejected::Bool=false)
    subDFsum = by(data, X) do cdf
        sum(cdf[Y])
    end
    chosenX = subDFsum[subDFsum[:x1].>0,X]
    if showrejected
        rejectedX = subDFsum[subDFsum[:x1].<=0,X]
    end
    filteredData = data[isin_IDX(data, X, convert(Array{Float64}, chosenX)),:]
    if showrejected
        return filteredData, chosenX, rejectedX
    else
        return filteredData
    end
end







"""
    isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray{<:Number,1})

### Description
Looks for all elements of the *:var* column in *crtDF* that are included in
the Array *coll*. Returns the indexes of matches.

### Arguments
- `crtDF::DataFrame`: A DataFrame containing at least a column named *:var*.
- `var::Symbol`: a Symbol for the column where to look for matches.
- `coll::AbstractArray`: An Array of Numbers to find from.

### Returns
- `indexer::AbstractArray{Int,1}` : The indexes where the value *crtDF[:var]* is in *coll*
"""
function isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray{<:Number,1})::AbstractArray{Int,1}
    if length(coll)>length(Set(coll))
        error("Non-unique coll elements provided")
    end
    print("\n$(length(coll))\n")
    indexer = Array{Int,1}(undef,length(crtDF[var])).*0
    crtDF[:idx] = 1:size(crtDF,1)
    crtDF = crtDF[[var, :idx]]
    sort!(crtDF, var)
    sort!(coll)
    i = 1
    idx = 0
    for row in 1:length(crtDF[var])
        if crtDF[row,var] > coll[i]
            i+=1 # Make sure I compare to the right element in the collection
        end
        if i>length(coll)
            break
        end
        if crtDF[row,var] == coll[i] # If I have a match, add to the list of desired indexes
            idx+=1
            indexer[idx] = crtDF[row,:idx]
        end
    end #for row in DF
    indexer = indexer[1:idx]
    if 0 in indexer
        error("A match was not assigned an index!")
    end
    return indexer
end


"""
    isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray{<:Union{Symbol,String},1})

### Description
Looks for all elements of the *:var* column in *crtDF* that are included in
the Array *coll*. Returns the indexes of matches. To do so it gives a unique index
to the elements of coll which can be sorted on.

### Arguments
- `crtDF::DataFrame`: A DataFrame containing at least a column named *:var*.
- `var::Symbol`: a Symbol for the column where to look for matches.
- `coll::AbstractArray`: An Array of Symbols or Strings to find from.

### Returns
- `indexer::AbstractArray{Int,1}` : The indexes where the value *crtDF[:var]* is in *coll*

#### WARNING : Currently not functional with strings/symbols in *coll*
"""
function isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray{<:Union{Symbol,String},1})::AbstractArray{Int,1}
    error("This function is not ready yet: I need to adjust the sortMap part where I map
           crtDF[:var] elements to the corresponding indexes in coll.")
    if length(coll)>length(Set(coll))
        error("Non-unique coll elements provided")
    end
    indexer = Array{Int,1}(undef,length(intersect(crtDF[var], coll))).*0
    crtDF[:idx] = 1:size(crtDF,1)
    crtDF = crtDF[[var, :idx]]
    crtDF[:sortMap] = 0
    for i in 1:size(crtDF,1)
        crtDF[:sortMap] = findall()
    end
    sort!(crtDF, var)
    sort!(coll)
    i = 1
    idx = 0
    for row in 1:length(crtDF[var])
        if crtDF[row,var] > coll[i]
            i+=1 # Make sure I compare to the right element in the collection
        end
        if crtDF[row,var] == coll[i] # If I have a match, add to the list of desired indexes
            idx+=1
            indexer[idx] = crtDF[row,:idx]
        end
    end #for row in DF
    if 0 in indexer
        error("A match was not assigned an index!")
    end
    return indexer
end


function isin_IDX_old(crtDF::DataFrame, var::Symbol, coll::AbstractArray)::AbstractArray
    indexer = BitArray(undef,size(crtDF,1))
    for i in 1:length(crtDF[var])
        indexer[i] = crtDF[var][i] in coll
    end
    return indexer
end

function notIn(notin::AbstractArray, onlyin::AbstractArray)
    return filter(x -> x ∉ notin, onlyin)
end


"""
First argument is the DataFrame.
All following arguments are colums where to look for missing values.
Delete the whole row if one of the columns has a missing value.
"""
function deleteMissingRows(xdf, vCol...)
    for col in vCol
        xdf = xdf[findall(.!ismissing.(xdf[col])),:]
    end
    return xdf
end



end #module
