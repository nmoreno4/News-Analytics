##################################################################################################
#%% Load modules and Path
##################################################################################################
using ShiftedArrays, DataFrames, Dates, DataFramesMeta, CSV, StatsBase, Statistics, RollingFunctions

include("CRSP_CS/customfcts.jl")
include("CRSP_CS/breakpoints.jl")
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
                     a.retx, a.shrout, a.prc, a.vol, a.spread, a.hsicmg"
    monthly_CRSPdatatable = ["crsp.msf", "crsp.msenames"]
end

# print("Setting of global variables has taken $(toc()) seconds")


##################################################################################################
#%% Download CS data
##################################################################################################
@time begin
    print("Downloading annual CS\n")
    # Download Compustat data from server
    CSdf = CSdownload(CSdaterange, yearly_CSvariables, yearly_CSdatatable)
    sort!(CSdf, [:gvkey,:datadate])
    CSdf[:gvkey] = parse.(Int, CSdf[:gvkey]);
    print("Downloading annual CS has taken")
end
sectors = CSV.read("/home/nicolas/Data/Inputs/sectors.csv");
sectors[:datadate] = Dates.Date.(map(x->replace(x, "/"=>"-"), sectors[:datadate]));
a = join(CSdf, sectors, on=[:gvkey, :datadate, :cusip], kind=:left);
@time b = by(a, [:gvkey, :datadate]) do df
    DataFrame(indfmt = df[:indfmt][1])
end
CSdf = join(b, a, on=[:gvkey, :datadate, :indfmt], kind=:inner)

##################################################################################################
#%% CS treatment
##################################################################################################
# Add a column with the year of the observation
CSdf[:year] = Dates.year.(CSdf[:datadate])
# number of years in Compustat. Only works with annual data!!
@time prov = by(CSdf, :gvkey) do df
    DataFrame(count = cumcount(df[:year]), datadate = df[:datadate])
end
CSdf = join(CSdf, prov, on=[:gvkey, :datadate], kind=:inner)

#Keep only stocks having at least two years of history in compustat database
# CSdf = CSdf[(CSdf[:count].>1),:]
CSdf = CSdf[(CSdf[:year].>=2003),:]

# create preferrerd stock and balance sheet deferred taxes and investment tax credit (txditc)
CSdf[Symbol("ps")] = coalesce.(CSdf[Symbol("pstkrv")],CSdf[Symbol("pstkl")],CSdf[Symbol("pstk")],0.0)
CSdf[Symbol("txditc")] = coalesce.(CSdf[Symbol("txditc")],0.0)

# Compute be and replace non-positive values by missing
CSdf[Symbol("be")]=CSdf[Symbol("seq")]+CSdf[Symbol("txditc")]-CSdf[Symbol("ps")]
CSdf[:be]=val2missing.(CSdf[:be],0)


print("Exclusive CS treatment has taken")


##################################################################################################
#%% Download CRSP data
##################################################################################################
@time begin
    print("Downloading monthly CRSP...\n")
    # Download Compustat data from server
    CRSPdf = CRSPdownload(CRSPdaterange, monthly_CRSPvariables, monthly_CRSPdatatable)
    print("Downloading monthly CRSP has taken")
end


##################################################################################################
#%% CRSP treatment
##################################################################################################
# change variable format to int
CRSPdf[:permco] = Array{Int}(CRSPdf[:permco])
CRSPdf[:permno] = Array{Int}(CRSPdf[:permno])
CRSPdf[:shrcd] = Array{Int}(CRSPdf[:shrcd])
CRSPdf[:exchcd] = Array{Int}(CRSPdf[:exchcd])

# Line up date to be end of month. It's called jdate because at the end I will only keep those from the month of june.
@time CRSPdf[:jdate] = map(x->ceil(x, Dates.Month)-Dates.Day(1), CRSPdf[:date])

# Download delisting return table (monthly freq)
delistdf = delistdownload("m")
delistdf[:permno] = Array{Int}(delistdf[:permno])
@time delistdf[:jdate] = map(x->ceil(x, Dates.Month)-Dates.Day(1), delistdf[:dlstdt])
@time CRSPdf = join(CRSPdf, delistdf, on = [:permno, :jdate], kind = :left)
CRSPdf[:dlret]=coalesce.(CRSPdf[:dlret],0.0)
# Set missing returns to 0 (only <0.001% in monthly)
CRSPdf[:ret]=coalesce.(CRSPdf[:ret],0.0)
# Compute adjusted return including delisting
CRSPdf[:retadj]=(CRSPdf[:ret].+1).*(CRSPdf[:dlret].+1).-1

# calculate market equity, sort and remove useless columns
CRSPdf[:me]=abs.(CRSPdf[:prc]).*CRSPdf[:shrout]
delete!(CRSPdf, [:dlret,:dlstdt,:prc,:shrout])
sort!(CRSPdf, [:permco,:jdate,:me])


