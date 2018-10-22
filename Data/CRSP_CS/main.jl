##################################################################################################
#%% Load modules and Path
##################################################################################################
using ShiftedArrays, DataFrames, Dates, DataFramesMeta, CSV, StatsBase,
      Statistics, RollingFunctions, JLD2

include("Data/CRSP_CS/customfcts.jl")
include("Data/CRSP_CS/breakpoints.jl")
include("Data/CRSP_CS/WRDStables.jl")
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


CSdf = CSraw(CSdaterange, yearly_CSvariables, yearly_CSdatatable)

print("Download the CRSP data and get the info plus propoerly computed drifting weights")
print("Compute a dataframe with decemeber and june me only (for classification)")
CRSPdf, CRSPdf_jun_me = CRSPdl(CRSPdaterange, monthly_CRSPvariables, monthly_CRSPdatatable)

CS_ccm = CSccmMerge(CSdf)

# merge june CRSP with Compustat. This is to compute the breakpoints.
june_merge = join(CRSPdf_jun_me, CS_ccm, kind=:inner, on=[:permno, :jdate]);

bmranks = bmSizeRanks(june_merge)

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

@time merged_CRSP_CS = @byrow! merged_CRSP_CS begin
    @newcol yearmonth::Array{Int}
    :yearmonth = :year*100+:month
end;
merged_CRSP_CS[:date] = DateTime.(merged_CRSP_CS[:date]);


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
dailyDF = @time join(CRSPdf, merged_CRSP_CS, kind=:left, on=[:yearmonth, :permno])

JLD2.@load "/home/nicolas/Data/Inputs/dates.jld2"
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


using PyCall
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:Denada]
collection = db[:daily_CRSP_CS_TRNA]
p=[0, 0]
@time for row in eachrow(dailyDF)
    p[1] += 1
    if p[1] in [1,5000,1000000,5000000,10000000,15000000]
        print(row)
        print(p[2])
    end
    ismissing(row[:dailywt]) ? dwt = nothing : dwt = row[:dailywt]
    ismissing(row[:wt]) ? mwt = nothing : mwt = row[:wt]
    ismissing(row[:ptf_2by3_size_value]) ? p2x3 = nothing : p2x3 = row[:ptf_2by3_size_value]
    ismissing(row[:ranksize]) ? rs = nothing : rs = row[:ranksize]
    ismissing(row[:rankbm]) ? rb = nothing : rb = row[:rankbm]
    collection[:update_one](
            Dict("\$and"=> [
                            Dict("permno"=>row[:permno]),
                            Dict("td"=> row[:td])
                            ]),
            Dict("\$set"=>Dict("dailywt"=>dwt, "wt" => mwt, "ptf_2by3_size_value" => p2x3,
                               "rankbm" => rb, "ranksize" => rs)))
end;
