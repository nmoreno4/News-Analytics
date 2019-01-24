using QueryMongo, DataFrames, Dates, TSmanip, Wfcts, LoadFF, Statistics, JLD2, Windsorize,
      TSmap, Plots, CSV, TrendCycle, Misc, FindFcts, DataStructures, ShiftedArrays,
      RegressionTables, FixedEffectModels, FixedEffects, CovarianceMatrices, RDatasets

iArrays = [Int[], Union{Int, Missing}[], DateTime[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[],
           Union{Float64, Missing}[], Union{Float64, Missing}[], Union{Float64, Missing}[]]
vars = ["permno", "EAD", "date", "me", "nS_nov12H_0", "posSum_nov12H_0", "negSum_nov12H_0",
        "nS_RES_inc_RESF_excl_nov12H_0", "posSum_RES_inc_RESF_excl_nov12H_0", "negSum_RES_inc_RESF_excl_nov12H_0",
        "nS_RESF_inc_nov12H_0", "posSum_RESF_inc_nov12H_0", "negSum_RESF_inc_nov12H_0"]
NSMat = @time gatherData((1,3776), vars, iArrays; ptfnames = ["ALL"], ptfs = [("tdF")])

# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/NS_ALL.jld2" NSMat
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_ALL.jld2"


iArrays = [Int[], DateTime[], Union{Float64, Missing}[], Union{Int, Missing}[], Union{Int, Missing}[]]
vars = ["permno", "date", "retadj", "ranksize", "rankbm"]
rankretMat = @time gatherData((1,3776), vars, iArrays; ptfnames = ["ALL"], ptfs = [("tdF")])

# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/NS_rankretMat_ALL.jld2" rankretMat
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_rankretMat_ALL.jld2"


NSMat = NSMat["ALL"]
sort!(NSMat, [:permno, :date])

NSMat = @time join(NSMat, rankretMat["ALL"], on=[:permno, :date], kind=:inner)

##############################################
# Compute News Surprises on day prior to EAD #
##############################################
ALL = [:nS_nov12H_0, :posSum_nov12H_0, :negSum_nov12H_0]
RES = [:nS_RES_inc_RESF_excl_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0]
RESF = [:nS_RESF_inc_nov12H_0, :posSum_RESF_inc_nov12H_0, :negSum_RESF_inc_nov12H_0]



function preSurprise(crtdf, newsTopics; WS="VW")
    nTopic = newsTopics[1]
    crtdf[:NS_LT] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
    nTopic = newsTopics[2]
    crtdf[:NS_ST] = @time aggNewsByPeriod(dayID, crtdf, nTopic[1], nTopic[2], nTopic[3], :me)[:NS]
    # add the possibility to use the me in t-3
    crtdf[:dailyRebal] = @time rebalPeriods(crtdf, :perID; rebalPer=(dayofmonth, 1:32) )
    crtdf[:driftW] = @time driftWeights(crtdf, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:perID, NS=true)
    return crtdf
    # Nsurp = @time NSsuprise(crtdf, LTspan,  STspan, 1,1, "EAD", newsTopics)
    # if doaggregate
    #     Nsurp = sort(varWeighter(Nsurp, :Nsurp, :date, :driftW), :date)
    #     Nsurp = deleteMissingRows(Nsurp, :Nsurp)
    # end
    # return Nsurp
end



newsTopics = (ALL,RES)
crtdf = preSurprise(NSMat, newsTopics; WS="VW")
# Most likely shorter horizons for both are justified
LTspan, STspan = Dates.Month(1), Dates.Day(1)
a = @time NSsuprise(crtdf, newsTopics, LTspan, STspan)
LTspan, STspan = Dates.Month(2), Dates.Day(3)
aa = @time NSsuprise(crtdf, newsTopics, LTspan, STspan)

newsTopics = (RESF,RES)
crtdf = @time preSurprise(NSMat, newsTopics; WS="VW")
# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/preSurprise.jld2" crtdf
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/preSurprise.jld2"
# Most likely shorter horizons for both are justified
LTspan, STspan = Dates.Month(1), Dates.Day(1)
# Started at 15:34 --> expect it to last approx 9 hours
LT1ST1 = @time NSsuprise(crtdf, LTspan,  STspan, 1,1, 1, newsTopics) # Takes a fucking long time
# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/LT1ST1.jld2" LT1ST1
# JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/LT1ST1.jld2"
LT1ST1 = unique!(deleteMissingRows(LT1ST1, :date))
rename!(LT1ST1, :Nsurp=>:Nsurp_1_LT1ST1)
LTspan, STspan = Dates.Month(2), Dates.Day(3)
LT2ST3 = @time NSsuprise(crtdf, LTspan,  STspan, 1,1, 1, newsTopics)
# @time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/LT2ST3.jld2" LT2ST3
# JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/LT2ST3.jld2"
LT2ST3 = deleteMissingRows(LT2ST3, :date)
rename!(LT2ST3, :Nsurp=>:Nsurp_1_LT2_ST3)
LT2ST3EAD = @time NSsuprise(crtdf, LTspan,  STspan, 1,1,"EAD", newsTopics)
LT2ST3EAD = deleteMissingRows(LT2ST3EAD, :date)
rename!(LT2ST3EAD, :Nsurp=>:Nsurp_EAD_LT2_ST3, :driftW=>:W_EAD_LT2_ST3)



deletecols!(a, :driftW)
b = @time join(NSMat, a, on=[:permno, :date], kind=:left)
deletecols!(aa, :driftW)
bb = @time join(NSMat, aa, on=[:permno, :date], kind=:left)
deletecols!(aaa, :driftW)
bbb = @time join(NSMat, aaa, on=[:permno, :date], kind=:left)
deletecols!(aaaaEAD, :driftW)
df = @time join(NSMat, LT1ST1, on=[:permno, :date], kind=:left)
df = @time join(df, LT2ST3, on=[:permno, :date], kind=:left)
@time JLD2.@save "/home/nicolas/Data/Prcessed Data MongoDB/Surp_2.jld2" df
# @time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/Surp_LT2_ST3.jld2"

c = b[findall(replace(b[:,:EAD], missing=>0) .== 1), [:permno, :date, :EAD, :Nsurp, :retadj, :rankbm, :ranksize]]
length(collect(skipmissing(a[:Nsurp])))


for i in names(df)
    print("$i \n")
end

@time unique!(df)

nTopic = copy(ALL)
ALLNS = @time aggNewsByPeriod(dayID, df, nTopic[1], nTopic[2], nTopic[3], :me)
rename!(ALLNS, :NS=>:NS_ALL, :perID=>:date)
df = @time join(df, ALLNS[[:date, :permno, :NS_ALL]], on=[:date, :permno], kind=:left)
nTopic = copy(RES)
RESNS = @time aggNewsByPeriod(dayID, df, nTopic[1], nTopic[2], nTopic[3], :me)
rename!(RESNS, :NS=>:NS_RES, :perID=>:date)
df = @time join(df, RESNS[[:date, :permno, :NS_RES]], on=[:date, :permno], kind=:left)
nTopic = copy(RESF)
RESFNS = @time aggNewsByPeriod(dayID, df, nTopic[1], nTopic[2], nTopic[3], :me)
rename!(RESFNS, :NS=>:NS_RESF, :perID=>:date)
df = @time join(df, RESFNS[[:date, :permno, :NS_RESF]], on=[:date, :permno], kind=:left)


GroMat = df[replace(df[:rankbm], missing=>NaN).<=2,[:date, :me, :permno, :rankbm, :Nsurp_1_LT1ST1, :Nsurp_1_LT2_ST3, :NS_ALL, :NS_RESF, :NS_RES, :EAD]]
ValMat = df[replace(df[:rankbm], missing=>NaN).>=9,[:date, :me, :permno, :rankbm, :Nsurp_1_LT1ST1, :Nsurp_1_LT2_ST3, :NS_ALL, :NS_RESF, :NS_RES, :EAD]]
BigMkt = df[replace(df[:ranksize], missing=>NaN).>9,[:date, :me, :permno, :rankbm, :Nsurp_1_LT1ST1, :Nsurp_1_LT2_ST3, :NS_ALL, :NS_RESF, :NS_RES, :EAD]]
BigMktAnnouncers = BigMkt[replace(BigMkt[:EAD], missing=>NaN).==1,[:date, :me, :permno, :rankbm, :Nsurp_1_LT1ST1, :Nsurp_1_LT2_ST3, :NS_ALL, :NS_RESF, :NS_RES]]

#recompute driftW
WS = "VW"
GroMat[:dailyRebal] = @time rebalPeriods(GroMat, :date; rebalPer=(dayofmonth, 1:32) )
GroMat[:driftW] = @time driftWeights(GroMat, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date, NS=true)
Grosurp1 = @time rename!(sort(varWeighter(GroMat[GroMat[:rankbm].<=2, :], :Nsurp_1_LT1ST1, :date, :driftW), :date), :Nsurp_1_LT1ST1=>:GroSurp1)
Grosurp2 = @time rename!(sort(varWeighter(GroMat[GroMat[:rankbm].<=2, :], :Nsurp_1_LT2_ST3, :date, :driftW), :date), :Nsurp_1_LT2_ST3=>:GroSurp2)
GroNS_ALL = @time rename!(sort(varWeighter(GroMat[GroMat[:rankbm].<=2, :], :NS_ALL, :date, :driftW), [:date]), :NS_ALL=>:GroNS_ALL)
GroNS_RESF = @time rename!(sort(varWeighter(GroMat[GroMat[:rankbm].<=2, :], :NS_RESF, :date, :driftW), :date), :NS_RESF=>:GroNS_RESF)
GroNS_RES = @time rename!(sort(varWeighter(GroMat[GroMat[:rankbm].<=2, :], :NS_RES, :date, :driftW), :date), :NS_RES=>:GroNS_RES)
ValMat[:dailyRebal] = @time rebalPeriods(ValMat, :date; rebalPer=(dayofmonth, 1:32) )
ValMat[:driftW] = @time driftWeights(ValMat, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date, NS=true)
Valsurp1 = @time rename!(sort(varWeighter(ValMat[ValMat[:rankbm].>=9, :], :Nsurp_1_LT1ST1, :date, :driftW), :date), :Nsurp_1_LT1ST1=>:ValSurp1)
Valsurp2 = @time rename!(sort(varWeighter(ValMat[ValMat[:rankbm].>=9, :], :Nsurp_1_LT2_ST3, :date, :driftW), :date), :Nsurp_1_LT2_ST3=>:ValSurp2)
ValNS_ALL = @time rename!(sort(varWeighter(ValMat[ValMat[:rankbm].>=9, :], :NS_ALL, :date, :driftW), :date), :NS_ALL=>:ValNS_ALL)
ValNS_RESF = @time rename!(sort(varWeighter(ValMat[ValMat[:rankbm].>=9, :], :NS_RESF, :date, :driftW), :date), :NS_RESF=>:ValNS_RESF)
ValNS_RES = @time rename!(sort(varWeighter(ValMat[ValMat[:rankbm].>=9, :], :NS_RES, :date, :driftW), :date), :NS_RES=>:ValNS_RES)
df[:dailyRebal] = @time rebalPeriods(df, :date; rebalPer=(dayofmonth, 1:32) )
df[:driftW] = @time driftWeights(df, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date, NS=true)
Mktsurp1 = @time rename!(sort(varWeighter(df, :Nsurp_1_LT1ST1, :date, :driftW), :date), :Nsurp_1_LT1ST1=>:MktSurp1)
Mktsurp2 = @time rename!(sort(varWeighter(df, :Nsurp_1_LT2_ST3, :date, :driftW), :date), :Nsurp_1_LT2_ST3=>:MktSurp2)
Mkt_NS_RESF = @time rename!(sort(varWeighter(df, :NS_LT, :date, :driftW), :date), :NS_LT=>:Mkt_NS_RESF)
Mkt_NS_RES = @time rename!(sort(varWeighter(df, :NS_ST, :date, :driftW), :date), :NS_ST=>:Mkt_NS_RES)
Mkt_ret = @time rename!(sort(varWeighter(df, :retadj, :date, :driftW), :date), :retadj=>:Mkt_ret)
MktNS_ALL = @time rename!(sort(varWeighter(df, :NS_ALL, :date, :driftW), :date), :NS_ALL=>:MktNS_ALL)
MktNS_RESF = @time rename!(sort(varWeighter(df, :NS_RESF, :date, :driftW), :date), :NS_RESF=>:MktNS_RESF)
MktNS_RES = @time rename!(sort(varWeighter(df, :NS_RES, :date, :driftW), :date), :NS_RES=>:MktNS_RES)
BigMkt[:dailyRebal] = @time rebalPeriods(BigMkt, :date; rebalPer=(dayofmonth, 1:32) )
BigMkt[:driftW] = @time driftWeights(BigMkt, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date, NS=true)
BigMktsurp1 = @time rename!(sort(varWeighter(BigMkt, :Nsurp_1_LT1ST1, :date, :driftW), :date), :Nsurp_1_LT1ST1=>:BigMktSurp1)
BigMktsurp2 = @time rename!(sort(varWeighter(BigMkt, :Nsurp_1_LT2_ST3, :date, :driftW), :date), :Nsurp_1_LT2_ST3=>:BigMktSurp2)
BigMktNS_ALL = @time rename!(sort(varWeighter(BigMkt, :NS_ALL, :date, :driftW), :date), :NS_ALL=>:BigMktNS_ALL)
BigMktNS_RESF = @time rename!(sort(varWeighter(BigMkt, :NS_RESF, :date, :driftW), :date), :NS_RESF=>:BigMktNS_RESF)
BigMktNS_RES = @time rename!(sort(varWeighter(BigMkt, :NS_RES, :date, :driftW), :date), :NS_RES=>:BigMktNS_RES)
BigMktAnnouncers[:dailyRebal] = @time rebalPeriods(BigMktAnnouncers, :date; rebalPer=(dayofmonth, 1:32) )
BigMktAnnouncers[:driftW] = @time driftWeights(BigMktAnnouncers, WS, rebalCol=:dailyRebal, meCol=:me, stockCol=:permno, dateCol=:date, NS=true)
BigMktAnnouncerssurp1 = @time rename!(sort(varWeighter(BigMktAnnouncers, :Nsurp_1_LT1ST1, :date, :driftW), :date), :Nsurp_1_LT1ST1=>:BigMktAnnouncerssurp1)
BigMktAnnouncerssurp2 = @time rename!(sort(varWeighter(BigMktAnnouncers, :Nsurp_1_LT2_ST3, :date, :driftW), :date), :Nsurp_1_LT2_ST3=>:BigMktAnnouncerssurp2)
BigMktAnnouncersNS_ALL = @time rename!(sort(varWeighter(BigMktAnnouncers, :NS_ALL, :date, :driftW), :date), :NS_ALL=>:BigMktAnnouncersNS_ALL)
BigMktAnnouncersNS_RESF = @time rename!(sort(varWeighter(BigMktAnnouncers, :NS_RESF, :date, :driftW), :date), :NS_RESF=>:BigMktAnnouncersNS_RESF)
BigMktAnnouncersNS_RES = @time rename!(sort(varWeighter(BigMktAnnouncers, :NS_RES, :date, :driftW), :date), :NS_RES=>:BigMktAnnouncersNS_RES)

df = @time join(df, Grosurp1, on=:date, kind=:left)
df = @time join(df, Grosurp2, on=:date, kind=:left)
df = @time join(df, Valsurp1, on=:date, kind=:left)
df = @time join(df, Valsurp2, on=:date, kind=:left)
df = @time join(df, Mktsurp1, on=:date, kind=:left)
df = join(df, Mktsurp2, on=:date, kind=:left)
df = join(df, Mkt_NS_RESF, on=:date, kind=:left)
df = join(df, Mkt_NS_RES, on=:date, kind=:left)
df = join(df, Mkt_ret, on=:date, kind=:left)
df = join(df, BigMktsurp1, on=:date, kind=:left)
df = join(df, BigMktsurp2, on=:date, kind=:left)
df = join(df, BigMktAnnouncerssurp1, on=:date, kind=:left)
df = join(df, BigMktAnnouncerssurp2, on=:date, kind=:left)
print("Some done")

df = join(df, GroNS_ALL, on=:date, kind=:left)
df = join(df, GroNS_RES, on=:date, kind=:left)
df = join(df, GroNS_RESF, on=:date, kind=:left)
df = join(df, ValNS_ALL, on=:date, kind=:left)
df = join(df, ValNS_RES, on=:date, kind=:left)
df = join(df, ValNS_RESF, on=:date, kind=:left)
df = join(df, MktNS_ALL, on=:date, kind=:left)
df = join(df, MktNS_RES, on=:date, kind=:left)
print("More done")
df = join(df, MktNS_RESF, on=:date, kind=:left)
df = join(df, BigMktNS_ALL, on=:date, kind=:left)
df = join(df, BigMktNS_RES, on=:date, kind=:left)
df = join(df, BigMktNS_RESF, on=:date, kind=:left)
df = join(df, BigMktAnnouncersNS_ALL, on=:date, kind=:left)
df = join(df, BigMktAnnouncersNS_RES, on=:date, kind=:left)
df = join(df, BigMktAnnouncersNS_RESF, on=:date, kind=:left)

df[:Date] = Date.(df[:date])
FF = FFfactors()
df = @time join(df, FF[[:Date, :Mkt_RF, :SMB, :HML, :RF, :Mom, :CMA, :RMW]], on=:Date, kind=:left)

BigMktAnnouncersNS_RESF = nothing, BigMktAnnouncersNS_RES = nothing, BigMktAnnouncersNS_ALL = nothing,BigMktNS_RESF = nothing, BigMktNS_RES = nothing, BigMktNS_ALL = nothing,MktNS_RESF = nothing, MktNS_RES = nothing, MktNS_ALL = nothing,ValNS_RESF = nothing, ValNS_RES = nothing, ValNS_ALL = nothing,GroNS_RESF = nothing, GroNS_RES = nothing, GroNS_ALL = nothing,BigMktAnnouncerssurp1 = nothing, BigMktsurp1 = nothing, Mktsurp1 = nothing, Valsurp1, Grosurp1,Mkt_NS_RES, Mkt_NS_RES, Mkt_ret
ValMat = nothing; BigMkt = nothing; BigMktAnnouncers = nothing

ADFTest(collect(skipmissing(a[:Mkt_NS_RES])), :none, 40)
std(skipmissing(MktNS_ALL[:MktNS_ALL]))
# run the joins with the sentiments?""

@time a = by(df, :date) do xdf
    res = Dict()
    res[:RES_coverage] = sum(skipmissing(xdf[:nS_RES_inc_RESF_excl_nov12H_0]))
    res[:ALL_coverage] = sum(skipmissing(xdf[:nS_nov12H_0]))
    DataFrame(res)
end
a[:ALL_coverage] = windsorize(a[:ALL_coverage], 99.9, 0)
a[:RES_coverage] = windsorize(a[:RES_coverage], 99.95, 0)
a[:lagALL_coverage] = lag(a[:ALL_coverage])
a[:lagRES_coverage] = lag(a[:RES_coverage])
a = @time join(df[[:date]], a, on=[:date], kind=:left)
df[:ALL_coverage] = a[:ALL_coverage]
df[:RES_coverage] = a[:RES_coverage]
df[:lagALL_coverage] = a[:lagALL_coverage]
df[:lagRES_coverage] = a[:lagRES_coverage]


colstoremove = [:nS_RESF_inc_nov12H_0, :nS_RES_inc_RESF_excl_nov12H_0, :nS_nov12H_0, :negSum_RESF_inc_nov12H_0, :negSum_RES_inc_RESF_excl_nov12H_0, :negSum_nov12H_0, :posSum_RESF_inc_nov12H_0, :posSum_RES_inc_RESF_excl_nov12H_0, :posSum_nov12H_0, :perID, :Date]
deletecols!(df, colstoremove)


df[:StockCategorical] =  categorical(df[:permno])
df[:YearCategorical] =  categorical(Dates.year.(df[:date]))
df[:YearmonthCategorical] =  categorical(Dates.yearmonth.(df[:date]))
df[:DateCategorical] =  categorical(df[:date])
@time a = by(df, :permno) do xdf
    res = Dict()
    res[:lagValSurp1] = lag(xdf[:ValSurp1])
    res[:lagGroSurp1] = lag(xdf[:GroSurp1])
    res[:lagMktSurp1] = lag(xdf[:MktSurp1])
    res[:lagValSurp2] = lag(xdf[:ValSurp2])
    res[:lagGroSurp2] = lag(xdf[:GroSurp2])
    res[:lagMktSurp2] = lag(xdf[:MktSurp2])
    res[:lagMkt_NS_RES] = lag(xdf[:Mkt_NS_RES])
    res[:lagMkt_NS_RESF] = lag(xdf[:Mkt_NS_RESF])
    res[:lagMkt_ret] = lag(xdf[:Mkt_ret])
    res[:lagBigMktSurp1] = lag(xdf[:BigMktSurp1])
    res[:lagBigMktSurp2] = lag(xdf[:BigMktSurp2])
    res[:lagBigMktAnnouncerssurp1] = lag(xdf[:BigMktAnnouncerssurp1])
    res[:lagBigMktAnnouncerssurp2] = lag(xdf[:BigMktAnnouncerssurp2])
    res[:lagNSurp1] = lag(xdf[:Nsurp_1_LT1ST1])
    res[:lagNSurp2] = lag(xdf[:Nsurp_1_LT2_ST3])
    res[:lagGroNS_ALL] = lag(xdf[:GroNS_ALL])
    res[:lagValNS_ALL] = lag(xdf[:ValNS_ALL])
    res[:lagMktNS_ALL] = lag(xdf[:MktNS_ALL])
    res[:lagBigMktNS_ALL] = lag(xdf[:BigMktNS_ALL])
    res[:lagBigMktAnnouncersNS_ALL] = lag(xdf[:BigMktAnnouncersNS_ALL])
    res[:lagGroNS_RES] = lag(xdf[:GroNS_RES])
    res[:lagValNS_RES] = lag(xdf[:ValNS_RES])
    res[:lagMktNS_RES] = lag(xdf[:MktNS_RES])
    res[:lagBigMktNS_RES] = lag(xdf[:BigMktNS_RES])
    res[:lagBigMktAnnouncersNS_RES] = lag(xdf[:BigMktAnnouncersNS_RES])
    res[:lagGroNS_RESF] = lag(xdf[:GroNS_RESF])
    res[:lagValNS_RESF] = lag(xdf[:ValNS_RESF])
    res[:lagMktNS_RESF] = lag(xdf[:MktNS_RESF])
    res[:lagBigMktNS_RESF] = lag(xdf[:BigMktNS_RESF])
    res[:lagBigMktAnnouncersNS_RESF] = lag(xdf[:BigMktAnnouncersNS_RESF])
    res[:lagNS_ALL] = lag(xdf[:NS_ALL])
    res[:lagNS_RES] = lag(xdf[:NS_RES])
    res[:lagNS_RESF] = lag(xdf[:NS_RESF])
    res[:l1_f0] = windowRet(xdf[:retadj], (-1,0); missShortWindows=false)
    res[:l1_f1] = windowRet(xdf[:retadj], (-1,1); missShortWindows=false)
    res[:l0_f2] = windowRet(xdf[:retadj], (0,2); missShortWindows=false)
    res[:f1_f2] = windowRet(xdf[:retadj], (1,2); missShortWindows=false)
    res[:f1_f5] = windowRet(xdf[:retadj], (1,5); missShortWindows=false)
    res[:f1_f20] = windowRet(xdf[:retadj], (1,20); missShortWindows=false)
    res[:f1_f40] = windowRet(xdf[:retadj], (1,40); missShortWindows=false)
    res[:f20_f40] = windowRet(xdf[:retadj], (20,40); missShortWindows=false)
    res[:f1_f60] = windowRet(xdf[:retadj], (1,60); missShortWindows=false)
    res[:f40_f60] = windowRet(xdf[:retadj], (40,60); missShortWindows=false)
    res[:date] = xdf[:date]
    DataFrame(res)
end

# @time sort!(a, [:permno, :date])
# @time sort!(df, [:permno, :date])
# df[:lagNS_ALL] = a[:lagNS_ALL]
# df[:lagNS_RES] = a[:lagNS_RES]
# df[:lagNS_RESF] = a[:lagNS_RESF]
df = @time join(df, a, on=[:date, :permno], kind=:left)

JLD2.@save "/run/media/nicolas/Research/Data/Surprise/2supr.jld2" df
# JLD2.@load "/run/media/nicolas/Research/Data/Surprise/2supr.jld2"

#############################
# Regression Specifications #
#############################
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
m1 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp, vcov = robust))
m2 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp + lagMkt_ret, vcov = cluster(DateCategorical)))
m3 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp, fe = DateCategorical, vcov = cluster(DateCategorical)))
m4 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp, vcov = robust))
m5 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp + Mkt_ret, vcov = cluster(DateCategorical)))
m6 = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp, fe = YearmonthCategorical, vcov = cluster(DateCategorical)))


