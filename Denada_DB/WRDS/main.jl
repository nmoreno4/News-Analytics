##################################################################################################
#%% Load modules and Path
##################################################################################################
using ShiftedArrays, DataFrames, Dates, DataFramesMeta, CSV, StatsBase, Statistics, RollingFunctions, JLD2

include("Denada_DB/WRDS/customfcts.jl")
include("Denada_DB/WRDS/breakpoints.jl")
include("Denada_DB/WRDS/WRDStables.jl")
# ##################################################################################################
# #%% Global variables
# ##################################################################################################
begin
    collection = "Denada"
    #Span of working period
    CSdaterange = ["01/01/1999", "12/31/2017"]
    CRSPdaterange = ["01/01/2000", "6/30/2018"]
    truestart = Dates.Date(2003,1,1)
    # Start with yearly freq of accounting data
    yearly_CSvariables = "gvkey, datadate, cusip, at, ceq, lt, seq, txditc, pstkrv,
                   pstkl, pstk, tic, conm, cik, naicsh" #, addzip, city, conml, naicsh, state
    yearly_CSdatatable = "comp.funda"
    # Start with monthly freq of CRSP data
    monthly_CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                     a.retx, a.shrout, a.prc, a.vol, a.spread"
    monthly_CRSPdatatable = ["crsp.msf", "crsp.msenames"]
end

##################################################################################################
#%% CS treatment
##################################################################################################
#%% Download CS data
@time CSdf = dl_CS(CSdaterange, yearly_CSvariables, yearly_CSdatatable)

@time CSdf = CS_age!(CSdf)
#Keep only stocks having at least two years of history in compustat database
# CSdf = CSdf[(CSdf[:count].>1),:]
# CSdf = CSdf[(CSdf[:year].>=2003),:]
@time CSdf = compute_be!(CSdf)

##################################################################################################
#%% CRSP treatment
##################################################################################################
@time CRSPdf = CRSPdownload(CRSPdaterange, monthly_CRSPvariables, monthly_CRSPdatatable)

# change variable format to int
CRSPdf = changeColumnType!(CRSPdf, [:permco, :permno, :shrcd, :exchcd], Int)

# Add lined up date to be end of month.
# It's called jdate because at the end I will only keep those from the month of june.
CRSPdf = lineupDate!(CRSPdf, Dates.Month, :jdate, :date)

# Adjust for deli return
@time CRSPdf = delistAdjust!(CRSPdf)

# calculate market equity, sort and remove useless columns
CRSPdf[:me]=abs.(CRSPdf[:prc]).*CRSPdf[:shrout]
delete!(CRSPdf, [:dlret,:dlstdt,:prc,:shrout])
sort!(CRSPdf, [:permco,:jdate,:me])


# Merge permno permco market equities
if CRSPdaterange!=["01/01/2000", "6/30/2018"]
    error("The dataframe split has been set for [\"01/01/2000\", \"6/30/2018\"] dates explicitly")
end
a1 = CRSPdf[1:999921,:]
a2 = CRSPdf[999922:end,:]
@time CRSPdf = mergepermnopermco!(a1)
@time CRSPdfa = mergepermnopermco!(a2)
append!(CRSPdf, CRSPdfa)
sort!(CRSPdf, [:permno,:jdate])

# keep only December market cap (+permno and date)
decme = decME(CRSPdf)
# add variables for what year (ffyear) and month (ffmonth) we were 6 months prior to the observation
CRSPdf = julyJuneDates!(CRSPdf)

#Compute drifting weights going on from date of rebalancement (starting each new ffyear)
sort!(CRSPdf, [:permno, :date]);
CRSPdf = driftweights!(CRSPdf, [:permno, :date])

# Join December and June info
CRSPdf_jun_me = juneDecMerge(CRSPdf, decme)
CRSPdf_jun_me = CRSPdf_jun_me[[:permno, :date, :jdate, :shrcd, :exchcd, :retadj, :me,
                        :wt, :cumretx, :mebase, :lagme_1, :dec_me]];
sort!(CRSPdf_jun_me, [:permno, :jdate]);


##################################################################################################
#%% Merge CRSP and CS using CCM
##################################################################################################
@time ccm = ccmDownload()

