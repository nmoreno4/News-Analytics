chosenVars = ["bm", "dailyretadj", "nbStories_rel100_nov24H", "sent_rel100_nov24H",
              "vol", "me"]
dbname = :Denada
collname = :daily_CRSP_CS_TRNA
tdperiods = (1,3776) # Start at period 1 to avoid problems. Edit code if need to start at later periods.(possibly in subperiodCol)

using PyCall, DataFrames, JLD2, NaNMath, CSV

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]


# Energy : 1010
# Materials : 1510
# Industrials : 2010
# Consumer Discretionary : 2510
# Consumer staples : 3010
# Health Care : 3510
# Financials : 4010
# Information Technology : 4510
# Communication Services : 5010
# Utilities : 5510
# Real Estate : 6010
industryIDdic = Dict("Energy"=>(1010,1499),
                     "Materials"=>(1510,1999),
                     "Industrials"=>(2010,2499),
                     "Consumer Discretionary"=>(2510,2999),
                     "Consumer staples"=>(3010,3499),
                     "Health Care"=>(3510,3999),
                     "Financials"=>(4010,4499),
                     "Information Technology"=>(4510,4999),
                     "Communication Services"=>(5010,5499),
                     "Utilities"=>(5510,5999),
                     "Real Estate"=>(6010,6499))



quintileDic = Dict()
for val in 1:5
    @time for sz in 1:5
        quintileDic[val*10+sz] = queryDB(tdperiods, chosenVars, (val*2-1, val*2), (sz*2-1, sz*2), mongo_collection)
    end
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_quintileDic.jld2" quintileDic
quintileDicbis = Dict()
for val in 1:5
    @time for sz in 1:5
        quintileDicbis[val*10+sz] = queryDB_doublefilt_Dic(["bmdecile", "sizedecile"], tdperiods, chosenVars, (val*2-1, val*2), (sz*2-1, sz*2), mongo_collection)
    end
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/quintileDicbis.jld2" quintileDicbis
# industDicbis = Dict()
# for indus in industryIDdic
#     @time industDicbis[indus[1]] = queryDB_singlefilt_Dic("ggroup", tdperiods, chosenVars, indus[2], mongo_collection)
# end


industDic = Dict()
for indus in industryIDdic
    @time industDic[indus[1]] = queryDB_singlefilt("ggroup", tdperiods, chosenVars, indus[2], mongo_collection)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_industDic.jld2" industDic

industDicbis = Dict()
for indus in industryIDdic
    @time industDicbis[indus[1]] = queryDB_singlefilt_Dic("ggroup", tdperiods, chosenVars, indus[2], mongo_collection)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_industDicbis.jld2" industDicbis
using FileIO
FileIO.save("/run/media/nicolas/Research/SummaryStats/D_industDicbis.jld2", industDicbis)
JLD2.@save  "/run/media/nicolas/Research/SummaryStats/D_industDicbis.jld2" industDicbis

industryDFs = Dict()
for indus in industryIDdic
    print(indus[1])
    if !(indus[1] in ["Health Care", "Financials"])
        industryDFs[indus[1]] = queryDic_to_df(industDicbis[indus[1]][1], industDicbis[indus[1]][2])
    end
end
JLD2.@save  "/run/media/nicolas/Research/SummaryStats/D_industryDFs.jld2" industryDFs

repDF = Dict("indus"=>[], "vol"=>[], "bm"=>[], "me"=>[], "ret"=>[], "nNews_S"=>[], "sent"=>[],
             "nbobs"=>[], "nPobs"=>[], "sentSTD"=>[], "sentSKEW"=>[], "sentKURT"=>[], "sentMED"=>[],
             "sent_all"=>[], "nbStories_all"=>[], "nbStoriesMAX_stock"=>[], "nbStoriesMIN_stock"=>[],
             "nbStoriesSTD_stock"=>[])
for indus in industryIDdic
    a = by(industryDFs[indus[1]], :permno) do df
        DataFrame(vol = custom_mean(df.vol), bm = custom_mean(df.bm), ret = custom_mean(df.dailyretadj),
                  me = custom_mean(df.me), nbStories = custom_sum(df.nbStories_rel100_nov24H),
                  sent = custom_mean(df.sent_rel100_nov24H), nbobs = length(df.dailyretadj),
                  sentSTD = custom_std(df.sent_rel100_nov24H), sentSKEW = custom_skew(df.sent_rel100_nov24H),
                  sentKURT = custom_kurt(df.sent_rel100_nov24H), sentMED = custom_median(df.sent_rel100_nov24H),
                  newsPerObs = custom_sum(df.nbStories_rel100_nov24H)/length(df.dailyretadj))
    end
    push!(repDF["indus"], indus[1])
    push!(repDF["vol"], round(custom_mean(a[:vol]);digits=0))
    push!(repDF["bm"], round(custom_mean(a[:bm]);digits=2))
    push!(repDF["me"], round(custom_mean(a[:me]);digits=0))
    push!(repDF["ret"], round(((custom_mean(a[:ret])+1)^252-1)*100;digits=2))
    push!(repDF["nNews_S"], round(custom_mean(a[:nbStories]);digits=0))
    push!(repDF["sent"], round(custom_mean(a[:sent]);digits=2))
    push!(repDF["nbobs"], round(custom_sum(a[:nbobs]);digits=0))
    push!(repDF["nPobs"], round(custom_mean(a[:newsPerObs]);digits=2))
    push!(repDF["sentSTD"], round(custom_mean(a[:sentSTD]);digits=2))
    push!(repDF["sentSKEW"], round(custom_mean(a[:sentSKEW]);digits=2))
    push!(repDF["sentKURT"], round(custom_mean(a[:sentKURT]);digits=2))
    push!(repDF["sentMED"], round(custom_median(industryDFs[indus[1]][:sent_rel100_nov24H]);digits=2))
    push!(repDF["sent_all"], round(custom_mean(industryDFs[indus[1]][:sent_rel100_nov24H]);digits=2))
    push!(repDF["nbStories_all"], round(custom_sum(industryDFs[indus[1]][:nbStories_rel100_nov24H]);digits=2))
    push!(repDF["nbStoriesMAX_stock"], round(custom_max(a[:nbStories]);digits=0))
    push!(repDF["nbStoriesMIN_stock"], round(custom_min(a[:nbStories]);digits=0))
    push!(repDF["nbStoriesSTD_stock"], round(custom_std(a[:nbStories]);digits=0))