if CRSPdaterange!=["01/01/2000", "6/30/2018"]
    error("The dataframe split has been set for [\"01/01/2000\", \"6/30/2018\"] dates explicitly")
end

a1 = CRSPdf[1:999921,:]
a2 = CRSPdf[999922:end,:]
@time CRSPdf2 = mergepermnopermco!(a1)
@time CRSPdf2a = mergepermnopermco!(a2)
append!(CRSPdf2, CRSPdf2a)
sort!(CRSPdf2, [:permno,:jdate])

# keep December market cap
CRSPdf2[:year] = Dates.year.(CRSPdf2[:jdate])
CRSPdf2[:month] = Dates.month.(CRSPdf2[:jdate])
decme = CRSPdf2[(CRSPdf2[:month].==12),:][[:permno, :date, :jdate, :me, :year]]
rename!(decme, :me => :dec_me)


### July to June dates
CRSPdf2[:ffdate] = CRSPdf2[:jdate]-Dates.Month(6)
@time CRSPdf2[:ffdate] = map(x->ceil(x, Dates.Month)-Dates.Day(1), CRSPdf2[:ffdate])
CRSPdf2[:ffyear] = Dates.year.(CRSPdf2[:ffdate])
CRSPdf2[:ffmonth] = Dates.month.(CRSPdf2[:ffdate])

sort!(CRSPdf2, [:permno,:date])

# retx is the return ex dividends : use it for computations on me
# Create :cumretx over the Fama-French year, i.e. from -18 to -6 month ago
CRSPdf2 = groupcumret!(CRSPdf2, [:permno, :ffyear], :retx)
# Lag :cumretx (the cumulated return ex dividend in the previous period)
CRSPdf2 = grouplag!(CRSPdf2, :permno, :cumretx, 1)

# lag market cap
CRSPdf2 = grouplag!(CRSPdf2, :permno, :me, 1)
CRSPdf2[[:date, :me, :lagme_1]]

# if first permno then use me/(1+retx) to replace the missing value
CRSPdf2 = setfirstlme!(CRSPdf2, :permno, :lagme_1)

# baseline me
mebase = CRSPdf2[CRSPdf2[:ffmonth] .== 1, [:permno, :ffyear, :lagme_1]]
rename!(mebase, :lagme_1 => :mebase)

# merge result back together
CRSPdf3 = join(CRSPdf2, mebase, on = [:permno, :ffyear], kind = :left);

# Set the weight of the stock in the portfolio at month t using drifting base me (DataFramesMeta required)
@time CRSPdf3 = @byrow! CRSPdf3 begin
    @newcol wt::Array{Union{Float64,Missing}}
    if :ffmonth == 1
        :wt = :lagme_1
    else
        :wt = :mebase*:lagcumretx_1
    end
end;

# Join December and June info
decme[:year]=decme[:year].+1;
decme=decme[[:permno,:year,:dec_me]];
crsp3_jun =  CRSPdf3[CRSPdf3[:month] .== 6, :];
crsp3_jun = join(crsp3_jun, decme, on=[:permno, :year], kind=:inner);
crsp3_jun = crsp3_jun[[:permno, :date, :jdate, :shrcd, :exchcd, :retadj, :me,
                        :wt, :cumretx, :mebase, :lagme_1, :dec_me]];
sort!(crsp3_jun, [:permno, :jdate]);


##################################################################################################
#%% Download CCM data
##################################################################################################
@time begin
    print("Downloading linking CCM data...\n")
    # Download Compustat data from server
    ccm = linktabledownload()
    # if missing last link is in a year from now
    ccm[:linkenddt] = coalesce.(ccm[:linkenddt],Dates.Date(now())+Dates.Year(1));
    # if missing, first link is the earliest from the DB
    ccm[:linkdt] = coalesce.(ccm[:linkdt],minimum(ccm[:linkdt]));
    ccm[:gvkey] = parse.(Int, ccm[:gvkey]);
    print("Downloading linking CCM data has taken")
end

##################################################################################################
#%% Merge CRSP and CS using CCM
##################################################################################################

# Link Compustat to CCM
ccm1=join(CSdf,ccm,kind=:left,on=:gvkey);

ccm1[:yearend] = map(x->ceil(x, Dates.Year)-Dates.Day(1), ccm1[:datadate]);
ccm1[:jdate] = ccm1[:yearend].+Dates.Month(6);

# set link date bounds
linkinbounds = (ccm1[:jdate].<=ccm1[:linkenddt]) .& (ccm1[:jdate].>=ccm1[:linkdt]);
linkinbounds = Array{Bool}(replace(linkinbounds, missing=>false))
ccm1 = ccm1[linkinbounds, :]