# Link Compustat to CCM
CS_ccm=join(CSdf,ccm,kind=:left,on=:gvkey);

CS_ccm[:yearend] = map(x->ceil(x, Dates.Year)-Dates.Day(1), CS_ccm[:datadate]);
CS_ccm[:jdate] = CS_ccm[:yearend].+Dates.Month(6);

# set link date bounds. This removes all duplicates
linkinbounds = (CS_ccm[:jdate].<=CS_ccm[:linkenddt]) .& (CS_ccm[:jdate].>=CS_ccm[:linkdt]);
linkinbounds = Array{Bool}(replace(linkinbounds, missing=>false));
CS_ccm = CS_ccm[linkinbounds, :]

# match gvkey with permID
CS_ccm = gvkeyMatchPermID!(CS_ccm,)

# merge june CRSP with Compustat. This is to compute the breakpoints.
june_merge = join(CRSPdf_jun_me, CS_ccm, kind=:inner, on=[:permno, :jdate]);

#######################################################################################
#%% Breakpoints computation
#######################################################################################
print("Breakpoint computation")
june_merge = julyJuneDates!(june_merge);
dupind = nonunique(june_merge[[:permno, :ffyear]]);
popfirst!(dupind);
push!(dupind, false);
dupind = map(x->invertbool(x), dupind);
june_merge = june_merge[dupind,:];
bmranks = bmClassficiation(june_merge);
bmranks = bmranks[[:permno, :ffyear, :ptf_2by3_size_value, :ranksize, :rankbm]];
# june_merge[:percentiles_me] = bmranks[:percentiles_me]
# june_merge[:percentiles_bm] = bmranks[:percentiles_bm]

#Since CRSPdf is monthly I get monthly momentum classification
CRSPdf = CRSPdf[(CRSPdf[:year].>=2001),:]
CRSPdf[:momrank] = momentumClassification(CRSPdf, 12, 10)[:momrank];
CRSPdf = CRSPdf[(CRSPdf[:year].>=2003),:]


CS_ccm = julyJuneDates!(CS_ccm)
merged_CRSP_CS = join(CRSPdf, CS_ccm, kind=:left, on=[:permno, :ffyear])
dupind = nonunique(merged_CRSP_CS[[:permno, :ffyear, :date]])
popfirst!(dupind)
push!(dupind, false)
dupind = map(x->invertbool(x), dupind)
merged_CRSP_CS = merged_CRSP_CS[dupind,:]
merged_CRSP_CS = join(merged_CRSP_CS, bmranks, kind=:left, on=[:permno, :ffyear])
merged_CRSP_CS = unique(merged_CRSP_CS)
merged_CRSP_CS[[:permno, :gvkey, :date, :momrank, :rankbm]]



################################
# Earnings Announcemnt Dates   #
################################
print("Compute EAD")
CSvariables = "gvkey, datadate, rdq" #addzip, city, conml, naicsh, state
CSdatatable = "comp.fundq"
EAdfq = CSdownload(CSdaterange, CSvariables, CSdatatable)
EAdfq[:EAD] = 1
EAdfq = EAdfq[[:gvkey, :rdq, :EAD]]
deletemissingrows!(EAdfq, :rdq)
rename!(EAdfq, :rdq => :dailydate)
EAdfq[:gvkey] = map(x->parse(Int,x), EAdfq[:gvkey])
EAdfq[:td]=missing
EAdfq = EAdfq[(EAdfq[:dailydate].>=Dates.Date(2003,1,1)),:]
EAdfq = EAdfq[(EAdfq[:dailydate].<=Dates.Date(2017,12,31)),:]
EAdfq[:td] = map(x->trading_day(dates, x), EAdfq[:dailydate])

merged_CRSP_CS = merged_CRSP_CS[(merged_CRSP_CS[:date].>=Dates.Date(2003,1,1)),:]
merged_CRSP_CS = merged_CRSP_CS[(merged_CRSP_CS[:date].<=Dates.Date(2017,12,31)),:]
merged_CRSP_CS[:td] = map(x->trading_day(dates, x), merged_CRSP_CS[:date])

