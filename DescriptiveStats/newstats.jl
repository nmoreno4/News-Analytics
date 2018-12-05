using JLD2, DataFrames, Dates, CSV, StatsBase, GLM
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")

freq = Dates.day
tdperiods = (1,3776)
# "/run/media/nicolas/Research/SummaryStats/agg/quintiles_$(freq)_$(tdperiods).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/simple_HML_Dates.day_(1, 3776).jld2"
HMLDic = deepcopy(aggDicFreq)
# @time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintiles/quintiles_Dates.day_(1, 3776).jld2"
# @time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/quintilenew_Dates.day_(1, 3776).jld2"
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/allobs_Dates.day_(1, 3776).jld2"

include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
quintileids = [x*10+y for x in 1:5 for y in 1:5]

baker = CSV.read("/run/media/nicolas/Research/Data/baker_sentiment.csv")
a = baker[:SENT]
@rput a
R"plot(a)"


for i in names(keepgoodcolumns(aggDicFreq[55], ["", "RES", "CMPNY", "MRG", "RESF"]))
    print("$i \n")
end


varsformeans = [:aggSent_, :aggSent_RES, :aggSent_CMPNY, :aggSent_MRG, :aggSent_RESF,
                :sum_perNbStories_, :sum_perNbStories_RES, :sum_perNbStories_CMPNY,
                :sum_perNbStories_MRG, :sum_perNbStories_RESF,
                :aggSent__1_5, :aggSent__1_20, :aggSent_RES_1_5,
                :cumret, :cumret__1_5, :cumret__1_20]
dsfilters = ["", "RES", "RESF"]
dsspan = 0:4
resmats = Dict()
for i in varsformeans
    resmats[i] = ones(Union{Float64,Missing}, 5,5)
    resmats["series_$(i)"] = Dict()
end
eads = [:everyEAD, Symbol("aroundEADm1:1:1"), Symbol("aroundEADm5:1:m1"), Symbol("aroundEAD1:1:5"), :EAD]
resWead = Dict()
for i in eads
    resWead[i] = Dict()
    for ds in dsspan
        resWead[i][ds] = deepcopy(resmats)
    end
end

resWead = @time computemeans(aggDicFreq, quintileids, resWead, eads, varsformeans, dsfilters, dsspan)

include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
for ds in dsspan
    for ead in eads
        spec = resWead[ead][ds]
        foo = concatspecststats(resWead[ead][ds], varsformeans)
        nead = replace(String(ead), ":"=>"_")
        foo = replace(foo, missing=>NaN)
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/AVGs/ds$(ds)_$(nead).csv", DataFrame(foo))
    end
end

print("a")
include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")
for ds in 1:4
    for ead in [:everyEAD, :EAD]
        print("$ead $ds")
        spec2 = resWead[ead][0]
        spec1 = resWead[ead][ds]
        foo = concatspecststatsDiffs(spec1, spec2, varsformeans)
        nead = replace(String(ead), ":"=>"_")
        foo = replace(foo, missing=>NaN)
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/AVGs/DIFFDS_ds$(ds)_$(nead).csv", DataFrame(foo))
    end
end

print("b")
for ead in [Symbol("aroundEADm1:1:1"), Symbol("aroundEADm5:1:m1"), Symbol("aroundEAD1:1:5"), :EAD]
    for ds in 0:4
        print("$ead $ds")
        spec2 = resWead[:everyEAD][ds]
        spec1 = resWead[ead][ds]
        foo = concatspecststatsDiffs(spec1, spec2, varsformeans)
        nead = replace(String(ead), ":"=>"_")
        foo = replace(foo, missing=>NaN)
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/AVGs/DIFFEAD_ds$(ds)_$(nead).csv", DataFrame(foo))
    end
end


print("c")
varsformeans = [:aggSent_RES, :aggSent_CMPNY, :aggSent_MRG, :aggSent_RESF]
for ead in [:everyEAD, Symbol("aroundEADm1:1:1"), Symbol("aroundEADm5:1:m1"), Symbol("aroundEAD1:1:5"), :EAD]
    for ds in 0:4
        print("$ead $ds")
        spec = resWead[ead][ds]
        foo = concatspecststatsDiffsTopics(spec, varsformeans, :aggSent_)
        nead = replace(String(ead), ":"=>"_")
        foo = replace(foo, missing=>NaN)
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/AVGs/DIFFsentTOPIC_ds$(ds)_$(nead).csv", DataFrame(foo))
    end
