push!(LOAD_PATH, "$(pwd())/panelregression")
using CSV, alterpaneldf, DataFrames

windows = [-1,-2,-3,-4,-5,-10,-20,-60, 1, 2, 3, 5]
lambda = 0.94
### Load panel df ###
dftoloadname = "rawpanel1"
df = CSV.read("/home/nicolas/Data/Intermediate/$(dftoloadname).csv", rows_for_type_detect=3737, rows = 300000)

sort!(df, cols = [:permno, :td])

function ewma(X, λ=lambda)
    res = Array{Float64,1}(length(X))
    res[1] = X[end]
    i=0
    for x in X[end-1:-1:1]
        i+=1
        res[i+1] = λ*res[i]+(1-λ)*x
    end
    return mean(res)
end
function lagfct(X)
    return X[1]
end
function rolling(fun::Function, data::AbstractVector{T}, windowspan::Int) where {T}
    nvals  = nrolled(length(data), windowspan)
    offset = windowspan - 1
    result = zeros(T, nvals)

    @inbounds for idx in eachindex(result)
        result[idx] = fun( view(data, idx:idx+offset) )
    end

    return result
end
function running(fun::Function, data::AbstractVector{T}, windowspan::Int) where {T}
    if length(data)<windowspan
        nbmissing = windowspan-length(data)
        toprepend = ones(nbmissing)*data[1]
        data = [toprepend;data]
    end
    ndata   = length(data)
    nvals   = nrolled(ndata, windowspan)
    ntapers = ndata - nvals

    result = zeros(T, ndata)

    result[1:ntapers] = tapers(fun, data[1:ntapers])
    ntapers += 1
    result[ntapers:ndata] = rolling(fun, data, windowspan)

    return result
end
function nrolled(seqlength::T, windowspan::T) where {T<:Signed}
    (0 < windowspan <= seqlength) || throw(SpanError(seqlength,windowspan))

    return seqlength - windowspan + 1
end
function tapers(fun::Function, data::AbstractVector{T}) where {T}
    nvals  = length(data)
    result = zeros(T, nvals)

    @inbounds for idx in nvals:-1:1
        result[idx] = fun( view(data, 1:idx) )
    end

    return result
end
for d in windows
    if d<0
        df[Symbol("MA$(d)sent")] = NaN
        df[Symbol("EMA$(d)sent")] = NaN
        df[Symbol("SUM$(d)sent")] = NaN
        df[Symbol("agg$(d)ret")] = NaN
        df[Symbol("agg$(d)EAD")] = NaN
        df[Symbol("lag$(d)sent")] = NaN
        df[Symbol("lag$(d)ret")] = NaN
        df[Symbol("lag$(d)EAD")] = NaN
    else
        df[Symbol("lag$(d)sent")] = NaN
        df[Symbol("lag$(d)ret")] = NaN
        df[Symbol("lag$(d)EAD")] = NaN
    end
end
function runningvars(subdf, lags=windows)
    for d in lags
        try
            if d<0
                subdf[Symbol("MA$(d)sent")] = running(mean, subdf[:sent], abs(d)+1)
                subdf[Symbol("EMA$(d)sent")] = running(ewma, subdf[:sent], abs(d)+1)
                subdf[Symbol("SUM$(d)sent")] = running(sum, subdf[:sent], abs(d)+1)
                subdf[Symbol("agg$(d)ret")] = running(StatsBase.geomean, [0;subdf[:retadj]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)EAD")] = running(sum, subdf[:EAD], abs(d)+1)
                subdf[Symbol("lag$(d)EAD")] = running(lagfct, subdf[:EAD], abs(d)+1)
                subdf[Symbol("lag$(d)sent")] = running(lagfct, subdf[:sent], abs(d)+1)
                subdf[Symbol("lag$(d)ret")] = running(lagfct, subdf[:retadj], abs(d)+1)
            else
                subdf[Symbol("lag$(d)EAD")] = running(lagfct, subdf[:EAD][end:-1:1], abs(d)+1)[end:-1:1]
                subdf[Symbol("lag$(d)sent")] = running(lagfct, subdf[:sent][end:-1:1], abs(d)+1)[end:-1:1]
                subdf[Symbol("lag$(d)ret")] = running(lagfct, subdf[:retadj][end:-1:1], abs(d)+1)[end:-1:1]
            end
        catch
            print(d)
        end
    end
end
@time by(df, :permno, runningvars)
df[[:permno, :td, :retadj, Symbol("lag$(-2)ret")]][40000:45000,:]
CSV.write("/home/nicolas/Data/Intermediate/$(dftoloadname)_extended.csv", df)


using RCall
a = df[Symbol("agg$(1)ret")][1:50000]
median(a)
@rput a
R"plot(a)"

@time for subdf in groupby(df, :permno)
    for d in [1,5,10]
        subdf[Symbol("MA$(d)sent")] = running(mean, subdf[:sent], d)
        subdf[Symbol("agg$(d)ret")] = running(StatsBase.geomean, [0;subdf[:retadj]]+1, d)[2:end]
        subdf[Symbol("agg$(d)EAD")] = running(sum, subdf[:EAD], d)
    end
end

# a = df[1:1400000,:]

#Past lags
val = -1
df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
val = -2
df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
val = -3
df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
val = -5
df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -10
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -20
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -60
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)

# Forward looking lags
val = 1
df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 2
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 3
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 5
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 10
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 20
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 60
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)

#Past aggregate
# val = 2
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 3
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
val = 5
df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 10
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
val = 20
df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 60
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 120
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 240
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)


@time by(df, :permno, lagvariables) #35 sec per 100000

FF_factors2 = CSV.read("/home/nicolas/Data/Intermediate/FF_sent.csv")
FF_factors2[:td] = 0
for row in eachrow(FF_factors2)
    row[:td] = trading_day(dates, row[:date])
end

a = join(df, FF_factors2, on=:td, kind=:left)
val = 1
a[[Symbol("agg$(val)retadj"), :retadj]]
