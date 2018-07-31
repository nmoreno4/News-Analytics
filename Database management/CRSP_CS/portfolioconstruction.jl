push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using CSV, Missings, DataFrames, JLD2, Suppressor, RCall, Query, StatsBase
@rlibrary stlplus
@rlibrary RPostgres
using usefulNestedDF, otherCleaning, customWRDSvariables, Portfolio_Sorting, WRDSdownload
# import WRDSdownload: FF_factors_download
import DFmanipulation: deletemissingrows!
# include("Database management/WRDSmodules/WRDSdownload.jl")

collection = "flatstockdate"
#Span of working period
CSdaterange = ["01/01/1999", "12/31/2017"]
CRSPdaterange = ["01/01/1999", "6/30/2018"]
truestart = Dates.Date(2003,1,1)
# Frequency of fundamental's data either annual or quarterly
fundfq = "a"
# Frequency of exchange data either monthly or daily
exchfq = "m"

if fundfq == "q"
    CSvariables = "gvkey, datadate, cusip, rdq, tic, conm, cik, atq, ceqq, ibq,
                   ltq, revtq, saleq, seqq, txditcq, xintq, pstkq" #addzip, city, conml, naicsh, state
    CSdatatable = "comp.fundq"
elseif fundfq=="a"
    CSvariables = "gvkey, datadate, cusip, at, ceq, lt, seq, txditc, pstkrv,
                   pstkl, pstk, tic, conm, cik, naicsh" #, addzip, city, conml, naicsh, state
    CSdatatable = "comp.funda"
end
if exchfq ==  "m"
    #Spread is only available at monthly frequency.
    CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                     a.retx, a.shrout, a.prc, a.vol, a.spread"
    CRSPdatatable = ["crsp.msf", "crsp.msenames"]
elseif exchfq=="d"
    CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                     a.retx, a.shrout, a.prc, a.vol"
    CRSPdatatable = ["crsp.dsf", "crsp.dsenames"]
end

# CSdf, CRSPdf, delistdf, CCMdf = gatherWRDSdata()


##############################
# Compustat treatment Block  #
##############################
print("Treat CS")
# Download Compustat data from server
CSdf = WRDSdownload.CSdownload(CSdaterange, CSvariables, CSdatatable)
# Add a column with the year of the observation
CSdf[:year] = Dates.year(CSdf[:datadate])

# number of years in Compustat
# Only works with annual data!!
sort!(CSdf, [:gvkey,:datadate])
CSdf[:count]=1
CSdf[:count]=by(CSdf, [:gvkey], CSdf -> DataFrame(count = cumsum(CSdf[:count])))[:count]
CSdf[:count]-=1
#Keep only stocks having at least two years of history in compustat database
CSdf = CSdf[CSdf[:count] .> 1, :]
# CSdf[[:count, :gvkey, :datadate]] #for visual check

# create preferrerd stock and balance sheet deferred taxes and investment tax credit (txditc)
if fundfq == "q"
    CSdf[Symbol("ps")] = Missings.coalesce.(CSdf[Symbol("pstkq")],0)
    CSdf[Symbol("txditcq")] = Missings.coalesce.(CSdf[Symbol("txditcq")],0)
elseif fundfq == "a"
    CSdf[Symbol("ps")] = Missings.coalesce.(CSdf[Symbol("pstkrv")],CSdf[Symbol("pstkl")],CSdf[Symbol("pstk")],0)
    CSdf[Symbol("txditc")] = Missings.coalesce.(CSdf[Symbol("txditc")],0)
end

# create book equity
if fundfq == "q"
    CSdf[Symbol("be")]=CSdf[Symbol("seqq")]+CSdf[Symbol("txditcq")]-CSdf[Symbol("ps")]
elseif fundfq == "a"
    CSdf[Symbol("be")]=CSdf[Symbol("seq")]+CSdf[Symbol("txditc")]-CSdf[Symbol("ps")]
end

#Replace missing be by 0
CSdf[ismissing.(CSdf[Symbol("be")]), Symbol("be")] = 0
#Remove those missing and negative be
CSdf = CSdf[CSdf[Symbol("be")] .> 0, :]