EAdfqfinal = join(EAdfq, merged_CRSP_CS[[:permno, :gvkey, :td]], kind=:inner, on=[:gvkey])
delete!(EAdfqfinal, :td_1)
EAdfqfinal = unique(EAdfqfinal)

dbname = :Denada
collname = :daily_CRSP_CS_TRNA
@pyimport pymongo
client = pymongo.MongoClient()
db = client[dbname]
mongo_collection = db[collname]

for row in eachrow(EAdfqfinal)
    mongo_collection[:update_one](
    Dict("\$and"=> [
                    Dict("permno"=>row[:permno]),
                    Dict("td"=> row[:td])
                    ]),
    Dict("\$set"=>Dict("EAD"=>row[:EAD])))
end


annualratios = lineupDate!(annualratios, Dates.Month, :jdate, :datadate)
annualratios = julyJuneDates!(annualratios);
annualratios[:gvkey] = parse.(Int, annualratios[:gvkey]);
dupind = nonunique(annualratios[[:gvkey, :ffyear]])
popfirst!(dupind)
push!(dupind, false)
dupind = map(x->invertbool(x), dupind)
annualratios = annualratios[dupind,:]
monthly_merge = join(merged_CRSP_CS, annualratios, kind=:left, on=[:gvkey, :ffyear])


for col in names(monthly_merge)
    print("$col \n")
end

@time monthly_merge = @byrow! monthly_merge begin
    @newcol yearmonth::Array{Int}
    :yearmonth = :year*100+:month
end;
variablestokeep = [:permno, :date, :vol, :spread, :retadj, :me, :yearmonth, :wt, :momrank,
                    :at, :lt, :seq, :tic, :conm, :cik, :naicsh, :curcd, :costat, :ggroup,
                    :gind, :gsector, :gsubind, :be, :permid, :ptf_2by3_size_value, :ranksize,
                    :rankbm, :epsfi, :oprepsx, :ajex, :ebit, :sale, :dvc, :ib, :oiadp, :gp,
                    :revt, :cogs, :pi, :ibc, :dpc, :ni, :ibcom, :icapt, :mib, :ebitda, :xsga,
                    :dltt, :dlc, :che, :txt, :xrd, :xad, :capx, :bm, :ocf, :capei, :evm, :pe_op_basic,
                    :pe_inc, :ps_1, :pcf, :dpr, :npm, :opmbd, :opmad, :gpm, :ptpm, :cfm, :roa,
                    :roe, :roce, :leverage, :tobinQ, :altmanZ];
monthly_merge = monthly_merge[variablestokeep];
monthly_merge[:date] = DateTime.(monthly_merge[:date]);


# Load S&P500 return
SP500m = CSV.read("/run/media/nicolas/Data/Inputs/monthlySP500.csv");
SP500m[:caldt] = Dates.Date.(map(x->replace(x, "/"=>"-"), SP500m[:caldt]));
SP500d = CSV.read("/run/media/nicolas/Data/Inputs/dailySP500.csv");
SP500d[:caldt] = Dates.Date.(map(x->replace(x, "/"=>"-"), SP500d[:caldt]));
@time SP500m = @byrow! SP500m begin
    @newcol yearmonth::Array{Int}
    :yearmonth = year(:caldt)*100+month(:caldt)
end;
delete!(SP500m, :caldt)
monthly_merge = join(monthly_merge, SP500m, kind=:left, on=[:yearmonth])
monthly_merge[:exret] = monthly_merge[:retadj].-monthly_merge[:vwretd]
𝛷 = 2^(-1/3)
decayw = [𝛷^t for t in 0:11]
@time prov = by(monthly_merge, [:permno]) do df
    if length(df[:exret])>=12
        rollsum = (1-𝛷)/(1-𝛷^12).*rolling(sum, df[:exret], 12, decayw)[1:end-1] # remove last obs for lag
        DataFrame(exretavg = [Array{Union{Missing, Float64}}(missing, 12); rollsum])
    else
        DataFrame(exretavg = Array{Union{Missing, Float64}}(missing, length(df[:exret])))
    end
end
monthly_merge[:exretavg] = prov[:exretavg]


