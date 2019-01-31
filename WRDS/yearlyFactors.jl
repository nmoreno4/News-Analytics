##########################################################################################
# This file gathers yearly data from Compustat and monthly data from CRSP to construct
# FF factor breakpoints. It stores the merged monthly CRSP data, the yearly CS and the
# size and B/M decile rankings in the MongoDB Dec2018 database in collection PermnoDay.
##########################################################################################
using WRDSdownload, CSV, DataFrames, JLD2, StatsBase, Dates, Statistics,
      RollingFunctions, ShiftedArrays, Buckets, PermidMatch

#Span of working period
CSdaterange = ["01/01/2000", "12/31/2019"]
CRSPdaterange = ["01/01/2000", "7/1/2018"]
truestart = Dates.Date(2003,1,1)
trueend = Dates.Date(2017,12,31)

############## Compustat Variable description ##############
# at:
# ceq: Common/Ordinary Equity - Total
# lt:
# seq: Total Parent Stockholders' Equity. This item represents the common and preferred
#      shareholders' interest in the company. (= CEQ + PSTK). It includes:
#          - Capital surplus
#          - Common/Ordinary Stock (Capital)
#          - Nonredeemable preferred stock
#          - Redeemable preferred stock
#          - Retained earnings
#          - Treasury Stock
# txditc: Deferred Taxes and Investment Tax Credit (= TXDB + ITCB) [Balance sheet]
# pstkrv: Preferred Stock redemption value
# pstkl: Preferred Stock liquidating value
# pstk: Preferred Stock (Capital) - Total (= pstkn + pstkr)
# cik:
# naicsh:
#############################################################
CSvariables = "gvkey, datadate, cusip, at, ceq, lt, seq, txditc, pstkrv,
               pstkl, pstk, tic, conm, cik, naicsh, indfmt"
CSdatatable = "comp.funda"
############## CRSP Variable description ##############
# ret:
# retx:
# shrout:
# prc:
# vol:
# spread:
########################################################
CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                 a.retx, a.shrout, a.prc, a.vol, a.spread"
CRSPdatatable = ["crsp.msf", "crsp.msenames"]



# Download Compustat data from server
CSdf = CSdownload(CSdaterange, CSvariables, CSdatatable)
CSdf[:year] = Dates.year.(CSdf[:datadate])

######################### FF definition of B/E: ###########################################
# Book equity = (Book value of stockholder equity)[seq] + (deferred taxes)
#              + (investment tax credit) - (book value of preferrerd stock)[ps]
# Book value of preferrerd stock = 1. ps redemption value
#                             *or* 2. ps liquidation value
#                             *or* 3. ps par value
#                             --> In that order
# We do not use negative-BE firms, which are rare before 1980, when calculating
# the breakpoints for BE/ME or when forming the size-BE/ME portfolios.
##########################################################################################
# create preferrerd stock
a = coalesce.(CSdf[:pstkrv],CSdf[:pstkl])
b = coalesce.(a,CSdf[:pstk])
CSdf[:ps] = coalesce.(a,CSdf[:pstk],0)

# Compute book equity
CSdf[:txditc] = coalesce.(CSdf[:txditc],0)
CSdf[:be] = CSdf[:seq] .+ CSdf[:txditc] .- CSdf[:ps]
# Set all negative B/E to missing
for nonPosIdx in findall(replace(CSdf[:be].<0, missing=>true))
    CSdf[:be][nonPosIdx] = missing
end


######################### FF inclusion critera: ##########################################
# To be included in the tests, a firm must have CRSP stock prices for December
# of year t - 1 and June of t and COMPUSTAT book common equity for year t - 1.
# Moreover, to avoid the survival bias inherent in the way COMPUSTAT adds firms
# to its tapes [Banz and Breen (1986)], we do not include firms until
# they have appeared on COMPUSTAT for two years.
##########################################################################################