end


print("d")
varsformeans = [:sum_perNbStories_RES, :sum_perNbStories_CMPNY, :sum_perNbStories_MRG, :sum_perNbStories_RESF]
for ead in [:everyEAD, Symbol("aroundEADm1:1:1"), Symbol("aroundEADm5:1:m1"), Symbol("aroundEAD1:1:5"), :EAD]
    for ds in 0:4
        print("$ead $ds")
        spec = resWead[ead][ds]
        foo = concatspecststatsDiffsTopics(spec, varsformeans, :sum_perNbStories_)
        nead = replace(String(ead), ":"=>"_")
        foo = replace(foo, missing=>NaN)
        CSV.write("/run/media/nicolas/Research/SummaryStats/MarieTables/AVGs/DIFFcoverageTOPIC_ds$(ds)_$(nead).csv", DataFrame(foo))
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


for doublesort in [0]#0:4
    print("\n\n\n\n\n\n\n\n\nDOUBLESOOOOORT : $doublesort \n\n\n\n\n\n\n\n\n\n")
    #:EAD, :everyEAD
    eadchoice = :everyEAD
    cptfvars = [:cumret, :aggSent_, :ret__1_5, :ret__1_3, Symbol("ret__-5_-1"), Symbol("aggSent__-1_0"), Symbol("aggSent__-5_-1"), Symbol("aggSent__-20_-1"), Symbol("aggSent__-60_-1"),
                Symbol("aggSent_RES_-1_0"), Symbol("aggSent_RES_-5_-1"), Symbol("aggSent_RES_-20_-1"), Symbol("aggSent_RES_-60_-1"), :ret__1_20];
    cptfvarsNOMINUS = [Symbol(replace(String(x), "-"=>"m")) for x in cptfvars]
    resdic = Dict()
    for ptf in [1]#[x*10+y for x in 1:5 for y in 1:5]
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


include("$(laptop)/DescriptiveStats/Stats_processing_help.jl")

ptfDF = @time keepgoodcolumns(copy(aggDicFreq[1]), ["", "RES", "RESF"])

####!!! I should group by ptf for the surprise series!!!
####!!! Individual suprise should group by permno -> done
####!!! I should have market return etc for the future controls!!!
####!!! Lagged returns -> done
####!!! Compute the market surprise -> done
vars = [((:sum_perSent_, :sum_perNbStories_), (:sum_perSent_, :sum_perNbStories_)),
        ((:sum_perSent_RESF, :sum_perNbStories_RESF), (:sum_perSent_RES, :sum_perNbStories_RES)),
        ((:sum_perSent_, :sum_perNbStories_), (:sum_perSent_RES, :sum_perNbStories_RES))]
windows = [(60, 5), (20,5), (60,2), (20,2)]
excluderecent = true

ptfDF[:perid] = Int.(ptfDF[:perid])

stockSurp = @time computesurprises(ptfDF, vars, windows)

LTspecs = [(60, :aggSent_), (60, :aggSent_RESF), (20, :aggSent_), (20, :aggSent_RESF),
            (60, :aggSent_), (60, :aggSent_RESF), (20, :aggSent_), (20, :aggSent_RESF)]
STspecs = [(5, :aggSent_RES), (5, :aggSent_RES), (5, :aggSent_RES), (5, :aggSent_RES),
            (2, :aggSent_RES), (2, :aggSent_RES), (2, :aggSent_RES), (2, :aggSent_RES)]
mktSurp = @time marketSurprises(ptfDF, LTspecs, STspecs, "VW")

chosenvars = [:sum_perSent_, :sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES]
HMLsuprs = HMLspreads(HMLDic, chosenvars, "VW", true)
FFfactors = CSV.read("/run/media/nicolas/Research/FF/dailyFactors.csv")[1:3776,:]
todate = x -> Date(string(x),"yyyymmdd")
dates = todate.(FFfactors[:Date])
ymonth = Dates.yearmonth.(dates)
months = Dates.month.(dates)
weekdays = Dates.dayname.(dates)
ys = Dates.year.(dates)
wmy = []
for (i,j,k) in zip(Dates.week.(dates), ys,months)
    push!(wmy, "$i $j $k")