#########################
# CRSP treatment Block  #
#########################
print("Treat CRSP")
CRSPdf = CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable)
# Line up date to be end of month. It's called jdate because at the end I will only keep those from the month of june.
CRSPdf[:jdate] = Date(0,1,1)
for row in eachrow(CRSPdf)
    row[:jdate] = ceil(row[:date], Dates.Month)-Dates.Day(1)
end
# Download delisting return table
delistdf = delistdownload(exchfq)
# match delist return date with return date
if exchfq=="m"
    delistdf[:jdate] = Date(0,1,1)
    for row in eachrow(delistdf)
        row[:jdate] = ceil(row[:dlstdt], Dates.Month)-Dates.Day(1)
    end
    CRSPdf = join(CRSPdf, delistdf, on = [:jdate, :permno], kind = :left)
elseif exchfq=="d"
    names!(delistdf, [:permno, :dlret, :date])
    CRSPdf = join(CRSPdf, delistdf, on = [:date, :permno], kind = :left)
end

CRSPdf[ismissing.(CRSPdf[:dlret]), :dlret] = 0
# Set missing returns to 0 (only <0.001% in monthly)
CRSPdf[ismissing.(CRSPdf[:ret]), :ret] = 0
# Compute adjusted return including delisting
CRSPdf[:retadj]=(1+CRSPdf[:ret]).*(1+CRSPdf[:dlret])-1
# Keep only rows where I have a price (only ~0.00016% in monthly)
CRSPdf[ismissing.(CRSPdf[:prc]), :prc] = 9999999999
CRSPdf = CRSPdf[CRSPdf[:prc] .< 9999999998, :]
# calculate market equity
CRSPdf[:me]=abs(Array{Float64}(CRSPdf[:prc])).*CRSPdf[:shrout]
delete!(CRSPdf, [:dlret, :shrout])
@time sort!(CRSPdf, [:date, :permco, :me])


### Aggregate Market Cap permno-permco ###
crsp_summe = @time by(CRSPdf, [:date, :permco], CRSPdf -> DataFrame(me = mean(CRSPdf[:me])))
crsp_maxme = @time by(CRSPdf, [:date, :permco], CRSPdf -> DataFrame(me = maximum(CRSPdf[:me])))
CRSPdf = join(CRSPdf, crsp_maxme, on = [:date, :permco, :me], kind = :inner)
delete!(CRSPdf, [:me])
CRSPdf = @time join(CRSPdf, crsp_summe, on = [:date, :permco], kind = :inner)
#Drop duplicates
deleterows!(CRSPdf, find(nonunique(CRSPdf)))

### keep December market cap ###
CRSPdf[:year] = Dates.year(CRSPdf[:jdate])
CRSPdf[:month] = Dates.month(CRSPdf[:jdate])
decme = CRSPdf[CRSPdf[:month] .== 12, :]
decme = decme[:, filter(x -> x in [:me, :permno, :date, :jdate, :year], names(decme))]
names!(decme, [:permno, :date, :jdate, :dec_me, :year])

### July to June dates ###
CRSPdf[:ffdate] = CRSPdf[:jdate]-Dates.Month(6)
CRSPdf[:ffyear] = Dates.year(CRSPdf[:ffdate])
CRSPdf[:ffmonth] = Dates.month(CRSPdf[:ffdate])

CRSPdf[:retxplus1] = 1+CRSPdf[:retx]
@time sort!(CRSPdf, [:permno, :date])

CRSPdf[:cumretx] = by(CRSPdf, [:permno, :ffyear], CRSPdf -> DataFrame(cumretx = cumprod(CRSPdf[:retxplus1])))[:cumretx]

# lag cumret
CRSPdf[:lcumretx] = by(CRSPdf, [:permno], CRSPdf -> DataFrame(lcumretx = unshift!(Array{Union{Float64, Missing}}(CRSPdf[:cumretx][1:end-1]), missing)))[:lcumretx]

# lag market cap
CRSPdf[:lme] = by(CRSPdf, [:permno], CRSPdf -> DataFrame(lme = unshift!(Array{Union{Float64, Missing}}(CRSPdf[:me][1:end-1]), missing)))[:lme]

# if first permno then use me/(1+retx) to replace the missing value
# Get the number of the observation for each stock
CRSPdf[:count] = by(CRSPdf, [:permno], CRSPdf -> DataFrame(count = cumsum(1+CRSPdf[:me]*0)-1))[:count]
for row in eachrow(CRSPdf)
    if row[:count]==0
        row[:lme]=row[:me]/row[:retxplus1]
    end
