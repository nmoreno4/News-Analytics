module DFmanipulation
using DataFrames
export deletemissingrows!

function deletemissingrows!(df, var, misstype = "missing")
    rowstodelete = Int[]
    cc=0
    for row in eachrow(df)
        cc+=1
        if misstype == "missing"
            if ismissing(row[var])
                push!(rowstodelete, cc)
            end
        elseif misstype == "NaN"
            if isnan(row[var])
                push!(rowstodelete, cc)
            end
        end
    end
    deleterows!(df, rowstodelete)
end

end #module
