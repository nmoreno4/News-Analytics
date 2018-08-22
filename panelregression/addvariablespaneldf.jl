push!(LOAD_PATH, "$(pwd())/panelregression")
using CSV, alterpaneldf, DataFrames, ArgParse

s = ArgParseSettings()
@add_arg_table s begin
    "machine"
        help = "crt year"
        required = true
        arg_type = String
        default = "local"
    "rowstoread"
        help = "Number of rows to read from the DataFrame"
        required = false
        arg_type = Int
        default = 14100000
    "runversion"
        arg_type=Int
        required = false
end
parsed_args = parse_args(s)
machine = parsed_args["machine"]
rowstoread = parsed_args["rowstoread"]
runversion = parsed_args["runversion"]

windows = [-1,-2, -5,-20, 0, 1,2]
lambda = 0.94
### Load panel df ###
dftoloadname = "rawpanel5"
if machine == "CECI"
    CECIpath = "/CECI/home/ulg/affe/nmoreno"
    df = CSV.read("$(CECIpath)/Data/Intermediate/$(dftoloadname)_FF.csv", rows_for_type_detect=3737, rows = rowstoread)
elseif machine == "local"
    df = CSV.read("/home/nicolas/Data/Intermediate/$(dftoloadname)_FF.csv", rows_for_type_detect=3737, rows = rowstoread)
end
print("file loaded")
df[:uid] = collect(zip(df[:permno], df[:td]))
a = df[[:uid]]
deleterows!(df, find(nonunique(a)))
delete!(df, :uid)

sort!(df, [:permno, :td])

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
function isvalue(rankbm)
    res = ones(size(rankbm,1))*NaN
    i=0
    for x in rankbm
        i+=0
        if x=="H"
            res[i]=1
        else
            res[i]=0
        end
    end
    print(i)
    return res
end
function isgrowth(rankbm)
    res = ones(size(rankbm,1))*NaN
    i=0
    for x in rankbm
        i+=0
        if x=="L"
            res[i]=1
        else
            res[i]=0
        end
    end
    return res
end
function isbig(rankbm)
    res = ones(size(rankbm,1))*NaN
    i=0
    for x in rankbm
        i+=0
        if (x-floor(x))*10>3
            res[i]=1
        else
            res[i]=0
        end
    end
    return res
end
function ismedium(rankbm)
    res = ones(size(rankbm,1))*NaN
    i=0
    print(length(rankbm))
    for x in rankbm
        i+=0
        if x=="M"
            res[i]=1
        else
            res[i]=0
        end
    end
    return res