# number of years in Compustat
sort!(CSdf, [:gvkey, :datadate])
CSdf[:count] = by(CSdf, :gvkey, x1 = :year => x -> running(length, x, length(x)))[:x1]
# Keep only variables we will use later
CSdf=CSdf[[:gvkey,:datadate,:year,:be,:count,:tic,:conm,:at,:lt,:naicsh,:cik, :indfmt]]




# Download CRSP data from server
CRSPdf = CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable)

# change variable format to int
for var in [:permno, :permco, :shrcd, :exchcd]
    CRSPdf[var] = convert(Array{Int}, CRSPdf[var])
end

# Line up date to be end of month. At the end I will only keep those from the month of june.
CRSPdf[:jdate] = ceil.(CRSPdf[:date] .+ Dates.Day(1), Dates.Month) .- Dates.Day(1)

# Download delisting return table
delistdf = delistdownload("m")
delistdf[:jdate] = ceil.(delistdf[:dlstdt] .+ Dates.Day(1), Dates.Month) .- Dates.Day(1)

@time CRSPdf = join(CRSPdf, delistdf, on = [:permno, :jdate], kind = :left)
CRSPdf[ismissing.(CRSPdf[:dlret]), :dlret] = 0
CRSPdf[ismissing.(CRSPdf[:ret]), :ret] = 0
CRSPdf[:retadj]=(1 .+ CRSPdf[:ret]) .* (1 .+ CRSPdf[:dlret]) .-1

# Compute market equity : ME = Price * Shares Outstanding
CRSPdf[:me] = abs.(CRSPdf[:prc] .* CRSPdf[:shrout])
DataFrames.deletecols!(CRSPdf, [:dlret, :dlstdt, :shrout])
@time sort!(CRSPdf, [:jdate, :permco, :me])

# Aggregate Market Cap permno-permco
# sum of me across different permno belonging to same permco a given date
crsp_summe = @time by(CRSPdf, [:jdate, :permco], me = :me => x-> sum(skipmissing(x)))
# largest mktcap within a permco/date
crsp_maxme = @time by(CRSPdf, [:jdate, :permco], me = :me => x-> length(collect(skipmissing(x))) > 0 ? maximum(skipmissing(x)) : missing )
# Keep only permno with max permcos. Join by jdate/maxme to find the permno
CRSPdf = @time join(CRSPdf, crsp_maxme, on = [:jdate, :permco, :me], kind = :inner)
# drop me column and replace with the sum me
DataFrames.deletecols!(CRSPdf, :me)
# join with sum of me to get the correct market cap info
CRSPdf = join(CRSPdf, crsp_summe, on = [:jdate, :permco], kind = :inner)
sort!(CRSPdf, [:permno, :jdate])


### keep December market cap ###
CRSPdf[:year] = Dates.year.(CRSPdf[:jdate])
CRSPdf[:month] = Dates.month.(CRSPdf[:jdate])
decme = CRSPdf[findall(CRSPdf[:month] .== 12), :]
decme = decme[:, [:permno, :date, :jdate, :me, :year]]
names!(decme, [:permno, :date, :jdate, :dec_me, :year])

### July to June dates ###
CRSPdf[:ffdate] = ceil.(CRSPdf[:jdate] .-Dates.Month(6) .+ Dates.Day(1), Dates.Month) .- Dates.Day(1)
CRSPdf[:ffyear] = Dates.year.(CRSPdf[:ffdate])
CRSPdf[:ffmonth] = Dates.month.(CRSPdf[:ffdate])
CRSPdf[ismissing.(CRSPdf[:retx]), :retx] = 0
CRSPdf[:retxplus1] = 1 .+ CRSPdf[:retx]
@time sort!(CRSPdf, [:permno, :jdate])

CRSPdf[:cumretx] = by(CRSPdf, [:permno, :ffyear], cumretx = :retxplus1 => x-> cumprod(x))[:cumretx]
# lag cumret
CRSPdf[:lcumretx] = by(CRSPdf, [:permno], lcumretx = :cumretx => x-> ShiftedArrays.lag(x))[:lcumretx]
# lag market cap
CRSPdf[:lme] = by(CRSPdf, [:permno], lme = :me => x-> ShiftedArrays.lag(x))[:lme]

