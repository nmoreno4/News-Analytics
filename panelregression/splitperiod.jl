module splitperiod
using CSV, DataFrames

export removetdrows

# df = CSV.read("/home/nicolas/Data/Intermediate/$(dftoloadname)_extended.csv")

# windowlength=20

function removetdrows(df, windowlength)
    df[:dchange]=0
    function intermed_removetdrows(a, wl=windowlength)
        a[:dchange] = [0;a[:td][2:end]-a[:td][1:end-1]]
        # print("$(maximum(a[:dchange]))\n")
        subdfs = []
        prevind = 1
        for i in find(x -> x .> 1,a[:dchange])
            push!(subdfs, a[prevind:i,:])
            prevind = i
        end
        push!(subdfs, a[prevind:end,:])
        pastadd = 0
        toremove=Int[]
        for subdf in subdfs
            append!(toremove, find(x->x%wl!=1, 1:size(subdf,1)).+pastadd)
            pastadd+=size(subdf,1)-1
        end
        a = Array{Any}(a)
        a = DataFrames.DataFrame(a)
        deleterows!(a, toremove)
    end
    b = by(df, :permno, intermed_removetdrows)
    delete!(b, :permno)
    names!(b,names(df))
    return b
end

end #module
