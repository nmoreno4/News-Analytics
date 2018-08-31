##################################################################################################
#%% Load modules and Path
tic()
##################################################################################################
push!(LOAD_PATH, "$(pwd())/CRSP_CS/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using CSV, Missings, DataFrames, JLD2, Suppressor, RCall, Query, StatsBase, JuliaDB,
      IterableTables, ShiftedArrays, StatsBase, FileIO
@rlibrary stlplus
@rlibrary RPostgres
using usefulNestedDF, otherCleaning, customWRDSvariables, Portfolio_Sorting, WRDSdownload
include("myfcts.jl")

print("Loading modules has taken $(toc()) seconds")


##################################################################################################
#%% Global variables
tic()
##################################################################################################
collection = "Denada"
#Span of working period
CSdaterange = ["01/01/1999", "12/31/2017"]
CRSPdaterange = ["01/01/1999", "6/30/2018"]
truestart = Dates.Date(2003,1,1)
# Start with yearly freq of accounting data
CSvariables = "gvkey, datadate, cusip, at, ceq, lt, seq, txditc, pstkrv,
               pstkl, pstk, tic, conm, cik, naicsh" #, addzip, city, conml, naicsh, state
CSdatatable = "comp.funda"
# Start with monthly freq of CRSP data
CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                 a.retx, a.shrout, a.prc, a.vol, a.spread"
CRSPdatatable = ["crsp.msf", "crsp.msenames"]

print("Setting of global variables has taken $(toc()) seconds")


##################################################################################################
#%% Download CS data
tic()
##################################################################################################
print("Downloading annual CS")
# Download Compustat data from server
CSdf = WRDSdownload.CSdownload(CSdaterange, CSvariables, CSdatatable)
CStable = JuliaDB.table(CSdf, pkey=(:gvkey, :datadate))
print("Downloading annual CS has taken $(toc()) seconds")


##################################################################################################
#%% CS treatment
tic()
##################################################################################################
# Add a column with the year of the observation
@time CStable = insertcolafter(CStable, :datadate, :year, Dates.year(select(CStable, :datadate)))
@time CSdf[:year] = Dates.year(CSdf[:datadate])

# number of years in Compustat
# Only works with annual data!!
@time prov = select(JuliaDB.groupby(@NT(count=z-> cumcount(z)),
        CStable, :gvkey, select=:gvkey, flatten=true), :count)
@time CStable = insertcolafter(CStable, :datadate, :count, prov)

#Keep only stocks having at least two years of history in compustat database
@time CStable = JuliaDB.filter(i -> (i.count .> 1), CStable)

# create preferrerd stock and balance sheet deferred taxes and investment tax credit (txditc)
@time prov = select(coalesceJuliaDB(CStable, (:pstkrv, :pstkl, :pstk)), :_1_)
@time CStable = insertcolafter(CStable, :pstk, :ps, prov)
@time prov = select(coalesceJuliaDB(CStable, (:txditc,1,1,1,1)), :_1_)
@time CStable = setcol(CStable, :txditc, prov)
#filter negative shareholder equity (seq) out
CStable = filter(i -> (i.seq >= 0), CStable)

#Compute BE and keep only positive values
@time be = JuliaDB.map(i -> i.seq + i.txditc - i.ps, CStable)
CStable = pushcol(CStable, :be, be)
CStable = filter(i -> (i.be > 0), CStable)

print("Exclusive CS treatment has taken $(toc()) seconds")


##################################################################################################
#%% Download CRSP data
tic()
##################################################################################################
print("Downloading monthly CS...")
# Download Compustat data from server
CRSPdf = CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable)
CRSPtable = JuliaDB.table(CRSPdf, pkey=(:permno, :permco, :date))
print("Downloading monthly CRSP has taken $(toc()) seconds")


##################################################################################################
#%% CRSP treatment
tic()
##################################################################################################
# Line up date to be end of month. It's called jdate because at the end I will only keep those from the month of june.
prov = JuliaDB.map(i ->  ceil(i.date, Dates.Month)-Dates.Day(1), CRSPtable)
CRSPtable = insertcolafter(CRSPtable, :date, :jdate, prov)
# Download delisting return table (monthly freq)
delistdf = delistdownload("m")
delisttable = JuliaDB.table(delistdf)
prov = JuliaDB.map(i ->  ceil(i.dlstdt, Dates.Month)-Dates.Day(1), delisttable)
delisttable = insertcolafter(delisttable, :dlstdt, :jdate, prov)
CRSPtable = reindex(CRSPtable, (:permno, :jdate))
delisttable = reindex(delisttable, (:permno, :jdate))
@time prov = select(coalesceJuliaDB(delisttable, (:dlret,1,1,1,1), idgroup=:permno), :_1_)
@time JuliaDB.join(CRSPtable,delisttable, how=:left)
CRSPdf = join(CRSPdf, delistdf, on = [:jdate, :permno], kind = :left)

l = table([1,1,1,2], [1,2,2,1], [1,2,3,4],
             names=[:a,:b,:c], pkey=(:a, :b))
r = table([0,1,1,2], [1,2,2,1], [1,2,3,4],
             names=[:a,:b,:d], pkey=(:a, :b))