# using PyCall
# @pyimport pymongo
# @pyimport datetime
# client = pymongo.MongoClient()
# db = client[:Denada]
# collection = db[:monthly_CRSP_CS]
# p=[0]
# @time for row in eachrow(monthly_merge)
#     insertDic = Dict{String,Any}()
#     for var in variablestokeep
#         if !ismissing(row[var])
#             insertDic[String(var)] = row[var]
#         else
#             insertDic[String(var)] = nothing
#         end
#     end
#     collection[:insert_one](insertDic)
# end;
# insertDic = Dict{String,Any}()
# insertDic["a"] = PyObject(NaN)


#######################
#      Daily data     #
#######################
print("Downloading daily data!...")
CRSPvariables = "a.permno, a.date, a.ret, a.vol, a.prc, a.numtrd, a.retx"
CRSPdatatable = ["crsp.dsf", "crsp.dsenames"] #the "d"sf stands for daily
CRSPdf = @time CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable);
CRSPdf = CRSPdf[(CRSPdf[:date].>=Dates.Date(2003,1,1)),:]
CRSPdf = CRSPdf[(CRSPdf[:date].<=Dates.Date(2017,12,31)),:]
print("Data downloaded!")
delistdf = delistdownload("d")
names!(delistdf, [:permno, :dlret, :date])
CRSPdf = @time join(CRSPdf, delistdf, on = [:date, :permno], kind = :left)
CRSPdf[ismissing.(CRSPdf[:dlret]), :dlret] = 0
# Set missing returns to 0 (only <0.001% in monthly)
CRSPdf[ismissing.(CRSPdf[:ret]), :ret] = 0
# Compute adjusted return including delisting
CRSPdf[:retadj]=(CRSPdf[:ret].+1).*(CRSPdf[:dlret].+1).-1
CRSPdf[:year] = Dates.year.(CRSPdf[:date])
CRSPdf[:month] = Dates.month.(CRSPdf[:date])
@time CRSPdf = @byrow! CRSPdf begin
    @newcol yearmonth::Array{Int}
    :yearmonth = :year*100+:month
end;
CRSPdf = CRSPdf[[:yearmonth, :permno, :retadj, :date, :vol, :numtrd, :prc, :retx]]
names!(CRSPdf, [:yearmonth, :permno, :dailyretadj, :dailydate, :dailyvol, :dailynumtrades, :dailyprice, :dailyretx])
dailyDF = @time join(CRSPdf, monthly_merge, kind=:left, on=[:yearmonth, :permno])


JLD2.@load "/run/media/nicolas/Data/Inputs/dates.jld2"
@time dailyDF = @byrow! dailyDF begin
    @newcol td::Array{Int}
    :td = trading_day(dates, :dailydate)
end;

dupind = @time nonunique(dailyDF[[:permno, :td]])
popfirst!(dupind)
push!(dupind, false)
dupind = map(x->invertbool(x), dupind)
@time dailyDF = dailyDF[dupind,:]

dailyDF[:dailydate] = DateTime.(dailyDF[:dailydate]);

using PyCall
@pyimport pymongo
@pyimport datetime
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[:daily_CRSP_CS_TRNA]
p=[0]
@time for row in eachrow(dailyDF)
    insertDic = Dict{String,Any}()
    for var in names(dailyDF)
        if !ismissing(row[var])
            insertDic[String(var)] = row[var]
        else
            insertDic[String(var)] = nothing
        end
    end
    collection[:insert_one](insertDic)
end;




################################
# Earnings Announcemnt Dates   #
################################
print("Compute EAD")
CSvariables = "gvkey, datadate, rdq" #addzip, city, conml, naicsh, state
CSdatatable = "comp.fundq"
EAdfq = CSdownload(CSdaterange, CSvariables, CSdatatable)
EAdfq[:EAD] = 1
EAdfq = EAdfq[[:gvkey, :rdq, :EAD]]
deletemissingrows!(EAdfq, :rdq)
rename!(EAdfq, :rdq => :dailydate)
EAdfq[:gvkey] = map(x->parse(Int,x), EAdfq[:gvkey])
EAdfq[:td]=missing
EAdfq = EAdfq[(EAdfq[:dailydate].>=Dates.Date(2003,1,1)),:]
EAdfq = EAdfq[(EAdfq[:dailydate].<=Dates.Date(2017,12,31)),:]
EAdfq[:td] = map(x->trading_day(dates, x), EAdfq[:dailydate])

