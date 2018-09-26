using PyCall, Statistics, StatsBase
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/PolaritySpread/SeriesConstruction/helpfcts.jl")

# Add a function to cumulate sentiment and another to cumulate returns

# Connect to the database
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Dzielinski]
collection = db[:daily_CRSP_CS_TRNA]

# Name and define which portfolios to look-up in the Database
ptfs = [["BL", [(1,3), (6,10)]],
        ["BH", [(8,10), (6,10)]],
        ["SL", [(1,3), (1,5)]],
        ["SH", [(8,10), (1,5)]],
        ["M", [(4,7), (1,10)]]]

ptfDic = Dict()
for x in ptfs
    ptfDic[x[1]] = Dict("valR"=>x[2][1], "sizeR"=>x[2][2])
end

@time for ptf in ptfDic
    ptfDic[ptf[1]] = merge(ptfDic[ptf[1]], fillptf(ptf[2]["valR"], ptf[2]["sizeR"], "pos_m", "nbStories", 10))
end


@time for ptfPair in [("SH", "BH"), ("SL", "BL"), ("BL", "BH"), ("SL", "SH")]
    ptfDic["$(findFreqCharac(ptfPair))_retVW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "VWret")
    ptfDic["$(findFreqCharac(ptfPair))_sentVW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "VWsent")
    ptfDic["$(findFreqCharac(ptfPair))_retEW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "EWret")
    ptfDic["$(findFreqCharac(ptfPair))_sentEW"] = mergeptf(ptfDic[ptfPair[1]], ptfDic[ptfPair[2]], "EWsent")
end

# Edit with new dictionary config
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