end
repdf = DataFrame(repDF)
repdf = repdf[[:indus, :nNews_S, :sent, :me, :bm, :ret, :vol, :nbobs, :nPobs, :sentSTD, :sentSKEW,
               :sentKURT, :sentMED, :sent_all, :nbStories_all, :nbStoriesMAX_stock, :nbStoriesMIN_stock,
               :nbStoriesSTD_stock]]
CSV.write("/run/media/nicolas/Research/SummaryStats/D_rindustry_df.csv", repdf)
@rput repDF
R"library(Hmisc)"
R"X = latex(repDF, file='')"
@rget X

momDic = Dict()
for mom in 1:10
    @time momDic[mom] = queryDB_singlefilt("momrank", tdperiods, chosenVars, (mom,mom), mongo_collection)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_momDic.jld2" momDic
momDicbis = Dict()
for mom in 1:10
    print(mom)
    @time momDicbis[mom] = queryDB_singlefilt_Dic("momrank", tdperiods, chosenVars, (mom,mom), mongo_collection)
end
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_momDic.jld2" momDicbis









topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "RECLL",
          "REORG", "RES", "RESF", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND"] #PRXF, "RECAP1", "SHPP"
varnames = ["nbStories_rel100_nov24H_$(x)" for x in topics]

function endPerIdx(freq = Dates.quarterofyear) #week, month
    datesvec = datesVec()
    periodchange = map(x->freq(x), datesvec[2:end])-map(x->freq(x), datesvec[1:end-1])
    islastdayofperiod = map(x->x!=0, [periodchange;1])
    return findall(islastdayofperiod)
end

res = Dict()

tdperiods = (1,3776)
mdf = Any[0]
for topic in topics
    chosenVars = ["bm", "dailyretadj", "nbStories_rel100_nov24H_$(topic)", "sent_rel100_nov24H_$(topic)",
                  "vol", "me"]
    print(topic)
    a, keylabels = @time queryDB_singlefilt_Dic("nbStories_rel100_nov24H_$(topic)", tdperiods, chosenVars, (-1000,999999999), mongo_collection)
    b = DataFrame(a)
    b = transposeDF(b)
    delete!(b, :variable)
    names!(b, [Symbol(x) for x in keylabels])
    res[topic] = Dict()
    res[topic]["sent"] = custom_mean(convert(Array{Float64}, b[Symbol("sent_rel100_nov24H_$(topic)")]) ./ convert(Array{Float64}, b[Symbol("nbStories_rel100_nov24H_$(topic)")]))
    res[topic]["volume"] = custom_mean(b[:vol])
    res[topic]["bm"] = custom_mean(b[:bm])
    res[topic]["ret"] = ((custom_mean(b[:dailyretadj])+1)^252-1)*100
    res[topic]["vol"] = custom_std(b[:dailyretadj])*252
    res[topic]["me"] = custom_mean(b[:me])
    res[topic]["nbstories"] = custom_sum(b[Symbol("nbStories_rel100_nov24H_$(topic)")])
end
topics_summary = res
JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_topics_summary.jld2" topics_summary

a = NaNMath.mean_count(by(mdf, :permno, mdf -> custom_std(mdf.dailyretadj))[:x1])
b = NaNMath.mean_count(by(mdf, :permno, mdf -> custom_mean(mdf.dailyretadj))[:x1])
a[1]*252
((b[1]+1)^252-1)*100
((NaNMath.mean(convert(Array{Float64}, mdf[:dailyretadj]))+1)^252-1)*100

topic_df_summary= DataFrame(topics_summary)
topic_df_summary = transposeDF(topic_df_summary)

let topic_df_summary = DataFrame(bm=[], me=[], nbstories=[], ret=[], sent=[], vol=[], volume=[])
for topic in topics_summary
    topic_df_summary = vcat(topic_df_summary, DataFrame(topics_summary[topic[1]]))
end
topic_df_summary[:topic] = collect(keys(topics_summary))
CSV.write("/run/media/nicolas/Research/SummaryStats/D_topics_summary.csv", topic_df_summary)
end