end

# baseline me from which I will compute the drift in weight_port.
# Since I rebalance at the end of june I start the drift of a new year in july
mebase = CRSPdf[CRSPdf[:ffmonth] .== 1, :]
mebase = mebase[:, filter(x -> x in [:permno, :ffyear, :lme], names(mebase))]
names!(mebase, [:permno, :ffyear, :mebase])

# merge result back together
CRSPdf = join(CRSPdf, mebase, on = [:permno, :ffyear], kind = :left)
CRSPdf[:wt] = missing
CRSPdf[:wt] = Array{Union{Float64, Missing}}(CRSPdf[:wt] )
for row in eachrow(CRSPdf)
    if row[:ffmonth]==1
        row[:wt]=row[:lme]
    else
        row[:wt]=row[:mebase]*row[:lcumretx]
    end
end
CRSPdf[[:date, :wt, :lme]]

decme[:year]=decme[:year]+1
decme=decme[[:permno,:year,:dec_me]]

crsp_jun = CRSPdf[CRSPdf[:month].==6,:]
crsp_jun = join(crsp_jun, decme, on=[:permno, :year], kind=:inner)


#######################
# CCM Block           #
#######################
print("Link CS CRSP")
ccm = linktabledownload()
ccm[:linkenddt] = Missings.coalesce.(ccm[:linkenddt],Dates.Date(now())+Dates.Year(1))
ccm[:linkdt] = Missings.coalesce.(ccm[:linkdt],minimum(ccm[:linkdt]))

#Link Compustat with link table (permno)
#ccm1 = linked CSdf
ccm1=join(CSdf,ccm,kind=:left,on=[:gvkey])
ccm1[[:gvkey,:datadate,:linkdt, :permno]]

# Set all compustat observations to last day of following year's june
ccm1[:yearend] = ccm1[:datadate]
for row in eachrow(ccm1)
    row[:yearend] = ceil(row[:yearend], Dates.Year)-Dates.Day(1)
end
ccm1[:jdate] = ccm1[:yearend]+Dates.Month(6)

# set link date bounds
ccm1[:permno] = Missings.coalesce.(ccm1[:permno],0)
#From 2000 to 2018, approx 22.5% of OBSERVATIONS had no matching permno at all
ccm1 = ccm1[ccm1[:permno].!=0, :]
#From 2000 to 2018, approx 30.7% of remaining OBSERVATIONS had no matching link during period
ccm1 = ccm1[ccm1[:jdate].<=ccm1[:linkenddt], :]
ccm1=ccm1[ccm1[:jdate].>=ccm1[:linkdt], :]

#only need BE in yearly, all other accounting data will be gathered quarterly
ccm1 = ccm1[[:gvkey, :permno, :datadate, :yearend, :jdate, :be, :naicsh]]
ccm1[:gvkey] = map(parse, ccm1[:gvkey])

# match gvkey with permID
matched = CSV.read("/home/nicolas/Data/permidmatch/matched.csv")
deletemissingrows!(matched, Symbol("Match OpenPermID"))
endstring = x -> x[end-9:end]
matched[:permid] = map(endstring, matched[Symbol("Match OpenPermID")])
matched[:permid] = map(parse, matched[:permid])
rename!(matched, :Input_LocalID => :gvkey)
matched = matched[[:gvkey, :permid]]
ccm1 = join(ccm1, matched, kind=:left, on=[:gvkey])

ccm1[ccm1[:gvkey].==12994,:]

# merge CRSP with Compustat
ccm_jun = join(crsp_jun, ccm1, kind=:inner, on=[:permno, :jdate])


###########################
# Breakpoints computation #
###########################
print("Breakpoint computation")
# Compute book-to-market ratio
ccm_jun[:beme]=ccm_jun[:be]*1000./ccm_jun[:dec_me]

ccm_jun[[:permno, :permid, :gvkey, :datadate]]


# select NYSE stocks for bucket breakdown
# exchcd = 1 and positive beme and positive me and shrcd in (10,11) and at least 2 years in comp
ccm_jun[:posbm] = 0
for row in eachrow(ccm_jun)
    if !(ismissing(row[:beme])) && !(ismissing(row[:me])) && row[:beme]>0 && row[:me]>0
        row[:posbm] = 1
    end