end
qy = []
for (i,j) in zip(Dates.quarterofyear.(dates), ys)
    push!(qy, "$i $j")
end


chosenvars = [:aggSent_]
w_vars = [Symbol("w_$(x)") for x in chosenvars]
mktsent = EW_VW_series(ptfDF, w_vars, chosenvars)

dailyseries = hcat(DataFrame(Dict("date"=>dates)), DataFrame(mktSurp), DataFrame(HMLsuprs), mktsent)
a = by(dailyseries, :date) do df
    res = Dict()
    # for i in names(dailyseries)[2:end]
    #     res[i] = cumret(df[i])
    # end
    res[:x1] = custom_sum(df[:HML_VW_sum_perSent_]) ./ custom_sum(df[:HML_VW_sum_perNbStories_])
    DataFrame(res)
end

for i in names(a)[2:end]
    print("std $i : $(NaNMath.std(collect(skipmissing(a[i])))) \n")
    print("mean $i : $(NaNMath.mean(collect(skipmissing(a[i])))) \n")
end

comparets = hcat(baker, a[1:155,:])
CSV.write("/run/media/nicolas/Research/SummaryStats/tscompare.csv", comparets)
@rput comparets

b = hcat(ys, dailyseries)
eee = by(b, :x1) do df
    res = Dict()
    res[:avg] = custom_mean(df[:EW_aggSent_])
end

x = []
for i in 2003:2017
    jan = b[b[:x1].==2010,:]
    fev = b[b[:x1].==i,:]
    jan = jan[:surpHML_ALL_RES_60_5]; fev = fev[:surpHML_ALL_RES_60_5]
    push!(x, Rttest(jan, fev))
end

prov = hcat(prov, eee, x)
CSV.write("/run/media/nicolas/Research/SummaryStats/yearlycompare.csv", prov)

a = dailyseries[:EW_aggSent_]
@rput a; R"plot(a)"


ptfDF = @time concat_groupInvariant_vars(ptfDF, DataFrame(mktSurp), size(ptfDF, 2))

# plot the time series
# a = bbbb[Symbol("LT20|aggSent_RESF_ST2|aggSent_RES")]
# @rput a
# R"plot(a, type='l')"
# custom_mean(a)