end
for d in windows
    if d<0
        df[Symbol("MA$(d)sent")] = NaN
        # df[Symbol("EMA$(d)sent")] = NaN
        # df[Symbol("SUM$(d)sent")] = NaN
        df[Symbol("agg$(d)ret")] = NaN
        df[Symbol("agg$(d)EAD")] = NaN
        df[Symbol("MA$(d)VWvaluesent")] = NaN
        df[Symbol("lag$(d)VWvaluesent")] = NaN
        df[Symbol("MA$(d)VWgrowthsent")] = NaN
        df[Symbol("lag$(d)VWgrowthsent")] = NaN
        df[Symbol("MA$(d)hmlsent")] = NaN
        df[Symbol("lag$(d)hmlsent")] = NaN
        df[Symbol("agg$(d)mktrf")] = NaN
        df[Symbol("agg$(d)hml")] = NaN
        df[Symbol("agg$(d)smb")] = NaN
        df[Symbol("agg$(d)valueret")] = NaN
        df[Symbol("agg$(d)growthret")] = NaN
        df[Symbol("agg$(d)smallret")] = NaN
        df[Symbol("agg$(d)bigret")] = NaN
        if d<-4
            for ld in -5:-1
                df[Symbol("lagagg$(d)_$(ld)EAD")] = NaN
                df[Symbol("lagMA$(d)_$(ld)sent")] = NaN
                df[Symbol("lagMA$(d)_$(ld)VWvaluesent")] = NaN
                df[Symbol("lagMA$(d)_$(ld)hmlsent")] = NaN
                df[Symbol("lagMA$(d)_$(ld)VWgrowthsent")] = NaN
            end
        end
        if d>-4
            df[Symbol("lag$(d)newsday")] = NaN
            df[Symbol("lag$(d)sent")] = NaN
            df[Symbol("lag$(d)ret")] = NaN
            df[Symbol("lag$(d)EAD")] = NaN
        end
    elseif d==0
        df[Symbol("isgrowth")] = NaN
        df[Symbol("isvalue")] = NaN
        df[Symbol("ismedium")] = NaN
        # df[Symbol("ismall")] = NaN
        df[Symbol("isbig")] = NaN
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
                # subdf[Symbol("EMA$(d)sent")] = running(ewma, subdf[:sent], abs(d)+1)
                # subdf[Symbol("SUM$(d)sent")] = running(sum, subdf[:sent], abs(d)+1)
                subdf[Symbol("agg$(d)ret")] = running(StatsBase.geomean, [0;subdf[:retadj]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)EAD")] = running(sum, subdf[:EAD], abs(d)+1)
                subdf[Symbol("MA$(d)VWvaluesent")] = running(mean, subdf[:VWvaluesent], abs(d)+1)
                subdf[Symbol("lag$(d)VWvaluesent")] = running(lagfct, subdf[:VWvaluesent], abs(d)+1)
                subdf[Symbol("MA$(d)VWgrowthsent")] = running(mean, subdf[:VWgrowthsent], abs(d)+1)
                subdf[Symbol("lag$(d)VWgrowthsent")] = running(lagfct, subdf[:VWgrowthsent], abs(d)+1)
                subdf[Symbol("MA$(d)hmlsent")] = running(mean, subdf[:hmlsent], abs(d)+1)
                subdf[Symbol("lag$(d)hmlsent")] = running(lagfct, subdf[:hmlsent], abs(d)+1)
                subdf[Symbol("agg$(d)mktrf")] = running(StatsBase.geomean, [0;subdf[:mktrf]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)hml")] = running(StatsBase.geomean, [0;subdf[:hml]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)smb")] = running(StatsBase.geomean, [0;subdf[:smb]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)valueret")] = running(StatsBase.geomean, [0;subdf[:valueret]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)growthret")] = running(StatsBase.geomean, [0;subdf[:growthret]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)smallret")] = running(StatsBase.geomean, [0;subdf[:smallret]]+1, abs(d)+1)[2:end]-1
                subdf[Symbol("agg$(d)bigret")] = running(StatsBase.geomean, [0;subdf[:bigret]]+1, abs(d)+1)[2:end]-1
                try
                    if d<-4
                        for ld in -5:-1
                            subdf[Symbol("lagagg$(d)_$(ld)EAD")] = running(lagfct, subdf[Symbol("agg$(d)EAD")], abs(d*ld)+1)
                            subdf[Symbol("lagMA$(d)_$(ld)sent")] = running(lagfct, subdf[Symbol("MA$(d)sent")], abs(d*ld)+1)
                            subdf[Symbol("lagMA$(d)_$(ld)VWvaluesent")] = running(lagfct, subdf[Symbol("MA$(d)VWvaluesent")], abs(d*ld)+1)
                            subdf[Symbol("lagMA$(d)_$(ld)hmlsent")] = running(lagfct, subdf[Symbol("MA$(d)hmlsent")], abs(d*ld)+1)
                            subdf[Symbol("lagMA$(d)_$(ld)VWgrowthsent")] = running(lagfct, subdf[Symbol("MA$(d)VWgrowthsent")], abs(d*ld)+1)
                        end
                    end
                end
                if d>=-4
                    subdf[Symbol("lag$(d)newsday")] = running(lagfct, subdf[:newsday], abs(d)+1)
                    subdf[Symbol("lag$(d)EAD")] = running(lagfct, subdf[:EAD], abs(d)+1)
                    subdf[Symbol("lag$(d)sent")] = running(lagfct, subdf[:sent], abs(d)+1)
                    subdf[Symbol("lag$(d)ret")] = running(lagfct, subdf[:retadj], abs(d)+1)
                end
            elseif d==0
                subdf[Symbol("isgrowth")] =  [if i=="L" 1 else 0 end for i in subdf[:rankbm]]
                subdf[Symbol("isvalue")] =  [if i=="H" 1 else 0 end for i in subdf[:rankbm]]
                subdf[Symbol("ismedium")] =  [if i=="M" 1 else 0 end for i in subdf[:rankbm]]
                subdf[Symbol("isbig")] =  [if i=="B" 1 else 0 end for i in subdf[:ptf_5by5]]
            else
                subdf[Symbol("lag$(d)EAD")] = running(lagfct, subdf[:EAD][end:-1:1], abs(d)+1)[end:-1:1]
                subdf[Symbol("lag$(d)sent")] = running(lagfct, subdf[:sent][end:-1:1], abs(d)+1)[end:-1:1]
                subdf[Symbol("lag$(d)ret")] = running(lagfct, subdf[:retadj][end:-1:1], abs(d)+1)[end:-1:1]
            end
        catch err
            print(err)
            print(subdf[:permno][1])
            print(d)
        end
    end
end
print("Running it!")
@time by(df, :permno, runningvars)
newnames = Symbol[]
for n in names(df)
    newname = replace(String(n), "-", "_")
    push!(newnames, Symbol(newname))
end
names!(df, newnames)
# sum(df[:isvalue])
# df[[:permno, :td, :retadj, Symbol("MA$(-60)VWvaluesent")]][40000:45000,:]
if machine == "CECI"
    CECIpath = "/CECI/home/ulg/affe/nmoreno"
    CSV.write("$(CECIpath)/CECIexports/$(dftoloadname)_$(rowstoread)extended.csv", df)
elseif machine == "local"
    CSV.write("/home/nicolas/Data/Intermediate/$(dftoloadname)_$(rowstoread)extended.csv", df)
end

#
# using RCall
# a = df[Symbol("agg$(1)ret")][1:50000]
# median(a)
# @rput a
# R"plot(a)"
#
# @time for subdf in groupby(df, :permno)
#     for d in [1,5,10]
#         subdf[Symbol("MA$(d)sent")] = running(mean, subdf[:sent], d)
#         subdf[Symbol("agg$(d)ret")] = running(StatsBase.geomean, [0;subdf[:retadj]]+1, d)[2:end]
#         subdf[Symbol("agg$(d)EAD")] = running(sum, subdf[:EAD], d)
#     end
# end
#
# # a = df[1:1400000,:]
#
# #Past lags
# val = -1
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -2
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -3
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = -5
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = -10
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = -20
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = -60
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
#
# # Forward looking lags
# val = 1
# df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 2
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 3
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 5
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 10
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 20
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 60
# # df[Symbol("lag$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("lag$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
#
# #Past aggregate
# # val = 2
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 3
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 5
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 10
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# val = 20
# df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 60
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 120
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # val = 240
# # df[Symbol("agg$(val)retadj")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)sent")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
# # df[Symbol("agg$(val)EAD")] = Array{Union{Float64, Missings.Missing}}(ones(size(df,1))*val)
#
#
# @time by(df, :permno, lagvariables) #35 sec per 100000
#
# FF_factors2 = CSV.read("/home/nicolas/Data/Intermediate/FF_sent.csv")
# FF_factors2[:td] = 0
# for row in eachrow(FF_factors2)
#     row[:td] = trading_day(dates, row[:date])
# end
#
# a = join(df, FF_factors2, on=:td, kind=:left)
# val = 1
# a[[Symbol("agg$(val)retadj"), :retadj]]