end
# by(nyse, [:jdate],nyse -> DataFrame(count = percentile(Array{Float64}(nyse[:beme]), [10]),size20 = percentile(Array{Float64}(nyse[:me]), [20])))
nyse=ccm_jun[ccm_jun[:exchcd].==1, :]
nyse=nyse[nyse[:posbm].==1, :]
nyse=nyse[find(x -> x in [10,11], nyse[:shrcd]), :]
# size breakdown
nyse_size = by(nyse, [:jdate], nyse -> DataFrame(
                size10 = percentile(Array{Float64}(nyse[:me]), [10]),
                size20 = percentile(Array{Float64}(nyse[:me]), [20]),
                size30 = percentile(Array{Float64}(nyse[:me]), [30]),
                size40 = percentile(Array{Float64}(nyse[:me]), [40]),
                size50 = percentile(Array{Float64}(nyse[:me]), [50]),
                size60 = percentile(Array{Float64}(nyse[:me]), [60]),
                size70 = percentile(Array{Float64}(nyse[:me]), [70]),
                size80 = percentile(Array{Float64}(nyse[:me]), [80]),
                size90 = percentile(Array{Float64}(nyse[:me]), [90])))# beme breakdown
nyse_bm = by(nyse, [:jdate], nyse -> DataFrame(
                bm10 = percentile(Array{Float64}(nyse[:beme]), [10]),
                bm20 = percentile(Array{Float64}(nyse[:beme]), [20]),
                bm30 = percentile(Array{Float64}(nyse[:beme]), [30]),
                bm40 = percentile(Array{Float64}(nyse[:beme]), [40]),
                bm50 = percentile(Array{Float64}(nyse[:beme]), [50]),
                bm60 = percentile(Array{Float64}(nyse[:beme]), [60]),
                bm70 = percentile(Array{Float64}(nyse[:beme]), [70]),
                bm80 = percentile(Array{Float64}(nyse[:beme]), [80]),
                bm90 = percentile(Array{Float64}(nyse[:beme]), [90])))