# match gvkey with permID
matched = CSV.read("/home/nicolas/Data/permidmatch/matched.csv");
missingrows = ismissing.(matched[Symbol("Match OpenPermID")]);
deleterows!(matched, findall(missingrows));
endstring = x -> x[end-9:end]; #lambda fct to get end of string where permid is.
matched[:permid] = parse.(Int, endstring.(matched[Symbol("Match OpenPermID")]));
rename!(matched, :Input_LocalID => :gvkey);
matched = matched[[:gvkey, :permid]];
ccm1 = join(ccm1, matched, kind=:left, on=[:gvkey]);

# merge june CRSP with Compustat. This is to compute the breakpoints.
ccm_jun = join(crsp3_jun, ccm1, kind=:inner, on=[:permno, :jdate]);


#######################################################################################
#%% Breakpoints computation
#######################################################################################
print("Breakpoint computation")
# Compute book-to-market ratio
ccm_jun[:beme]=(ccm_jun[:be].*1000)./ccm_jun[:dec_me]

# select NYSE stocks for bucket breakdown
# exchcd = 1 and positive beme and positive me and shrcd in (10,11) and at least 2 years in comp
stocksfrobreakpoints = ( (ccm_jun[:exchcd].==1) .& (ccm_jun[:beme].>0)
                         .& (ccm_jun[:me].>0) .& (ccm_jun[:count].>1)
                         .& ((ccm_jun[:shrcd].==10).|(ccm_jun[:shrcd].==11)) );
stocksfrobreakpoints = Array{Bool}(replace(stocksfrobreakpoints, missing=>false));
nyse_breaks=ccm_jun[stocksfrobreakpoints, :];

nyse_breaks = by(nyse_breaks, :jdate) do df
  DataFrame(percentiles_me = tuple(percentile(Array{Float64}(df[:me]), collect(10:10:100))...),
            percentiles_bm = tuple(percentile(Array{Float64}(df[:beme]), collect(10:10:100))...))
end

ccm_jun = join(ccm_jun, nyse_breaks, kind=:left, on=:jdate)

@time foo = @byrow! ccm_jun begin
    @newcol ptf_2by3_size_value::Array{Union{String,Missing}}
    # @newcol ptf_5by5_size_value::Array{Union{Float64,Missing}}
    # @newcol ptf_10by10_size_value::Array{Union{Float64,Missing}}
    @newcol ranksize::Array{Union{Int,Missing}}
    @newcol rankbm::Array{Union{Int,Missing}}
    if !ismissing(:me)
        :ranksize = ranking(:me, :percentiles_me)
    end
    if !ismissing(:beme)
        :rankbm = ranking(:beme, :percentiles_bm)
    end
    if !ismissing(:rankbm) && !ismissing(:ranksize)
        :ptf_2by3_size_value = by2x3(:ranksize, :rankbm)
    end
end;




#######################################################
# Create Momentum Portfolio                           #
# Measures Based on Past (J) Month Compounded Returns #
#######################################################

J = 12*5 # Formation Period Length: J can be between 3 to 12 months
# K = 6 # Holding Period Length: K can be between 3 to 12 months
nbbreaks = 10
momdf = deepcopy(CRSPdf3)

# Calculate rolling cumulative return
# by summing log(1+ret) over the formation period
momdf[:logret] = log.(momdf[:retadj].+1)
@time rollretdf = by(momdf, :permno) do df
    if length(df[:logret])>=J
        DataFrame(rollret = [Array{Union{Missing, Float64}}(missing, J-1); rolling(sum, df[:logret], J)])
    else
        DataFrame(rollret = Array{Union{Missing, Float64}}(missing, length(df[:logret])))
    end
end;
momdf[:rollret] = rollretdf[:rollret];
momdf[:cumret] = exp.(momdf[:rollret]).-1;
@time umd = by(momdf, :date) do df
    if length(collect(skipmissing(df[:cumret])))>0
        missingidxs = ismissing.(df[:cumret]);
        momrank = CategoricalArrays.cutq(collect(skipmissing(df[:cumret])),
                    nbbreaks, labels=[string(i) for i in 1:nbbreaks])
        momrank = [parse(Int, i) for i in momrank]
        res = Array{Union{Missing, Int}}(undef,0)
        i=0
        for rowismissing in missingidxs
            if rowismissing
                push!(res, missing)
            else
                i+=1
                push!(res, momrank[i])
            end
        end
        DataFrame(momrank = res)
    else
        DataFrame(momrank = Array{Union{Missing, Int}}(missing, length(df[:cumret])))
    end
end
momdf[:momrank] = umd[:momrank];


# Load S&P500 return
SP500m = CSV.read("/home/nicolas/Data/Inputs/monthlySP500.csv");
SP500m[:caldt] = Dates.Date.(map(x->replace(x, "/"=>"-"), SP500m[:caldt]));
SP500d = CSV.read("/home/nicolas/Data/Inputs/dailySP500.csv");
SP500d[:caldt] = Dates.Date.(map(x->replace(x, "/"=>"-"), SP500d[:caldt]));