@time ptfDF[:surp_RESF_RES_60_5] = surpriseSeriesDF(ptfDF, 60, 5, (:sum_perSent_RESF, :sum_perNbStories_RESF), (:sum_perSent_RES, :sum_perNbStories_RES))
ptfDF[:surp_ALL_RES_60_5] = surpriseSeriesDF(ptfDF, 60, 5, (:sum_perSent_, :sum_perNbStories_), (:sum_perSent_RES, :sum_perNbStories_RES))
ptfDF[:surp_RESF_RES_20_5] = surpriseSeriesDF(ptfDF, 20, 5, (:sum_perSent_RESF, :sum_perNbStories_RESF), (:sum_perSent_RES, :sum_perNbStories_RES))
ptfDF[:surp_ALL_RES_20_5] = surpriseSeriesDF(ptfDF, 20, 5, (:sum_perSent_, :sum_perNbStories_), (:sum_perSent_RES, :sum_perNbStories_RES))
ptfDF[:surp_RESF_RES_60_2] = surpriseSeriesDF(ptfDF, 60, 2, (:sum_perSent_RESF, :sum_perNbStories_RESF), (:sum_perSent_RES, :sum_perNbStories_RES))
ptfDF[:surp_ALL_RES_60_2] = surpriseSeriesDF(ptfDF, 60, 2, (:sum_perSent_, :sum_perNbStories_), (:sum_perSent_RES, :sum_perNbStories_RES))
surprisevars = [:surp_RESF_RES_60_5, :surp_ALL_RES_60_5, :surp_RESF_RES_20_5, :surp_ALL_RES_20_5, :surp_RESF_RES_60_2, :surp_ALL_RES_60_2]
ptfDF[:EAD] = replace(ptfDF[:EAD], missing=>0)
ptfDF[:ND] = replace(ptfDF[:sum_perNbStories_] ./ ptfDF[:sum_perNbStories_], missing=>0)
cptfvars = [[:cumret, :momrank, :bmdecile, :sizedecile, :EAD, :ND]; surprisevars];
hmlsurprisevars = [:surpHML_ALL_RES_60_5, :surpHML_ALL_RES_20_5, :surpHML_ALL_RES_60_2, :surpHML_ALL_RES_20_2, :surpHML_ALL_RES_60_10]
paneldf = @time createPanelDF(ptfDF, HMLDic, ptfvars = cptfvars, runninglags = [60,20,5], tdperiods = tdperiods, HMLvars = [:sum_perNbStories_, :cumret, :aggSent_, :aggSent_RES]);
namesWNOminus = [Symbol(replace(replace(String(x), "t_-"=>"t__-"), "-"=>"m")) for x in names(paneldf)]
names!(paneldf, namesWNOminus)
a=paneldf[[[:permno, :perid, :cumret, :bmdecile, :sizedecile, :momrank, :EAD, :ND, :HML_VW_aggSent_, :Mkt_RF, :SMB, :HML, :Mom] ; cptfvars ; hmlsurprisevars]]
a[:invertmom] = replace(abs.(a[:momrank] .- 11), missing=>5)
a[:aggSent_] = ptfDF[:aggSent_]
a[:ret__1_5] = ptfDF[:ret__1_5]
a[:ret__1_20] = ptfDF[:ret__1_20]
a[:ret__0_1] = ptfDF[:ret__0_1]
a[:anomsum] = a[:invertmom] .+ a[:bmdecile] .+ a[:sizedecile]
@time @rput a
R"library(plm)"
@time R"E <- pdata.frame(a, index=c('permno', 'perid'))";
@time R"mod3 <- plm(ret__1_20 ~ surp_RESF_RES_60_2*bmdecile + surp_RESF_RES_60_2:EAD + surp_RESF_RES_60_2:ND + surpHML_ALL_RES_60_5*bmdecile + surpHML_ALL_RES_60_5:EAD + surpHML_ALL_RES_60_5:ND + Mkt_RF + SMB + HML + Mom, data = E, model = 'within')";
@time R"res = summary(mod3)"
@time R"mod <- plm(cumret ~ surpHML_ALL_RES_60_5*bmdecile*EAD*ND + Mkt_RF + SMB + HML + Mom, data = E, model = 'within')";
R"res = summary(mod)"
@time R"mod1 <- plm(ret__1_5 ~ surpHML_ALL_RES_60_5*bmdecile + surpHML_ALL_RES_60_5:EAD + surpHML_ALL_RES_60_5:ND + Mkt_RF + SMB + HML + Mom, data = E, model = 'within')";
@time R"res = summary(mod1)"
@time R"mod2 <- plm(ret__1_5 ~ surp_RESF_RES_60_2*bmdecile + surp_RESF_RES_60_2:EAD + surp_RESF_RES_60_2:ND + surpHML_ALL_RES_60_5*bmdecile + surpHML_ALL_RES_60_5:EAD + surpHML_ALL_RES_60_5:ND + Mkt_RF + SMB + HML + Mom, data = E, model = 'within')";
@time R"res = summary(mod2)"


for i in names(a)
    print("$i\n")
end





paneldf = hcat(paneldf, ptfDF[[Symbol("LT60|aggSent_RESF_ST5|aggSent_RES"), Symbol("LT60|aggSent__ST5|aggSent_RES")]],
                stockSurp[[names(stockSurp)[9], names(stockSurp)[13]]])
