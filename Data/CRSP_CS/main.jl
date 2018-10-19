##################################################################################################
#%% Load modules and Path
##################################################################################################
using ShiftedArrays, DataFrames, Dates, DataFramesMeta, CSV, StatsBase,
      Statistics, RollingFunctions, JLD2

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
