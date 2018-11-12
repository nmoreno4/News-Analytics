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


######### BM/Size 25 ptfs ##########
quintileDic = Dict()
for val in 1:5
    @time for sz in 1:5
        quintileDic[val*10+sz] = queryDB_doublefilt_Dic(["bmdecile", "sizedecile"], tdperiods, chosenVars, (val*2-1, val*2), (sz*2-1, sz*2), mongo_collection)
    end
end
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/quintileDicbis.jld2" quintileDicbis
quintileids = [x*10+y for x in 1:5 for y in 1:5]
# Transform Dic to DF
quintileDFs = Dict()
for id in quintileids
    quintileDFs[id] = queryDic_to_df(quintileDic[id][1], quintileDic[id][2])
end
# JLD2.@save  "/run/media/nicolas/Research/SummaryStats/D_quintileDFs.jld2" quintileDFs
# Save final DF
repdf =  df_custom_summary(quintileDFs, quintileids, false)
CSV.write("/run/media/nicolas/Research/SummaryStats/D_quintiles_df.csv", repdf)
#correlation matrix
corrmat = custom_corr_mat(quintileDFs, quintileids)
CSV.write("/run/media/nicolas/Research/SummaryStats/D_quintiles_corrmat.csv", corrmat)


######### Industries ########
# Gather data from MongoDB
industDic = Dict()
for indus in industryIDdic
    @time industDic[indus[1]] = queryDB_singlefilt_Dic("ggroup", tdperiods, chosenVars, indus[2], mongo_collection)
end
# Transform Dic to DF
industryDFs = Dict()
for indus in industryIDdic
    industryDFs[indus[1]] = queryDic_to_df(industDic[indus[1]][1], industDic[indus[1]][2])
end
# JLD2.@save  "/run/media/nicolas/Research/SummaryStats/D_industryDFs.jld2" industryDFs

repdf =  df_custom_summary(industryDFs, industryIDdic, true)
CSV.write("/run/media/nicolas/Research/SummaryStats/D_industry_df.csv", repdf)
#correlation matrix
corrmat = custom_corr_mat(repdf, collect(keys(industryIDdic)))
CSV.write("/run/media/nicolas/Research/SummaryStats/D_industry_corrmat.csv", corrmat)


###### Momentum ########
momDic = Dict()
for mom in 1:10
    print(mom)
    @time momDic[mom] = queryDB_singlefilt_Dic("momrank", tdperiods, chosenVars, (mom,mom), mongo_collection)
end
# JLD2.@save "/run/media/nicolas/Research/SummaryStats/D_momDic.jld2" momDicbis
# Transform Dic to DF
momDFs = Dict()
for id in 1:10
    print(id)
    momDFs[id] = queryDic_to_df(momDic[id][1], momDic[id][2])
end
# JLD2.@save  "/run/media/nicolas/Research/SummaryStats/D_momDFs.jld2" momDFs
# Save final DF
repdf =  df_custom_summary(momDFs, 1:10, false)
CSV.write("/run/media/nicolas/Research/SummaryStats/D_mom_df.csv", repdf)

corrmat = custom_corr_mat(repdf, 1:10)
CSV.write("/run/media/nicolas/Research/SummaryStats/D_mom_corrmat.csv", corrmat)





#########################################################################################
#########################################################################################
############################ Topic news summary Stats ###################################
#########################################################################################
#########################################################################################

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

# a = NaNMath.mean_count(by(mdf, :permno, mdf -> custom_std(mdf.dailyretadj))[:x1])
# b = NaNMath.mean_count(by(mdf, :permno, mdf -> custom_mean(mdf.dailyretadj))[:x1])
# a[1]*252
# ((b[1]+1)^252-1)*100
# ((NaNMath.mean(convert(Array{Float64}, mdf[:dailyretadj]))+1)^252-1)*100
#
# topic_df_summary= DataFrame(topics_summary)
# topic_df_summary = transposeDF(topic_df_summary)

let topic_df_summary = DataFrame(bm=[], me=[], nbstories=[], ret=[], sent=[], vol=[], volume=[])
for topic in topics_summary
    topic_df_summary = vcat(topic_df_summary, DataFrame(topics_summary[topic[1]]))
end
topic_df_summary[:topic] = collect(keys(topics_summary))
CSV.write("/run/media/nicolas/Research/SummaryStats/D_topics_summary.csv", topic_df_summary)
end