@time sort!(paneldf, [:permno, :perid])
paneldf = @time lagbypermno(paneldf, [:cumret], 1:5)
paneldf = @time mktretbypermno(paneldf,[:Mkt_RF, :SMB, :HML, :Mom], [5], "lead")
extras = [[names(stockSurp)[9], names(stockSurp)[13]]; [Symbol("LT60|aggSent_RESF_ST5|aggSent_RES"), Symbol("LT60|aggSent__ST5|aggSent_RES")] ; [Symbol("cumret_l$(x)") for x in 1:5] ; [:HML_lead5, :Mkt_RF_lead5, :Mom_lead5, :SMB_lead5]]
a=paneldf[[[:permno, :perid, :HML_VW_aggSent_, :Mkt_RF, :SMB, :HML, :Mom] ; cptfvars ; hmlsurprisevars; extras]]
names!(a, [[:permno, :perid, :HML_VW_aggSent_, :Mkt_RF, :SMB, :HML, :Mom] ; cptfvars ; hmlsurprisevars; [:S_all60_RES5, :S_RESF60_RES5, :Smkt_RESF60_RES5, :Smkt_all60_RES5]; [Symbol("cumret_l$(x)") for x in 1:5] ; [:HML_lead5, :Mkt_RF_lead5, :Mom_lead5, :SMB_lead5]])
a[:invertmom] = replace(abs.(a[:momrank] .- 11), missing=>5)
a[:aggSent_] = ptfDF[:aggSent_]
a[:ret__1_5] = ptfDF[:ret__1_5]
a[:ret__1_20] = ptfDF[:ret__1_20]
a[:ret__0_1] = ptfDF[:ret__0_1]
a[:anomsum] = a[:invertmom] .+ a[:bmdecile] .+ a[:sizedecile]
@time @rput a
R"library(plm)"
R"library(stargazer)"
@time R"E <- pdata.frame(a, index=c('permno', 'perid'))";
@time R"mod4 <- plm(ret__1_5 ~ S_all60_RES5*bmdecile + S_all60_RES5:ND + Smkt_all60_RES5*bmdecile*ND + surpHML_ALL_RES_60_5*bmdecile*ND + Mkt_RF_lead5 + SMB_lead5 + HML_lead5 + Mom_lead5 + cumret_l1 + cumret_l2 + cumret_l3 + cumret_l4 + cumret_l5, data = E, model = 'within')";
@time R"res4 = summary(mod4)"
R"print(res4)";
R"stargazer(mod4, mod5, mod6, mod7, mod8)"


@time R"mod5 <- plm(ret__1_5 ~ surpHML_ALL_RES_60_5*bmdecile*ND + Mkt_RF_lead5 + SMB_lead5 + HML_lead5 + Mom_lead5 + cumret_l1 + cumret_l2 + cumret_l3 + cumret_l4 + cumret_l5, data = E, model = 'within')";
@time R"res5 = summary(mod5)"
R"print(res5)";

@time R"mod6 <- plm(ret__1_5 ~ S_all60_RES5*bmdecile + S_all60_RES5:ND + Smkt_all60_RES5*bmdecile*ND + Mkt_RF_lead5 + SMB_lead5 + HML_lead5 + Mom_lead5, data = E, model = 'within')";
@time R"res6 = summary(mod6)"
R"print(res6)";

@time R"mod7 <- plm(ret__1_5 ~ S_all60_RES5*bmdecile + S_all60_RES5 + Smkt_all60_RES5*bmdecile*ND*EAD + surpHML_ALL_RES_60_5*bmdecile*ND*EAD + Mkt_RF_lead5 + SMB_lead5 + HML_lead5 + Mom_lead5, data = E, model = 'within')";
@time R"res7 = summary(mod7)"
R"print(res7)";


@time R"mod8 <- plm(cumret ~ S_all60_RES5*bmdecile + S_all60_RES5:ND + Smkt_all60_RES5*bmdecile*ND + surpHML_ALL_RES_60_5*bmdecile*ND + Mkt_RF + SMB + HML + Mom + cumret_l1 + cumret_l2 + cumret_l3 + cumret_l4 + cumret_l5, data = E, model = 'within')";
@time R"res8 = summary(mod8)"
R"print(res8)";

@time R"mod9 <- plm(ret__1_5 ~ S_all60_RES5*bmdecile + S_all60_RES5 + Smkt_all60_RES5*bmdecile*ND*EAD + surpHML_ALL_RES_60_5*bmdecile*ND*EAD, data = E, model = 'within')";
@time R"res9 = summary(mod9)"
R"print(res9)";


std(a[:surpHML_ALL_RES_60_5])



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