# if first permno then use me/(1+retx) to replace the missing value
CRSPdf[:count] = by(CRSPdf, :permno, x1 = :permno => x -> running(length, x, length(x)).-1 )[:x1]
for row in 1:size(CRSPdf,1)
    if CRSPdf[row, :count] == 0 # if first occurence of a stock (missing ME)
        CRSPdf[row, :lme] = CRSPdf[row,:me]/CRSPdf[row,:cumretx]
    end
end
deletecols!(CRSPdf, :count)


# baseline me from which I will compute the drift in weight_port.
# Since I rebalance at the end of june I start the drift of a new year in july
mebase = CRSPdf[CRSPdf[:ffmonth] .== 1, :] # i.e. ==July
mebase = mebase[[:permno, :ffyear, :lme]]
names!(mebase, [:permno, :ffyear, :mebase])

# merge result back together. :mebase contains the :me in July
CRSPdf = join(CRSPdf, mebase, on = [:permno, :ffyear], kind = :left)
CRSPdf[:wt] = Array{Union{Float64, Missing}}(undef,size(CRSPdf,1))
for row in eachrow(CRSPdf)
    if row[:ffmonth]==1
        row[:wt]=row[:lme]
    else
        row[:wt]=row[:mebase]*row[:lcumretx]
    end
end

decme[:year]=decme[:year].+1
decme=decme[[:permno,:year,:dec_me]]

# Create a matrix with the CRSP info from june + a column with the :me at the end of the
# year (December).
crsp_jun = CRSPdf[CRSPdf[:month].==6,:]
crsp_jun = join(crsp_jun, decme, on=[:permno, :year], kind=:inner)


#######################
# CCM Block           #
#######################
ccm = linktabledownload()
# if linkenddt is missing then set to today date
ccm[:linkenddt] = replace(ccm[:linkenddt], missing=>Dates.Date(now()))
# ccm[:linkdt] = Missings.coalesce.(ccm[:linkdt],minimum(ccm[:linkdt]))
#Link Compustat with link table (permno)
ccm1=join(CSdf,ccm,kind=:left,on=[:gvkey])
# Set all compustat observations to last day of following year's june
ccm1[:yearend] = ceil.(ccm1[:datadate] .+ Dates.Day(1), Dates.Year) .- Dates.Day(1)
ccm1[:jdate] = ceil.(ccm1[:yearend] .+ Dates.Month(6) .+ Dates.Day(1), Dates.Month) .- Dates.Day(1)

# set link date bounds
jdateInBounds = findall((replace(ccm1[:jdate].>=ccm1[:linkdt], missing=>false)) .& (replace(ccm1[:jdate].<=ccm1[:linkenddt], missing=>false)))
ccm2 = ccm1[jdateInBounds,:]
ccm2=ccm2[[:gvkey,:permno,:datadate,:yearend,:jdate,:be,:count,:tic,:conm,:at,:lt,:naicsh,:cik,:indfmt]]
ccm2[:gvkey] = parse.(Int, ccm2[:gvkey])

#########################
# GVKEY - PERMID match #
#########################

# Create splitted DFs to feed into permid.org entity matcher
splitCSVforPermiDMatch(ccm2)

# Gather and merge splitted DFs from permid.org entity matcher
permidMatcher = gvkeyPermidMatchDF()
permidMatcher = permidMatcher[[Symbol("Match OpenPermID"),Symbol("Match Score"),:Input_LocalID, :Input_Name]]

# Print match info
noMissingMatch = permidMatcher[.!ismissing.(permidMatcher[Symbol("Match Score")]),:]
nomatch = size(permidMatcher,1) - size(noMissingMatch,1)
matchprop = round(nomatch/size(permidMatcher,1)*100)
print("\n There were $nomatch stocks that had no permId match, which represents ~$matchprop % of total")
perfectMatch = size(noMissingMatch[noMissingMatch[Symbol("Match Score")].=="100%",:],1)
perfectMatchprop = round(perfectMatch/size(permidMatcher,1)*100)
print("\n There were $perfectMatch stocks that had a 100% permId match, which represents ~$perfectMatchprop % of total")

