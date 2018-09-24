using PyCall, Statistics

# Add a function to cumulate sentiment and another to cumulate returns

# Connect to the database
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:DenadaDB]
collection = db[:daily_CRSP_CS_TRNA]


BL = initptf()
valR, sizeR = (1,3), (6,10)
BL = @time fillptf(BL, valR, sizeR)

BH = initptf()
valR, sizeR = (8,10), (6,10)
BH = fillptf(BH, valR, sizeR)

SL = initptf()
valR, sizeR = (1,3), (1,5)
SL = fillptf(SL, valR, sizeR)

SH = initptf()
valR, sizeR = (8,10), (1,5)
SH = fillptf(SH, valR, sizeR)

M = initptf()
valR, sizeR = (4,7), (1,10)
M = fillptf(M, valR, sizeR)

Hret = mergeptf(SH, BH, "VWret")
Hsent = mergeptf(SH, BH, "VWsent")
Lret = mergeptf(SL, BL, "VWret")
Lsent = mergeptf(SL, BL, "VWsent")

Bret = mergeptf(BL, BH, "VWret")
Bsent = mergeptf(BL, BH, "VWsent")
Sret = mergeptf(SL, SH, "VWret")
Ssent = mergeptf(SL, SH, "VWsent")

Mktret = marketptf("VWret")
Mktsent = marketptf("VWsent")

using RCall, DataFrames
mydata = DataFrame(Hret=Hret, Hsent=Hsent, Lret=Lret, Lsent=Lsent,
                   Bret=Bret, Bsent=Bsent, Sret=Lret, Ssent=Lsent,
                   Mktret=Mktret, Mktsent=Mktsent,
                   HMLret = Hret-Lret, SMBret = Sret-Bret,
                   HMLsent = Hsent-Lsent, SMBsent = Ssent-Bsent)
@rput mydata
R"mod = lm(Mktret~HMLret+SMBret+HMLsent+SMBsent, mydata)"
R"summary(mod)"

function ret2tick(vec, val=100)
    res = Float64[]
    for i in vec
        val*=(1+i)
        push!(res, val)
    end
    return res
end

function mergeptf(dic1, dic2, mvar)
    foo = hcat(dic1[mvar],dic2[mvar])
    return vec(mapslices(mean, foo, dims = 2))
end

function marketptf(mvar)
    foo = hcat(SH[mvar].*SH["wt"],BH[mvar].*BH["wt"], SL[mvar].*SL["wt"],BL[mvar].*BL["wt"], M[mvar].*M["wt"])
    weights = hcat(SH["wt"],BH["wt"],SL["wt"],BL["wt"],M["wt"])
    return vec(mapslices(sum, foo, dims = 2))./(vec(mapslices(sum, weights, dims = 2)))
end

function initptf()
    return Dict{String,Array{Float64,1}}("VWret"=>Float64[], "EWret"=>Float64[],
                                       "VWsent"=>Float64[], "EWsent"=>Float64[], "wt"=>Float64[])
end

function fillptf(ptfDict, valR, sizeR, tdmax=100)
    for td in 1:tdmax
        foo = sizeValRetSent(td, valR, sizeR)
        push!(ptfDict["VWret"], foo[1])
        push!(ptfDict["EWret"], foo[2])
        push!(ptfDict["VWsent"], foo[3])
        push!(ptfDict["EWsent"], foo[4])
        push!(ptfDict["wt"], foo[5])
    end
    return ptfDict
end

function sizeValRetSent(td, valR, sizeR, sentMeasure = "spread_rel50nov3D_m")
    dayretvec = Float64[]
    daywtvec = Union{Float64, Missing}[]
    dayspreadvec = Union{Float64, Missing}[]
    for filtDic in collection[:find](Dict("td"=>td, "rankbm"=>Dict("\$gte"=>valR[1], "\$lte"=>valR[2]),
                                            "ranksize"=>Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])))
        push!(dayretvec, filtDic["dailyretadj"])
        if typeof(filtDic["wt"])==Float64
            push!(daywtvec, filtDic["wt"])
        else
            push!(daywtvec, missing)
        end
        if haskey(filtDic, sentMeasure)
            push!(dayspreadvec, filtDic[sentMeasure])
        else
            push!(dayspreadvec, missing)
        end
    end
    VWret = sum(skipmissing(dayretvec.*daywtvec))/sum(skipmissing(daywtvec))
    EWret = mean(dayretvec)
    EWsent = mean(skipmissing(dayspreadvec))
    VWsent = sum(skipmissing(dayspreadvec.*daywtvec))/sum(skipmissing(daywtvec))
    return (VWret, EWret, EWsent, VWsent, sum(skipmissing(daywtvec)))
end