nyse_breaks = join(nyse_size, nyse_bm, kind=:inner, on=[:jdate])
ccm_jun = join(ccm_jun, nyse_breaks, kind=:left, on=[:jdate])
ccm_jun[:ptf_2by3_size_value] = ""
ccm_jun[:ptf_5by5_size_value] = 0.0
ccm_jun[:ptf_10by10_size_value] = 99.99
ccm_jun[:ranksize] = ""
ccm_jun[:rankbm] = ""
for row in eachrow(ccm_jun)
    if !(ismissing(row[:beme])) && !(ismissing(row[:me])) && row[:beme]>0 && row[:me]>0
        # Size classification
        if row[:me]<row[:size50]
            row[:ranksize]="S"
        elseif row[:me]>=row[:size50]
            row[:ranksize]="B"
        end
        # BM classification
        if 0<=row[:beme]<=row[:bm30]
            row[:rankbm]="L"
        elseif row[:bm30]<row[:beme]<=row[:bm70]
            row[:rankbm]="M"
        elseif row[:bm70]<row[:beme]
            row[:rankbm]="H"
        end
        # 2by3 portfolio construction
        if 0<=row[:me]<row[:size50]
            if 0<=row[:beme]<row[:bm30]
                row[:ptf_2by3_size_value]="SL"
            elseif row[:bm30]<=row[:beme]<row[:bm70]
                row[:ptf_2by3_size_value]="SM"
            elseif row[:bm70]<=row[:beme]
                row[:ptf_2by3_size_value]="SH"
            end
        elseif row[:size50]<=row[:me]
            if 0<=row[:beme]<row[:bm30]
                row[:ptf_2by3_size_value]="BL"
            elseif row[:bm30]<=row[:beme]<row[:bm70]
                row[:ptf_2by3_size_value]="BM"
            elseif row[:bm70]<=row[:beme]
                row[:ptf_2by3_size_value]="BH"
            end
        end
        # 5by5 portfolio construction
        if 0<=row[:me]<row[:size20]
            if 0<=row[:beme]<row[:bm20]
                row[:ptf_5by5_size_value]=1.1
            elseif row[:bm20]<=row[:beme]<row[:bm40]
                row[:ptf_5by5_size_value]=1.2
            elseif row[:bm40]<=row[:beme]<row[:bm60]
                row[:ptf_5by5_size_value]=1.3
            elseif row[:bm60]<=row[:beme]<row[:bm80]
                row[:ptf_5by5_size_value]=1.4
            elseif row[:bm80]<=row[:beme]
                row[:ptf_5by5_size_value]=1.5
            end
        elseif row[:size20]<=row[:me]<row[:size40]
            if 0<=row[:beme]<row[:bm20]
                row[:ptf_5by5_size_value]=2.1
            elseif row[:bm20]<=row[:beme]<row[:bm40]
                row[:ptf_5by5_size_value]=2.2
            elseif row[:bm40]<=row[:beme]<row[:bm60]
                row[:ptf_5by5_size_value]=2.3
            elseif row[:bm60]<=row[:beme]<row[:bm80]
                row[:ptf_5by5_size_value]=2.4
            elseif row[:bm80]<=row[:beme]
                row[:ptf_5by5_size_value]=2.5
            end
        elseif row[:size40]<=row[:me]<row[:size60]
            if 0<=row[:beme]<row[:bm20]
                row[:ptf_5by5_size_value]=3.1
            elseif row[:bm20]<=row[:beme]<row[:bm40]
                row[:ptf_5by5_size_value]=3.2
            elseif row[:bm40]<=row[:beme]<row[:bm60]
                row[:ptf_5by5_size_value]=3.3
            elseif row[:bm60]<=row[:beme]<row[:bm80]
                row[:ptf_5by5_size_value]=3.4
            elseif row[:bm80]<=row[:beme]
                row[:ptf_5by5_size_value]=3.5
            end
        elseif row[:size60]<=row[:me]<row[:size80]
            if 0<=row[:beme]<row[:bm20]
                row[:ptf_5by5_size_value]=4.1
            elseif row[:bm20]<=row[:beme]<row[:bm40]
                row[:ptf_5by5_size_value]=4.2
            elseif row[:bm40]<=row[:beme]<row[:bm60]
                row[:ptf_5by5_size_value]=4.3
            elseif row[:bm60]<=row[:beme]<row[:bm80]
                row[:ptf_5by5_size_value]=4.4
            elseif row[:bm80]<=row[:beme]
                row[:ptf_5by5_size_value]=4.5
            end
        elseif row[:size80]<=row[:me]
            if 0<=row[:beme]<row[:bm20]
                row[:ptf_5by5_size_value]=5.1
            elseif row[:bm20]<=row[:beme]<row[:bm40]
                row[:ptf_5by5_size_value]=5.2
            elseif row[:bm40]<=row[:beme]<row[:bm60]
                row[:ptf_5by5_size_value]=5.3
            elseif row[:bm60]<=row[:beme]<row[:bm80]
                row[:ptf_5by5_size_value]=5.4
            elseif row[:bm80]<=row[:beme]
                row[:ptf_5by5_size_value]=5.5
            end
        end
        # 10by10 portfolio construction
        if 0<=row[:me]<row[:size10]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=0.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=0.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=0.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=0.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=0.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=0.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=0.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=0.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=0.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=0.9
            end
        elseif row[:size10]<=row[:me]<row[:size20]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=1.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=1.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=1.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=1.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=1.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=1.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=1.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=1.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=1.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=1.9
            end
        elseif row[:size20]<=row[:me]<row[:size30]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=2.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=2.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=2.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=2.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=2.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=2.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=2.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=2.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=2.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=2.9
            end
        elseif row[:size30]<=row[:me]<row[:size40]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=3.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=3.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=3.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=3.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=3.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=3.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=3.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=3.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=3.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=3.9
            end
        elseif row[:size40]<=row[:me]<row[:size50]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=4.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=4.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=4.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=4.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=4.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=4.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=4.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=4.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=4.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=4.9
            end
        elseif row[:size50]<=row[:me]<row[:size60]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=5.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=5.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=5.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=5.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=5.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=5.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=5.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=5.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=5.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=5.9
            end
        elseif row[:size60]<=row[:me]<row[:size70]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=6.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=6.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=6.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=6.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=6.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=6.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=6.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=6.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=6.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=6.9
            end
        elseif row[:size70]<=row[:me]<row[:size80]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=7.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=7.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=7.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=7.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=7.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=7.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=7.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=7.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=7.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=7.9
            end
        elseif row[:size80]<=row[:me]<row[:size90]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=8.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=8.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=8.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=8.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=8.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=8.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=8.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=8.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=8.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=8.9
            end
        elseif row[:size90]<=row[:me]
            if 0<=row[:beme]<row[:bm10]
                row[:ptf_10by10_size_value]=9.0
            elseif row[:bm10]<=row[:beme]<row[:bm20]
                row[:ptf_10by10_size_value]=9.1
            elseif row[:bm20]<=row[:beme]<row[:bm30]
                row[:ptf_10by10_size_value]=9.2
            elseif row[:bm30]<=row[:beme]<row[:bm40]
                row[:ptf_10by10_size_value]=9.3
            elseif row[:bm40]<=row[:beme]<row[:bm50]
                row[:ptf_10by10_size_value]=9.4
            elseif row[:bm50]<=row[:beme]<row[:bm60]
                row[:ptf_10by10_size_value]=9.5
            elseif row[:bm60]<=row[:beme]<row[:bm70]
                row[:ptf_10by10_size_value]=9.6
            elseif row[:bm70]<=row[:beme]<row[:bm80]
                row[:ptf_10by10_size_value]=9.7
            elseif row[:bm80]<=row[:beme]<row[:bm90]
                row[:ptf_10by10_size_value]=9.8
            elseif row[:bm90]<=row[:beme]
                row[:ptf_10by10_size_value]=9.9
            end
        end
    end