# Create permid --> gvkey converter
endstring = x -> x[end-9:end]
noMissingMatch[:permid] = parse.(Int, map(endstring, noMissingMatch[Symbol("Match OpenPermID")]))
rename!(noMissingMatch, :Input_LocalID => :gvkey)
noMissingMatch = noMissingMatch[[:gvkey, :permid]]
gvkeyToPermid = Dict(zip(noMissingMatch[:gvkey], noMissingMatch[:permid]))
ccm3 = join(ccm2, noMissingMatch, kind=:left, on=[:gvkey])



###########################
# Breakpoints computation #
###########################

#### Merge june CRSP with Compustat for bucket creation ####
ccm_jun = join(crsp_jun, ccm3, kind=:inner, on=[:permno, :jdate])

# Compute book-to-market ratio
ccm_jun[:beme]=ccm_jun[:be] .* 1000 ./ ccm_jun[:dec_me]
# histogram(windsorize(collect(skipmissing(ccm_jun[:beme])), 97, 0))
# select NYSE stocks for bucket breakdown
# exchcd = 1 and positive beme and positive me and shrcd in (10,11) and at least 2 years in comp

nyse=ccm_jun[ccm_jun[:exchcd].==1, :] # Removes ~60% of observations
nyse=nyse[findall(x -> x in [10,11], nyse[:shrcd]), :] # Removes another ~10% of observations
nyse=nyse[.!ismissing.(nyse[:beme]).>0, :]
nyse=nyse[.!ismissing.(nyse[:me]).>0, :]
nyse=nyse[nyse[:count].>2, :] # End up with ~20% of initial observations

# Compute breakpoints by year
nyse_size = by(nyse, [:jdate], nyse -> DataFrame(
                size10 = percentile(Array{Float64}(nyse[:me]), [10]),
                size20 = percentile(Array{Float64}(nyse[:me]), [20]),
                size30 = percentile(Array{Float64}(nyse[:me]), [30]),
                size40 = percentile(Array{Float64}(nyse[:me]), [40]),
                size50 = percentile(Array{Float64}(nyse[:me]), [50]),
                size60 = percentile(Array{Float64}(nyse[:me]), [60]),
                size70 = percentile(Array{Float64}(nyse[:me]), [70]),
                size80 = percentile(Array{Float64}(nyse[:me]), [80]),
                size90 = percentile(Array{Float64}(nyse[:me]), [90])))
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
sort!(nyse_bm, :jdate);sort!(nyse_size, :jdate)
nyse_breaks = join(nyse_size, nyse_bm, kind=:inner, on=[:jdate])
ccm_jun = join(ccm_jun, nyse_breaks, kind=:left, on=[:jdate])
ccm_jun[:ranksize] = Array{Union{Missing,Int}}(undef, size(ccm_jun,1))
ccm_jun[:rankbm] = Array{Union{Missing,Int}}(undef, size(ccm_jun,1))
bmcols = [Symbol("bm$(i)") for i in 10:10:90]
sizecols = [Symbol("size$(i)") for i in 10:10:90]
for row in 1:size(ccm_jun,1)
    bmBPs = [ccm_jun[row,col] for col in bmcols]
    sizeBPs = [ccm_jun[row,col] for col in sizecols]
    if !ismissing(ccm_jun[row,:beme]) && ccm_jun[row,:beme]>0 && !ismissing(ccm_jun[row,:me]) && ccm_jun[row,:me]>0 && ccm_jun[row,:count]>=2
        rankbm = assignBucket(ccm_jun[row,:beme], bmBPs)
        if typeof(rankbm)==Int
            ccm_jun[row, :rankbm] = rankbm
        end
    end
    if !ismissing(ccm_jun[row,:beme]) && ccm_jun[row,:beme]>0 && !ismissing(ccm_jun[row,:me]) && ccm_jun[row,:me]>0 && ccm_jun[row,:count]>=2
        ranksize = assignBucket(ccm_jun[row,:me], sizeBPs)
        if typeof(ranksize)==Int
            ccm_jun[row, :ranksize] = ranksize
        end
    end
