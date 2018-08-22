module keeponekind

using DataFrames
export keeponlyptf
# keep only value or growth stocks
function keeponlyptf(df, rank="value")
    col = 0
    if rank=="value"
        col = :isvalue
    elseif rank=="growth"
        col = :isgrowth
    end
    tokeep = find(x->x==1, df[col])
    return df[tokeep,:]
end

end#module