end
a = countmap(ccm_jun[:ptf_2by3_size_value])


##########################
# Monthly CRSP yearly CS #
##########################
print("merge monthly CRSP with yearly CS")
# create positivebeme and nonmissport variable
ccm_jun[:nonmissport] = 0
for row in eachrow(ccm_jun)
    if row[:rankbm]!=""
        row[:nonmissport]=1
    end
end
sum(ccm_jun[:nonmissport])

june = ccm_jun[[:permno, :gvkey, :permid, :date, :naicsh, :beme, :be, :me, :jdate, :rankbm, :ranksize, :posbm, :nonmissport, :ptf_10by10_size_value, :ptf_2by3_size_value, :ptf_5by5_size_value]]
june[:ffyear] = Dates.year(june[:jdate])

# Join monthly CRSP return data to yearly CS data
ccm3 = join(CRSPdf, june, kind=:left, on=[:permno, :ffyear])

ccm3[[:date, :posbm, :permid, :permno, :gvkey]]
ccm4 = ccm3[ccm3[:date].>=truestart, :]
deletemissingrows!(ccm4, :posbm)
ccm4 = ccm4[ccm4[:posbm].==1, :]
deletemissingrows!(ccm4, :nonmissport)
ccm4 = ccm4[ccm4[:nonmissport].==1, :]
deletemissingrows!(ccm4, :wt)
ccm4 = ccm4[ccm4[:wt].>0, :]
ccm4=ccm4[find(x -> x in [10,11], ccm4[:shrcd]), :]

for i in names(ccm4)
    print("$i\n")
end
ccm_jun[[:year, :yearend, :jdate]]

ccm4 = ccm4[[:date, :permno, :gvkey, :permid, :ffyear, :vol, :exchcd, :retadj, :me,
             :beme, :be, :wt, :naicsh, :rankbm, :ranksize, :ptf_10by10_size_value,
             :ptf_2by3_size_value, :ptf_5by5_size_value, :year, :month]]
rename!(ccm4, :retadj => :monthlyretadj)
rename!(ccm4, :vol => :monthlyvol)
rename!(ccm4, :date => :monthlydate)

#######################
# Quarterly CS data   #
#######################
# CSvariables = "gvkey, datadate, cusip, rdq, tic, conm, cik, atq, ceqq, ibq,
#                ltq, revtq, saleq, seqq, txditcq, xintq, pstkq" #addzip, city, conml, naicsh, state
# CSdatatable = "comp.fundq"
# CSdfq = WRDSdownload.CSdownload(CSdaterange, CSvariables, CSdatatable)
#
# #compute quarterly date for match
# CSdfq[:yearend] = CSdfq[:datadate]
# for row in eachrow(CSdfq)
#     row[:yearend] = ceil(row[:yearend], Dates.Year)-Dates.Day(1)
# end



