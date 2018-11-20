using JLD2, DataFrames, Dates, CSV, StatsBase, GLM
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

freq = Dates.day
tdperiods = (1,3776)
# "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/simple_HML_Dates.day_(1, 3776).jld2"
HMLDic = deepcopy(aggDicFreq)
# @time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintiles/quintiles_Dates.day_(1, 3776).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintilenew_Dates.day_(1, 3776).jld2"

include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
quintileids = [x*10+y for x in 1:5 for y in 1:5]


for i in names(keepgoodcolumns(aggDicFreq[55], ["", "RES", "CMPNY", "MRG", "RESF"]))
    print("$i \n")
end

a = copy(aggDicFreq[11])
b = by_means(a, [:sum_perNbStories_, :sum_perNbStories_RES, :sum_perNbStories_CMPNY, :sum_perNbStories_MRG, :sum_perNbStories_RESF], :permno)
c = b[:mean_sum_perNbStories_]
d = a[:sum_perNbStories_RES]
mean(replace(c, missing=>0))


ds = 4
varsformeans = [:aggSent_RES, :aggSent_, :cumret, :sum_perNbStories_, :sum_perNbStories_RES,
                :sum_perNbStories_CMPNY, :sum_perNbStories_MRG, :sum_perNbStories_RESF,
                :aggSent_CMPNY, :aggSent_MRG, :aggSent_RESF]
resmats = Dict()
for i in varsformeans
    resmats[i] = ones(Float64, 5,5)
    resmats["sz_timmerman_$(i)"] = Dict()
    resmats["val_timmerman_$(i)"] = Dict()
end
eads = [:EAD, Symbol("aroundEADm1:1:1"), :everyEAD]
resWead = Dict()
for i in eads
    resWead[i] = deepcopy(resmats)
end
for id in quintileids
    print(id)
    val, sz = parse(Int, "$id"[1]), parse(Int, "$id"[2])
    ptfDF = copy(aggDicFreq[id])
    ptfDF = keepgoodcolumns(ptfDF, ["", "RES", "CMPNY", "MRG", "RESF"])
    ptfDF[:everyEAD] = 1
    ptfDF[:aggSent_CMPNY] = ptfDF[:sum_perSent_CMPNY] ./ ptfDF[:sum_perNbStories_CMPNY]
    ptfDF[:aggSent_MRG] = ptfDF[:sum_perSent_MRG] ./ ptfDF[:sum_perNbStories_MRG]
    ptfDF[:aggSent_RESF] = ptfDF[:sum_perSent_RESF] ./ ptfDF[:sum_perNbStories_RESF]

    namesWNOminus = [Symbol(replace(replace(replace(String(x), "t_-"=>"t__-"), "-"=>"m"), "ret_"=>"cumret_")) for x in names(ptfDF)]
    names!(ptfDF, namesWNOminus)


    for i in varsformeans
        if String(i)[end-2:end] in ["RES", "CMPNY", "MRG", "RESF"]
            top = String(i)[end-2:end]
        else
            top = ""
        end
        ptfDF = @time createdoublesort(ptfDF, Symbol("aggSent_$(top)_m5_m1"), Symbol("aggSent_$(top)_m60_m1"))
        # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m20_m1"), 10:10:100)
        # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m60_m1"), 10:10:100)
        # ptfDF = buckets_assign(ptfDF, Symbol("aggSent_$(top)_m120_m1"), 10:10:100)

        if ds==0
            provbuckfDF = ptfDF[ptfDF[:doublefreqsort].>=0,:]
        else
            provbuckfDF = ptfDF[ptfDF[:doublefreqsort].==ds,:]
        end
        for ead in eads
            provbuckfDF[ead] = replace(provbuckfDF[ead], missing=>0)
            provtfDF = provbuckfDF[provbuckfDF[ead].==1,:]

            means_stock_sent = by_means(provtfDF, [i], :permno)
            resWead[ead][i][val,sz] = colmeans_to_dic(means_stock_sent)[Symbol("mean_$(i)")]

            means_td_sent = by_means(provtfDF, [i], :perid)
            means_td_sent = daysWNOead(tdperiods, means_td_sent, [Symbol("mean_$(i)")])
            if !(val in keys(resmats["val_timmerman_$(i)"]))
                resWead[ead]["val_timmerman_$(i)"][val] = Dict()
            end
            if !(sz in keys(resmats["sz_timmerman_$(i)"]))
                resWead[ead]["sz_timmerman_$(i)"][sz] = Dict()
            end
            resWead[ead]["sz_timmerman_$(i)"][sz] = concat_ts_timmerman!(means_td_sent, resWead[ead]["sz_timmerman_$(i)"][sz], sz, Symbol("mean_$(i)"))
            resWead[ead]["val_timmerman_$(i)"][val] = concat_ts_timmerman!(means_td_sent, resWead[ead]["val_timmerman_$(i)"][val], val, Symbol("mean_$(i)"))
        end
    end
