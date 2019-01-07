using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2

tdrange = (1,3776)

szvar = "ranksize" #sizedecile ranksize
bmvar = "rankbm" #bmdecile rankbm
wt = :wt
filters = Dict( "tdF" => ["td", tdrange],
                "BigF" => [szvar, (6,10)],
                "SmallF" => [szvar, (1,5)],
                "GrowthF" => [bmvar, (1,3)],
                "ValueF" => [bmvar, (8,10)],
                "SizeA" => [szvar, (1,5)] )


raw = Dict()
VWts = Dict()
cc = [1]
ptfnames = ["BG", "BV", "SG", "SV", "ALL"]
@time for ptf in [("tdF", "BigF", "GrowthF"), ("tdF", "BigF", "ValueF"), ("tdF", "SmallF", "GrowthF"), ("tdF", "SmallF", "ValueF"), [("tdF")]]
    retvals = ["permno", "date", "retadj", "$wt"]
    iniArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
    if length(ptf)==3
        f1 = deepcopy(filters[ptf[1]])
        f2 = deepcopy(filters[ptf[2]])
        f3 = deepcopy(filters[ptf[3]])
        print(f2)
        raw[ptfnames[cc[1]]] = @time queryDF(retvals, iniArrays, f1, f2, f3)
    else
        f1 = deepcopy(filters[ptf[1]])
        print(f1)
        raw[ptfnames[cc[1]]] = @time queryDF(retvals, iniArrays, f1)
    end
    VWts[ptfnames[cc[1]]] = @time FFweighting(raw[ptfnames[cc[1]]], :date, wt, :retadj)
    cc[1]+=1
end

JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/ts_retadj_ranksize_bm_td3776.jld2" VWts


retvals = ["permno", "date", "wt", "me", "retadj",
           "negSum_nov12H_0", "posSum_nov12H_0", "nS_nov12H_0"]
iniArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
              Union{Float64, Missing}[],Union{Float64, Missing}[],Union{Float64, Missing}[]]


FF = FFfactors(rowstoread=tdrange[1]:tdrange[end])

VWts["ALL"][:x1] = VWts["ALL"][:x1] .- FF[:RF] ./100

val = (VWts["BV"][:x1] .+ VWts["SV"][:x1]) ./ 2
gro = (VWts["BG"][:x1] .+ VWts["SG"][:x1]) ./ 2
HML = val .- gro
Mktrf = FF[:Mkt_RF] ./ 100

using Plots, Statistics, StatsBase
plot(VWts["ALL"][:date], [ret2tick(VWts["ALL"][:x1])[2:end], ret2tick(Mktrf)[2:end]])
plot(VWts["ALL"][:date], [ret2tick(HML)[2:end], ret2tick(FF[:HML] ./ 100)[2:end]])
plot(VWts["ALL"][:date], [ret2tick(HML)[2:end], ret2tick(FF[:HML] ./ 100)[2:end]])
plot(VWts["ALL"][:date], [ret2tick(VWts["BG"][:x1])[2:end], ret2tick(FF[:BLVW]./100)[2:end]], lw=1.5)
plot(VWts["ALL"][:date], [ret2tick(SGret[:x1])[2:end], ret2tick((FF[:SLVW]./100))[2:end]], lw=1.5)
cor(VWts["ALL"][:x1], Mktrf)
cor(VWts["SG"][:x1], (FF[:SLVW]./100))
cor(VWts["BG"][:x1], (FF[:BLVW]./100))
cor(VWts["SV"][:x1], (FF[:SHVW]./100))
cor(VWts["BV"][:x1], (FF[:BHVW]./100))
cor(HML, (FF[:HML]./100))