#######################
#      Daily data     #
#######################
print("Downloading daily data!...")
CRSPvariables = "a.permno, a.date,a.ret, a.vol"
CRSPdatatable = ["crsp.dsf", "crsp.dsenames"]
CRSPdf = CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable)
print("Data downloaded!")
delistdf = delistdownload(exchfq)
exchfq="d"
if exchfq=="m"
    delistdf[:jdate] = Date(0,1,1)
    for row in eachrow(delistdf)
        row[:jdate] = ceil(row[:dlstdt], Dates.Month)-Dates.Day(1)
    end
    CRSPdf = join(CRSPdf, delistdf, on = [:jdate, :permno], kind = :left)
elseif exchfq=="d"
    names!(delistdf, [:permno, :dlret, :date])
    CRSPdf = join(CRSPdf, delistdf, on = [:date, :permno], kind = :left)
end
CRSPdf[ismissing.(CRSPdf[:dlret]), :dlret] = 0
# Set missing returns to 0 (only <0.001% in monthly)
CRSPdf[ismissing.(CRSPdf[:ret]), :ret] = 0
# Compute adjusted return including delisting
CRSPdf[:retadj]=(1+CRSPdf[:ret]).*(1+CRSPdf[:dlret])-1
CRSPdf[:year] = Dates.year.(CRSPdf[:date])
CRSPdf[:month] = Dates.month.(CRSPdf[:date])
CRSPdf = CRSPdf[[:year, :month, :permno, :retadj, :date, :vol]]
names!(CRSPdf, [:year, :month, :permno, :dailyretadj, :dailydate, :dailyvol])
Result = join(CRSPdf, ccm4, kind=:left, on=[:year, :month, :permno])
deletemissingrows!(Result, :monthlydate)


################################
# Earnings Announcemnt Dates   #
################################
print("Compute EAD")
CSvariables = "gvkey, datadate, rdq" #addzip, city, conml, naicsh, state
CSdatatable = "comp.fundq"
EAdfq = WRDSdownload.CSdownload(CSdaterange, CSvariables, CSdatatable)
EAdfq[:EAD] = 1
EAdfq = EAdfq[[:gvkey, :rdq, :EAD]]
deletemissingrows!(EAdfq, :rdq)
rename!(EAdfq, :rdq => :dailydate)
EAdfq[:gvkey] = map(parse, EAdfq[:gvkey])
Result = join(Result, EAdfq, kind=:left, on=[:dailydate, :gvkey])
Result[[:monthlydate, :gvkey, :rankbm, :dailydate, :EAD]]
for row in eachrow(Result)
    if ismissing(row[:EAD])
        row[:EAD]=0
    end
end
sum(Result[:EAD])


# deletemissingrows!(Result, :rankbm)

# CSV.write("/run/media/nicolas/OtherData/home/home/nicolas/Data/WRDS/daily2003_2018.csv", Result)
print("Insert in DAtabase")
using Mongo, TimeZones
client = MongoClient()
CRSPConnect = MongoCollection(client, "NewsDB", collection)
cc=0
for row in eachrow(Result)
    cc+=1
    if cc%100000==0
        print(cc)
    end
    if ismissing(row[:permid])
        row[:permid] = 0
    end
    if ismissing(row[:naicsh])
        row[:naicsh] = 0
    end
    if !(ismissing(row[:ptf_5by5_size_value]))
        p_oid = insert(CRSPConnect,
                ("permno" => row[:permno],
                 "EAD" => row[:EAD],
                 "gvkey" => row[:gvkey],
                 "permid" => row[:permid],
                 "monthlyretadj" => row[:monthlyretadj],
                 "dailyretadj" => row[:dailyretadj],
                 "dailydate" => DateTime(ZonedDateTime(DateTime(row[:dailydate])+Dates.Hour(16), tz"America/New_York")),
                 "monthlydate" => row[:monthlydate],
                 "ptf_2by3_size_value" => row[:ptf_2by3_size_value],
                 "ptf_10by10_size_value" => row[:ptf_10by10_size_value],
                 "ptf_5by5_size_value" => row[:ptf_5by5_size_value],
                 "rankbm" => row[:rankbm],
                 "ranksize" => row[:ranksize],
                 "me" => row[:me],
                 "be" => row[:be],
                 "beme" => row[:be],
                 "wport" => row[:wt],
                 "exchcd" => row[:exchcd],
                 "naicsh"  => row[:naicsh]
                 ))
    end
end