end
timmermanns = Dict()
for ead in resWead
    for result in ead[2]
        if typeof(result[1])==Symbol
            CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/means/ds$(ds)_simplemean_$(result[1])_$(freq)_$(ead[1]).csv", DataFrame(result[2]))
        else
            X = ptfEWmean(result[2])
            # @time MR = timmerman(X, 10)
            # print(MR)
            # timmermanns["$(result[1])_$(ead[1])"] = MR
        end
    end
end

for ptf in quintileids
    ptfDF = copy(aggDicFreq[ptf])
    ptfDF[:aggSent_CMPNY] = ptfDF[:sum_perSent_CMPNY] ./ ptfDF[:sum_perNbStories_CMPNY]
    ptfDF[:aggSent_MRG] = ptfDF[:sum_perSent_MRG] ./ ptfDF[:sum_perNbStories_MRG]
    ptfDF[:aggSent_RESF] = ptfDF[:sum_perSent_RESF] ./ ptfDF[:sum_perNbStories_RESF]
    @time cdf_variable(ptfDF, [:aggSent_, :aggSent_RES, :aggSent_MRG, :aggSent_CMPNY, :aggSent_RESF], ptf)
end

ptfDF = buckets_assign(ptfDF, :aggSent_, 10:10:100)




include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")