end

# Recompute ffyear for match
ccm_jun[:ffyear] = Dates.year.(ccm_jun[:jdate])

# delete breakpoints and CRSP info columns
DataFrames.deletecols!(ccm_jun, [bmcols;sizecols])
DataFrames.deletecols!(ccm_jun, [:permco, :date, :shrcd, :exchcd, :ret, :retx, :prc, :vol, :spread,
                  :retadj, :me, :year,:month, :ffdate, :ffmonth, :retxplus1, :jdate,
                  :cumretx, :lcumretx, :lme, :mebase, :wt])

##################################################
# Merge yearly CS breakpoints with Monthly CRSP  #
##################################################

monthlyMerge = join(CRSPdf, ccm_jun, kind=:left, on=[:permno, :ffyear])

monthlyMerge[:posbm] = 0
for row in eachrow(monthlyMerge)
    if !(ismissing(row[:beme])) && !(ismissing(row[:me])) && row[:beme]>0 && row[:me]>0 && row[:count]>=2
        row[:posbm] = 1
    end
end
monthlyMerge = monthlyMerge[monthlyMerge[:posbm].==1, :]
monthlyMerge = monthlyMerge[.!ismissing.(monthlyMerge[:wt]).>=1, :]
monthlyMerge = monthlyMerge[.!ismissing.(monthlyMerge[:rankbm]), :]
monthlyMerge=monthlyMerge[findall(x -> x in [10,11], monthlyMerge[:shrcd]), :]

monthlyMerge[[:date, :permno, :rankbm,:ranksize, :ffyear, :beme, :jdate]][10:15,:]

ymonth = []
for (y,m) in zip(Dates.year.(monthlyMerge[:date]) ,Dates.month.(monthlyMerge[:date]))
    push!(ymonth, y*100+m)
end
monthlyMerge[:ymonth] = ymonth
monthlyMerge = monthlyMerge[monthlyMerge[:date].>=truestart, :]
monthlyMerge = monthlyMerge[monthlyMerge[:date].<=trueend, :]

monthlyMerge = monthlyMerge[[:permno, :gvkey, :permid, :ymonth, :prc, :vol, :spread, :retadj, :me,
                             :wt, :conm, :at, :lt, :naicsh, :beme, :ranksize, :rankbm,:indfmt]]
names!(monthlyMerge, [:permno, :gvkey, :permid, :ymonth, :prcM, :volM, :spreadM, :retadjM, :meM,
                      :wt, :conm, :atY, :ltY, :naicshY, :bemeY, :ranksize, :rankbm,:indfmt])


##########################################
# Merge daily MongoDB with monthly data  #
##########################################
using Mongoc, Dates, JSON, DataStructures
client = Mongoc.Client()
database = client["Jan2019"]
collection = database["PermnoDay"]

for row in 1:size(monthlyMerge,1)

    # Show advancement
    if row in 10:30000:size(monthlyMerge,1)
        print("Advnacement : ~$(round(100*row/size(monthlyMerge,1)))% \n")
    end

    crtrow = monthlyMerge[row:row,:]
    colids = names(crtrow)

    # Create a dictionary to insert dropping missing values
    colstodelete = Symbol[]
    for i in 1:size(crtrow,2)
        if ismissing(crtrow[i][1])
            push!(colstodelete, colids[i])
        end
    end
    if length(colstodelete)>0
        deletecols!(crtrow,colstodelete)
    end

    # Create selector and updator dictionaries
    setDict = Dict(zip([string(x) for x in names(crtrow)], Matrix(crtrow)))
    selectDict = [Dict("permno"=>setDict["permno"]), Dict("ymonth"=>setDict["ymonth"])]
    delete!(setDict, ["permno", "ymonth"])

    # Update all matching in MongoDB
    crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
    crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
    Mongoc.update_many(collection, crtselector, crtupdate)
end
