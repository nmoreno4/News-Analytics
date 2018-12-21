module FindFcts
using DataFrames

export isin_IDX, notIn

"""
    isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray)

### Description
Looks for all elements of the *:var* column in *crtDF* that are included in
the Array *coll*. Returns the indexes of matches.

### Arguments
- `crtDF::DataFrame`: A DataFrame containing at least a column named *:var*.
- `var::Symbol`: a Symbol for the column where to look for matches.
- `coll::AbstractArray`: An Array of stuff to find from.
"""
function isin_IDX(crtDF::DataFrame, var::Symbol, coll::AbstractArray)
    indexer = BitArray(undef,size(crtDF,1))
    @time for i in 1:length(crtDF[var])
        indexer[i] = crtDF[var][i] in coll
    end
    return indexer
end


function isinIDX2(crtDF, var, coll)
    idxtokeep = Int[]
    for permno in coll
        append!(idxtokeep, findall(x->x==permno, coll))
    end
    return idxtokeep
end

function notIn(notin, onlyin)
    return filter(x -> x ∉ notin, onlyin)
end


end #module