for doublesort in 0:4
    print("\n\n\n\n\n\n\n\n\nDOUBLESOOOOORT : $doublesort \n\n\n\n\n\n\n\n\n\n")
    #:EAD, :everyEAD
    eadchoice = :everyEAD
    cptfvars = [:cumret, :aggSent_, :ret__1_5, :ret__1_3, Symbol("ret__-5_-1"), Symbol("aggSent__-1_0"), Symbol("aggSent__-5_-1"), Symbol("aggSent__-20_-1"), Symbol("aggSent__-60_-1"),
                Symbol("aggSent_RES_-1_0"), Symbol("aggSent_RES_-5_-1"), Symbol("aggSent_RES_-20_-1"), Symbol("aggSent_RES_-60_-1"), :ret__1_20];
    cptfvarsNOMINUS = [Symbol(replace(String(x), "-"=>"m")) for x in cptfvars]
    resdic = Dict()
    for ptf in [x*10+y for x in 1:5 for y in 1:5]
        try
            print("\n \n \n \n THIS IS PTF: $ptf \n \n \n \n")
            resdic[ptf] = Dict()
            ptfDF = @time keepgoodcolumns(copy(aggDicFreq[ptf]), ["", "RES", "CMPNY", "MRG", "RESF"])
            ptfDF = @time createdoublesort(ptfDF, Symbol("aggSent__-5_-1"), Symbol("aggSent__-60_-1"))
            ptfDF[:everyEAD] = 1
            replace!(ptfDF[eadchoice], missing=>0)
            if doublesort!=0
                @time ptfDF = ptfDF[ptfDF[:doublefreqsort].==doublesort,:]
            end
            ptfDF = @time ptfDF[ptfDF[eadchoice].==1,:]
            paneldf = @time createPanelDF(ptfDF, HMLDic, ptfvars = cptfvars, runninglags = [250,120,60,20,5], tdperiods = tdperiods);

            namesWNOminus = [Symbol(replace(replace(String(x), "t_-"=>"t__-"), "-"=>"m")) for x in names(paneldf)]
            names!(paneldf, namesWNOminus)

            # Regress current return against current HMLsent, stocksent and ptfsent
            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[1], cptfvarsNOMINUS[2], Symbol("ptf_VW_$(cptfvarsNOMINUS[2])"), :HML_VW_aggSent_, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][1] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[5], cptfvarsNOMINUS[7], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), :HML_VW_aggSent__l5, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][2] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[1], cptfvarsNOMINUS[7], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), :HML_VW_aggSent__l5, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][3] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[3], cptfvarsNOMINUS[7], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), :HML_VW_aggSent__l5, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][4] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[14], cptfvarsNOMINUS[8], Symbol("ptf_VW_$(cptfvarsNOMINUS[8])"), :HML_VW_aggSent__l20, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][5] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[5], cptfvarsNOMINUS[7], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), cptfvarsNOMINUS[11], Symbol("ptf_VW_$(cptfvarsNOMINUS[11])"), :HML_VW_aggSent__l5, :HML_VW_aggSent_RES_l5, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][6] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[3], cptfvarsNOMINUS[7], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), cptfvarsNOMINUS[11], Symbol("ptf_VW_$(cptfvarsNOMINUS[11])"), :HML_VW_aggSent__l5, :HML_VW_aggSent_RES_l5, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][7] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[14], cptfvarsNOMINUS[8], Symbol("ptf_VW_$(cptfvarsNOMINUS[8])"), cptfvarsNOMINUS[12], Symbol("ptf_VW_$(cptfvarsNOMINUS[12])"), :HML_VW_aggSent__l20, :HML_VW_aggSent_RES_l20, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][8] = reg

            a=paneldf[[:permno, :perid, cptfvarsNOMINUS[3], cptfvarsNOMINUS[7], cptfvarsNOMINUS[8], cptfvarsNOMINUS[9], Symbol("ptf_VW_$(cptfvarsNOMINUS[7])"), Symbol("ptf_VW_$(cptfvarsNOMINUS[8])"), Symbol("ptf_VW_$(cptfvarsNOMINUS[9])"), :HML_VW_aggSent__l5, :HML_VW_aggSent__l20, :HML_VW_aggSent__l60, :Mkt_RF, :SMB, :HML, :Mom]]
            reg = panelReg(a)
            resdic[ptf][9] = reg
        catch
            print("\n \n \n \n FAILED!!!! PTF: $ptf \n \n \n \n")
        end
    end

    depvars = ["[1, 2, ptf2, HML]", "[5,7,ptf7,HML_l5]", "[1,7,ptf7,HML_l5]", "[3,7,ptf7,HML_l5]", "[14,8,ptf8,HML_l20]", "[5,7,ptf7,11,ptf11,HML_l5,HML_R_l5]", "[3,7,ptf7,11,ptf11,HML_l5,HML_R_l5]", "[14,8,ptf8,12,ptf12,HML_l20,HML_R_l20]", "[3,7,8,9,ptf7,ptf8,ptf9,HML5,HML20,HML60]"]

    for i in 1:length(depvars)
        for j in 1:7
            regToCsv(j, resdic, depvars[i], eadchoice, doublesort, i)
        end
    end
end





function classifynewspolarity(ptfDF, groupvar, percentiles)
    a = by(ptfDF, groupvar) do df
        res = Dict()
        res[Symbol("bp_$(groupvar)")] = percentile(collect(skipmissing(df[var])), percentiles)
        DataFrame(res)
    end
end

bpDict = Dict()
for perc in []
percentile(collect(skipmissing(df[var])), percentiles)




@rput a
R"plot(a)"
classifynewspolarity(ptfDF, [:aggSent_], [0.5])

function sensitivityHML()
end


# 0/ Compute market sentiment
# 1/ Gather Baker sentiment and map it to :perid
# 2/ Gather FF factors and map it to :perid
# 3/ Compute HML sent and map it to :perid
# 4/ Compute ptf sent, coverage, neg sent and pos and map it to :perid
# 5/ Regress ptf sent/ret to 1,2,3,4
# 6/ Conditional on EAD regress ptf sent to 1,2,3,4
# 7/ Regress future (past) sent/ret and regress it against 1,2,3,4
# 8/ Rank ptf in winner/loser high-freq/low-freq = 4 ptfs
# 9/ average (future/past) returns of ptfs in 4
# 10/ Plot cdfs
# 11/ Plot sentiment (low freq) against baker sentiment
# 12/ Plot HML sent against Volumes*price (make assumption that shares out ratio HML stays constant)
# 13/ permno-td observations with news (aggsent)



ods_write("TestSpreadsheet.ods",Dict(("TestSheet",3,2)=>[[1,2,3,4,5] [6,7,8,9,10]]))
