using JLD2, DataFrames, MultivariateStats, Dates, TSmanip, TSmap

@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_FF_all_3.jld2" NSMat

crtdf = NSMat["ALL"]
nTopic = [:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0]

dayNS = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)
a = dayStockMat(dayNS)
function dayStockMat(dayNS)
    res = Dict()
    daterange = DataFrame(Dict(:perID=>sort(collect(Set(dayNS[:perID])))))
    @time by(dayNS, :permno) do xdf
        X = join(daterange, xdf, on=:perID, kind=:left)[:NS]
        res[xdf[:permno][1]] = convert(Array{Float64}, replace(X, missing=>NaN))
    end
    # X = convert(Array{Union{Missing,Float64}}, zeros(size(daterange,1), length(res)))
    X = zeros(size(daterange,1), length(res))
    rKeys= collect(keys(res))
    @time for i in 1:length(res)
        X[:,i] = res[rKeys[i]]
    end
    return X
end

FA = @time MultivariateStats.fit(FactorAnalysis, replace(a'[1:3500,1:3500], NaN=>0), method=:em)
MultivariateStats.projection(FA)
FA.Ψ

plot(sort(collect(Set(dayNS[:perID]))), a[:,4006])


M = @time MultivariateStats.fit(KernelPCA, replace(a', NaN=>0);maxoutdim=3, inverse=true)
Yte = @time MultivariateStats.transform(M, replace(a', NaN=>0))
principalvars(M)
Xr = @time MultivariateStats.reconstruct(M, Yte)

plot(sort(collect(Set(dayNS[:perID]))), M.proj[:,4])
plot(sort(collect(Set(dayNS[:perID]))), M.mean)
plot(sort(collect(Set(dayNS[:perID]))), M.α[:,2])
plot(sort(collect(Set(dayNS[:perID]))), Yte[:,1])