EAdfq = join(EAdfq, matched, kind=:left, on=[:gvkey])




#######
# New #
#######

cumprodplus1(x) = cumprod(x.+1)
lagvec(x) = [missing; x[1:end-1]]


# dailyCRSP[ismissing.(dailyCRSP[:retx]), :retx] = 0
# dailyCRSP[:year] = Dates.year.(dailyCRSP[:date])
# dailyCRSP[:month] = Dates.month.(dailyCRSP[:date])
# @time dailyCRSP = @byrow! dailyCRSP begin
#     @newcol yearmonth::Array{Int}
#     :yearmonth = :year*100+:month
# end;
# names!(dailyCRSP, [:permno, :dailydate, :dailyretx, :year, :month, :yearmonth, :td])
# dailyDF = @time join(dailyCRSP, monthly_merge, kind=:left, on=[:yearmonth, :permno])
# @time dailyDF = @byrow! dailyDF begin
#     @newcol td::Array{Int}
#     :td = trading_day(dates, :dailydate)
# end;
# dupind = @time nonunique(dailyDF[[:permno, :td]])
# popfirst!(dupind)
# push!(dupind, false)
# dupind = map(x->invertbool(x), dupind)
# @time dailyDF = dailyDF[dupind,:];

sort!(dailyDF, [:permno, :dailydate])
dailyDF = groupcumret!(dailyDF, [:permno, :ffmonth, :ffyear], :dailyretx, [:permno, :dailydate])
dailyDF = grouplag!(dailyDF, [:permno, :ffmonth, :ffyear], :cumdailyretx, 1, [:permno, :dailydate])
dailyDF[ismissing.(dailyDF[:lagcumdailyretx_1]), :lagcumdailyretx_1] = 1
dailyDF = dailyDF[nonmissing.(dailyDF[:wt]),:]

ids = Any[0]
newwt = Bool[]
for i in 1:length(dailyDF[:wt])
    if dailyDF[:wt][i]!=ids[1] #Different as previous
        push!(newwt, true)
        ids[1] = dailyDF[:wt][i]
    else
        push!(newwt, false)
    end
end
dailyDF[:newwt] = newwt
# dailyDF = grouplag!(dailyDF, :permno, :wt, 1)
# dailyDF = setfirstlme!(dailyDF, :permno, :lagwt_1)
@time dailyDF = @byrow! dailyDF begin
    @newcol dailywt::Array{Union{Float64,Missing}}
    if :newwt
        :dailywt = :wt
    else
        :dailywt = :wt*:lagcumdailyretx_1
    end
end;

dailyDF = dailyDF[[:td, :permno, :wtdaily]]

using PyCall
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[:daily_CRSP_CS_TRNA]
p=[0, 0]
@time for row in eachrow(dailyDF)
    p[1] += 1
    if p[1] in [1,5000,1000000,10000000]
        print(row)
        print(p[2])
    end
    if !ismissing(row[:dailywt]) && !ismissing(row[:wt]) && !ismissing(row[:ptf_2by3_size_value]) && !ismissing(row[:ranksize]) && !ismissing(row[:rankbm])
        collection[:update_one](
                Dict("\$and"=> [
                                Dict("permno"=>row[:permno]),
                                Dict("td"=> row[:td])
                                ]),
                Dict("\$set"=>Dict("dailywt"=>row[:dailywt], "wt" => row[:wt], "ptf_2by3_size_value" => row[:ptf_2by3_size_value],
                                   "rankbm" => row[:rankbm], "ranksize" => row[:ranksize])))
    else
        p[2]+=1
        collection[:update_one](
                Dict("\$and"=> [
                                Dict("permno"=>row[:permno]),
                                Dict("td"=> row[:td])
                                ]),
                Dict("\$set"=>Dict("dailywt"=>nothing, "wt" => nothing, "ptf_2by3_size_value" => nothing,
                                   "rankbm" =>nothing, "ranksize" => nothing)))
    end
end;
