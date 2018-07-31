module DFmanipulation
using DataFrames
export deletemissingrows!

function deletemissingrows!(df, var)
    rowstodelete = Int[]
    cc=0
    for row in eachrow(df)
        cc+=1
        if ismissing(row[var])
            push!(rowstodelete, cc)
        end
    end
    deleterows!(df, rowstodelete)
end

end #module
