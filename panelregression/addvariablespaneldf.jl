push!(LOAD_PATH, "$(pwd())/panelregression")
using CSV, alterpaneldf, DataFrames

### Load panel df ###
dftoloadname = "rawpanel1"
df = CSV.read("/home/nicolas/Data/Intermediate/$(dftoloadname).csv", rows_for_type_detect=3737)

sort!(df, cols = [:permno, :td])

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
