function cumcount(X)
    res = Array{Int}(length(X))
    for i = 1:length(X)
        res[i] = i-1
    end
    return res
end
function mylag(X, l)
    # print(X)
    return [X[1+l:end]; Array{Float64}(l)*NaN64]
end
function coalesceJuliaDB(t, vcols; idgroup=:gvkey, default=NaN)
    if length(vcols)==2
        b = JuliaDB.groupby(@NT(z-> mycoalesce(columns(z, vcols[1]), columns(z, vcols[2]); default=0) ),
            t, idgroup, select=vcols, flatten=true)
    elseif length(vcols)==3
        b = JuliaDB.groupby(@NT(z-> mycoalesce(columns(z, vcols[1]), columns(z, vcols[2]),
            columns(z, vcols[3]); default=0) ),t, idgroup, select=vcols, flatten=true)
    elseif length(vcols)==4
        b = JuliaDB.groupby(@NT(z-> mycoalesce(columns(z, vcols[1]), columns(z, vcols[2]),
            columns(z, vcols[3]), columns(z, vcols[4]); default=0) ),t, idgroup, select=vcols, flatten=true)
    elseif length(vcols)==5
        print(vcols[1:1])
        b = JuliaDB.groupby(@NT(z-> mycoalesce(columns(z, vcols[1]); default=0) ),
            t, idgroup, select=vcols[1:1], flatten=true)
    else
        print("too many dims to coalesce")
    end
end
function mycoalesce(X...; default=0)
    mat = X[1]
    if length(X)>1
        for vec in X[2:end]
            mat = hcat(mat, vec)
        end
    end
    # print(size(mat,1))
    result = Array{DataValues.DataValue{Float64}}(size(mat,1))*default
    for i in 1:size(mat,1)
        res = default
        for el in mat[i,:]
            if el*0==0
                res = el
                break
            end
        end
        result[i] = res
    end
    return result
end