####### Base Specification - simple robust errors #######
length(collect(skipmissing(df[:NS_ALL])))
noresdf = df[findall(ismissing.(df[:NS_RES])),:]
noalldf = df[findall(ismissing.(df[:NS_ALL])),:]
alldf = df[.!ismissing.(df[:NS_ALL]),:]
resdf = df[.!ismissing.(df[:NS_RES]),:]
lagresdf = df[.!ismissing.(df[:lagNS_RES]),:]

lagalldf = df[.!ismissing.(df[:lagNS_ALL]),:]
lagnoresdf = df[ismissing.(df[:lagNS_RES]),:]
lagnoalldf = df[ismissing.(df[:lagNS_ALL]),:]
resfdf = df[.!ismissing.(df[:NS_RESF]),:]
surpdf1 = df[.!ismissing.(df[:Nsurp_1_LT1ST1]),:]
surpdf2 = df[.!ismissing.(df[:Nsurp_1_LT2_ST3]),:]
eaddf = df[.!ismissing.(df[:EAD]),:]
valdf = df[replace(df[:rankbm], missing=>NaN).>=9,:]
grodf = df[replace(df[:rankbm], missing=>NaN).<=2,:]



specname = "baseSpec1"
m1 = @time reg(surpdf1, @model(retadj ~ lagMktSurp1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf1, @model(retadj ~ lagMktSurp1 + Nsurp_1_LT1ST1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf1, @model(l1_f1 ~ lagMktSurp1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf1, @model(l1_f1 ~ lagMktSurp1 + Nsurp_1_LT1ST1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))

#
specname = "baseSpec2"
m1 = @time reg(surpdf2, @model(f1_f20 ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf2, @model(f1_f20 ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf2, @model(f1_f20 ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf2, @model(f1_f20 ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))

#
specname = "baseSpecDateCluster"
m1 = @time reg(surpdf, @model(retadj ~ lagMktSurp , vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf, @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3 , vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf, @model(l1_f1 ~ lagMktSurp , vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf, @model(l1_f1 ~ lagMktSurp + Nsurp_1_LT2_ST3 , vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))


specname = "baseSpecDateClusterFE"
m1 = @time reg(surpdf, @model(retadj ~ lagMktSurp, fe = DateCategorical , vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf, @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3, fe = DateCategorical , vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf, @model(l1_f1 ~ lagMktSurp, fe = DateCategorical , vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf, @model(l1_f1 ~ lagMktSurp + Nsurp_1_LT2_ST3, fe = DateCategorical , vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))


#
specname = "baseSpecNScontrol1"
# crtdf = copy(surpdf)
# crtdf[:lagNS_RES] = replace(crtdf[:lagNS_RES], missing=>0)
# crtdf[:lagNSurp] = replace(crtdf[:lagNSurp], missing=>0)
m1 = @time reg(surpdf1, @model(retadj ~ lagMktSurp1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf1, @model(retadj ~ lagMktSurp1 + Nsurp_1_LT1ST1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf1, @model(l1_f0 ~ lagMktSurp1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf1, @model(l1_f0 ~ lagMktSurp1 + Nsurp_1_LT1ST1 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT1ST1", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))

#
specname = "baseSpecNScontrol2"
# crtdf = copy(surpdf)
# crtdf[:lagNS_RES] = replace(crtdf[:lagNS_RES], missing=>0)
# crtdf[:lagNSurp] = replace(crtdf[:lagNSurp], missing=>0)
m1 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))
# Day fixed effects and contemporaneous market returns account for a similar amount of
# variation. However, the coefficient for the surprise switches sign! I suspect this is because
# an extremely low amount of variation is left to explain, so it immediately becomes significant.


#
eaddf = df[.!ismissing.(df[:EAD]),:]
lagresdf = df[.!ismissing.(df[:lagNS_RES]),:]

specname = "sample1"
# crtdf = copy(surpdf)
# crtdf[:lagNS_RES] = replace(crtdf[:lagNS_RES], missing=>0)
# crtdf[:lagNSurp] = replace(crtdf[:lagNSurp], missing=>0)
m1 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))


#
specname = "sample2"
# crtdf = copy(surpdf)
# crtdf[:lagNS_RES] = replace(crtdf[:lagNS_RES], missing=>0)
# crtdf[:lagNSurp] = replace(crtdf[:lagNSurp], missing=>0)
m1 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(surpdf2, @model(retadj ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf2, @model(l1_f0 ~ lagMktSurp2 + Nsurp_1_LT2_ST3 + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "Nsurp_1_LT1ST1"=>"\$Surprise^i_t\$"))



# Is it a contrast with your own news or sth else (biased expectations)?
nosurp1 = df[ismissing.(df[:Nsurp_1_LT1ST1]),:]
nosurp2 = df[ismissing.(df[:Nsurp_1_LT2_ST3]),:]
resdf = df[.!ismissing.(df[:NS_RES]),:]
noalldf = df[findall(ismissing.(df[:NS_ALL])),:]
df[:SurpDay1] = replace(df[:Nsurp_1_LT1ST1].*0 .+ 1, missing=>0)
df[:SurpDay2] = replace(df[:Nsurp_1_LT2_ST3].*0 .+ 1, missing=>0)
df[:RESday] = replace(df[:NS_RES].*0 .+ 1, missing=>0)
df[:ALLday] = replace(df[:NS_ALL].*0 .+ 1, missing=>0)



#
specname = "optimalSample"
m1 = @time reg(df, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(alldf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(lagresdf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m5 = @time reg(eaddf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4, m5; renderSettings = asciiOutput(), below_statistic=:tstat, statisticformat="%0.5f")
regtable(m1, m2, m3, m4, m5; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$"))


#
specname = "optimalSampleNOsurprise"
m1 = @time reg(df, @model(retadj ~ lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m2 = @time reg(alldf, @model(retadj ~ lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m3 = @time reg(lagresdf, @model(retadj ~ lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m4 = @time reg(surpdf, @model(retadj ~ lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
m5 = @time reg(eaddf, @model(retadj ~ lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4, m5; renderSettings = asciiOutput(), below_statistic=:tstat, statisticformat="%0.5f")
regtable(m1, m2, m3, m4, m5; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$"))


#
specname = "ValBase"
m1 = @time reg(valdf, @model(retadj ~ lagMktNS_RES + lagMktSurp + lagValSurp + lagGroSurp + lagValNS_RES + lagGroNS_RES, vcov = cluster(DateCategorical)))
m2 = @time reg(valdf[.!ismissing.(valdf[:NS_RES]),:], @model(retadj ~ lagMktNS_RES + lagMktSurp + lagValSurp + lagGroSurp + lagValNS_RES, vcov = cluster(DateCategorical)))
m3 = @time reg(valdf, @model(retadj ~ lagValNS_RES + lagValSurp, vcov = cluster(DateCategorical)))
m4 = @time reg(valdf[.!ismissing.(valdf[:NS_RES]),:], @model(retadj ~ lagValNS_RES + lagValSurp, vcov = cluster(DateCategorical)))
m5 = @time reg(valdf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4, m5; renderSettings = asciiOutput(), below_statistic=:tstat, statisticformat="%0.5f")
regtable(m1, m2, m3, m4, m5; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "lagMktNS_RES", "lagValSurp", "lagGroSurp", "lagValNS_RES", "lagGroNS_RES", "lagMktNS_ALL"],
                         statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "lagValSurp"=>"\$Surprise^{Value}_{t-1}\$",
                                       "lagGroSurp"=>"\$Surprise^{Growth}_{t-1}\$", "lagValNS_RES"=>"\$RES\\_NS_{t-1}^{Value}\$",
                                       "lagGroNS_RES"=>"\$RES\\_NS_{t-1}^{Growth}\$"))

specname = "GroBase"
m1 = @time reg(grodf, @model(retadj ~ lagMktNS_RES + lagMktSurp + lagValSurp + lagGroSurp + lagValNS_RES + lagGroNS_RES, vcov = cluster(DateCategorical)))
m2 = @time reg(grodf[.!ismissing.(grodf[:NS_RES]),:], @model(retadj ~ lagMktNS_RES + lagMktSurp + lagValSurp + lagGroSurp + lagGroNS_RES, vcov = cluster(DateCategorical)))
m3 = @time reg(grodf, @model(retadj ~ lagGroNS_RES + lagGroSurp, vcov = cluster(DateCategorical)))
m4 = @time reg(grodf[.!ismissing.(grodf[:NS_RES]),:], @model(retadj ~ lagGroNS_RES + lagGroSurp, vcov = cluster(DateCategorical)))
m5 = @time reg(grodf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL, vcov = cluster(DateCategorical)))
regtable(m1, m2, m3, m4, m5; renderSettings = asciiOutput(), below_statistic=:tstat, statisticformat="%0.5f")
regtable(m1, m2, m3, m4, m5; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "lagMktNS_RES", "lagValSurp", "lagGroSurp", "lagValNS_RES", "lagGroNS_RES", "lagMktNS_ALL"],
                         statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$", "lagValSurp"=>"\$Surprise^{Value}_{t-1}\$",
                                       "lagGroSurp"=>"\$Surprise^{Growth}_{t-1}\$", "lagValNS_RES"=>"\$RES\\_NS_{t-1}^{Value}\$",
                                       "lagGroNS_RES"=>"\$RES\\_NS_{t-1}^{Growth}\$"))




#
specname = "resSpec"
# crtdf = copy(surpdf)
# crtdf[:lagNS_RES] = replace(crtdf[:lagNS_RES], missing=>0)
# crtdf[:lagNSurp] = replace(crtdf[:lagNSurp], missing=>0)
m1 = @time reg(df, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL + lagMktNS_RES*lagRES_coverage, vcov = cluster(DateCategorical)))
m2 = @time reg(noresdf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL + lagMktNS_RES&lagRES_coverage, vcov = cluster(DateCategorical)))
m3 = @time reg(df, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL + lagRES_coverage, vcov = cluster(DateCategorical)))
m4 = @time reg(noresdf, @model(retadj ~ lagMktSurp + lagMktNS_RES + lagMktNS_ALL + lagRES_coverage, vcov = cluster(DateCategorical)))


regtable(m1, m2, m3, m4; renderSettings = asciiOutput(), below_statistic=:tstat)
regtable(m1, m2, m3, m4; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/$(specname).tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3", "lagMktNS_RES", "lagMktNS_ALL"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$", "lagMktNS_RES"=>"\$RES\\_NS_{t-1}^{Market}\$",
                                       "lagMktNS_ALL"=>"\$ALL\\_NS_{t-1}^{Market}\$"))


#
for i in names(df)
    print("$i\n")
end


####### Base Specification - date clustered errors #######
crtdf = df[.!ismissing.(df[surpKind]),:]
m1 = @time reg(crtdf, @model(retadj ~ lagMktSurp + lagMktNS_ALL + lagMktNS_RES, vcov = cluster(DateCategorical)))
m2 = @time reg(crtdf, @model(l1_f1 ~ lagMktSurp + lagMktNS_ALL + lagMktNS_RES, vcov = cluster(DateCategorical)))
m3 = @time reg(crtdf, @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3 + lagMktNS_ALL + lagMktNS_RES, vcov = cluster(DateCategorical)))
m4 = @time reg(crtdf, @model(l1_f1 ~ lagMktSurp + Nsurp_1_LT2_ST3 + lagMktNS_ALL + lagMktNS_RES, vcov = cluster(DateCategorical)))
m5 = @time reg(crtdf, @model(l1_f0 ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))
m6 = @time reg(crtdf, @model(l1_f0 ~ lagMktSurp + Nsurp_1_LT2_ST3 + lagMktNS_ALL + lagMktNS_RES, vcov = cluster(DateCategorical)))

regtable(m1, m2, m3, m4, m5, m6; renderSettings = asciiOutput(), below_statistic=:tstat, statisticformat="%0.4f")
regtable(m1, m3, m2, m4, m5, m6; renderSettings = latexOutput("/home/nicolas/Data/Results/Contrast effects/regression tables/baseSpec.tex"),
                         below_statistic=:tstat, below_decoration=mydec1, print_estimator_section=false,
                         regressors=["lagMktSurp", "Nsurp_1_LT2_ST3"], statisticformat="%0.3f",
                         estim_decoration = my_latex_estim_decoration,
                         labels = Dict("lagMktSurp" => "\$Surprise^{Market}_{t-1}\$", "Nsurp_1_LT2_ST3"=>"\$Surprise^i_t\$",
                                       "retadj"=>"\$Ret^i_{t-1}\$", "l1_f1"=>"\$Ret^i_{[t-1,t+1]}\$"))

mydec1(x) = "[$x]"

function my_latex_estim_decoration(s::String, pval::Float64)
  if pval<0.0
      error("p value needs to be nonnegative.")
  end
  if (pval > 0.1)
      return "$s"
  elseif (pval > 0.05)
      return "$s\\sym{*}"
  elseif (pval > 0.01)
      return "$s\\sym{**}"
  elseif (pval > 0.001)
      return "$s\\sym{***}"
  else
      return "$s\\sym{***}"
  end
end









# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagMktSurp, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagBigMktSurp, vcov = robust))

# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(retadj ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = robust))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = robust))

# If I use firm fixed effects I remove ALL between differences across the average differences of firms.
# Hence, I couldn't look at further effects that are stock-specific.
# If I use cluster for the errors on firms, then I just account for "nuisance" in the time-series dependence of firm residuals.

regtable(all_retadj_ALL_StockS_MktS, all_retadj_ALL_StockS_BigMktS,
         all_l1_f0_ALL_StockS_MktS, all_l1_f0_ALL_StockS_BigMktS,
         all_retadj_ALL_StockS_MktS_firmS, all_retadj_ALL_StockS_BigMktS_firmS,
         all_l1_f0_ALL_StockS_MktS_firmS, all_l1_f0_ALL_StockS_BigMktS_firmS;
         renderSettings = asciiOutput(), below_statistic=:tstat)






# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(retadj ~ lagMktSurp, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(retadj ~ lagBigMktSurp, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(l1_f0 ~ lagMktSurp, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(l1_f0 ~ lagBigMktSurp, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(retadj ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(l1_f0 ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[:EAD]),:], @model(l1_f0 ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))

# If I use firm fixed effects I remove ALL between differences across the average differences of firms.
# Hence, I couldn't look at further effects that are stock-specific.
# If I use cluster for the eprint("\n")rrors on firms, then I just account for "nuisance" in the time-series dependence of firm residuals.

regtable(all_retadj_ALL_StockS_MktS, all_retadj_ALL_StockS_BigMktS,
         all_l1_f0_ALL_StockS_MktS, all_l1_f0_ALL_StockS_BigMktS,
         all_retadj_ALL_StockS_MktS_firmS, all_retadj_ALL_StockS_BigMktS_firmS,
         all_l1_f0_ALL_StockS_MktS_firmS, all_l1_f0_ALL_StockS_BigMktS_firmS;
         renderSettings = asciiOutput(), below_statistic=:tstat)









#
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS = @time reg(df, @model(retadj ~ lagMktSurp, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS = @time reg(df, @model(retadj ~ lagBigMktSurp, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS = @time reg(df, @model(l1_f0 ~ lagMktSurp, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS = @time reg(df, @model(l1_f0 ~ lagBigMktSurp, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS_firmS = @time reg(df, @model(retadj ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS_firmS = @time reg(df, @model(retadj ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS_firmS = @time reg(df, @model(l1_f0 ~ lagMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS_firmS = @time reg(df, @model(l1_f0 ~ lagBigMktSurp + Nsurp_1_LT2_ST3, vcov = cluster(DateCategorical)))

# If I use firm fixed effects I remove ALL between differences across the average differences of firms.
# Hence, I couldn't look at further effects that are stock-specific.
# If I use cluster for the errors on firms, then I just account for "nuisance" in the time-series dependence of firm residuals.

regtable(all_retadj_ALL_StockS_MktS, all_retadj_ALL_StockS_BigMktS,
         all_l1_f0_ALL_StockS_MktS, all_l1_f0_ALL_StockS_BigMktS,
         all_retadj_ALL_StockS_MktS_firmS, all_retadj_ALL_StockS_BigMktS_firmS,
         all_l1_f0_ALL_StockS_MktS_firmS, all_l1_f0_ALL_StockS_BigMktS_firmS;
         renderSettings = asciiOutput(), below_statistic=:tstat)




#
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l0_f5 ~ lagMktSurp + NS_ST + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l0_f5 ~ lagBigMktSurp + NS_ST + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagMktSurp + NS_ST + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagBigMktSurp + NS_ST + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))

# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the market?
all_retadj_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l0_f5 ~ lagMktSurp + NS_ST + Nsurp_1_LT2_ST3 + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_retadj_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l0_f5 ~ lagBigMktSurp + NS_ST + Nsurp_1_LT2_ST3 + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))

# All other things equal, is a stock's news surprise impact negatively influenced by the surprise of the market?
all_l1_f0_ALL_StockS_MktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagMktSurp + NS_ST + Nsurp_1_LT2_ST3 + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))
# All other things equal, is a stock's surprise impact negatively influenced by the surprise of the BIG components of the market?
all_l1_f0_ALL_StockS_BigMktS_firmS = @time reg(df[.!ismissing.(df[surpKind]),:], @model(l1_f0 ~ lagBigMktSurp + NS_ST + Nsurp_1_LT2_ST3 + lagValSurp*rankbm + lagGroSurp*rankbm, vcov = robust))

# If I use firm fixed effects I remove ALL between differences across the average differences of firms.
# Hence, I couldn't look at further effects that are stock-specific.
# If I use cluster for the errors on firms, then I just account for "nuisance" in the time-series dependence of firm residuals.

regtable(all_retadj_ALL_StockS_MktS, all_retadj_ALL_StockS_BigMktS,
         all_l1_f0_ALL_StockS_MktS, all_l1_f0_ALL_StockS_BigMktS,
         all_retadj_ALL_StockS_MktS_firmS, all_retadj_ALL_StockS_BigMktS_firmS,
         all_l1_f0_ALL_StockS_MktS_firmS, all_l1_f0_ALL_StockS_BigMktS_firmS;
         renderSettings = asciiOutput(), below_statistic=:tstat)


function windowRet(X, win; removeMissing=true, missShortWindows=true)
    X = replace(X,NaN=>missing)
    l = win[1]
    f = win[2]
    res = Union{Missing,Float64}[]
    for i in 1:length(X)
        if i+l<=0 #if the lag puts me too far back
            if missShortWindows
                push!(res,missing)
            elseif i+f<=length(X)
                push!(res,cumret(X[1:i+f]))
            else
                push!(res,missing)
            end
        elseif i+f>length(X) #forward goes outside range
            if missShortWindows
                push!(res,missing)
            elseif i+l>=0
                if i+l<length(X)
                    push!(res,cumret(X[i+l:end]))
                else
                    push!(res,missing)
                end
            end
        else
            push!(res,cumret(X[i+l:i+f]))
        end
    end
    return replace(res, NaN=>missing)
end
