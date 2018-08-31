using JuliaDB, Missings
t = table([1,2,3], [4,5,6], names=[:x, :y])
t.x
b = table([2,1,2,1],[2,3,1,3],[4,5,6,7], names=[:x,:y,:z], pkey=(:x,:y))
x = distribute([1,2,3,4], 3)
t = table(x, [5,6,7,8], names=[:x,:y])
table(columns(t)..., [9,10,11,12],names=[:x,:y,:z])


x = ndsparse(["a","b"],[3,4])
t = table([0.1, 0.5, 0.75], [0,1,2], names=[:t, :x])
reduce(+, t, select=:x)
reduce((a, b) -> @NT(t=a.t+b.t, x=a.x+b.x), t)


t=table(Float64[1,1,1,2,2,2], Float64[1,2,3,1,2,3],
    Float64[1,2,3,4,5,6],names=[:x,:y,:z], pkey=(:x,:y))
groupreduce(+, t, (:x,:y), select=:z)

a = groupby(lag, t, (:x),select=:z, flatten=true)
insertcolafter(t, :z, :w, select(a, 2))

@time b = JuliaDB.groupby(@NT(q25=z->lag(z, 2, default=NaN)),
    t, :x, select=:z, flatten=true)

function mylag(X, l; default=NaN)
    # print(X)
    return [X[1+l:end]; Array{Float64}(l)*NaN64]
end

using IterableTables, Dagger
addprocs(4)
t = JuliaDB.table(CStable, pkey=(:gvkey, :datadate))
@time b = JuliaDB.groupby(@NT(lag2=z-> +(columns(z, :at), columns(z, :lt)) ),
    CStable, :gvkey, select=(:at, :lt), flatten=true)
select(t, (:at, :lt))


using DataFrames, ShiftedArrays
a = DataFrame(A = 1:8, B = ["M", "F", "F", "M", "M", "F", "F", "M"])
c=0
c = by(a, :B) do df
    DataFrame(lag1 = lag(df[:A].+df[:A]*4, -2), A=df[:A])
end
