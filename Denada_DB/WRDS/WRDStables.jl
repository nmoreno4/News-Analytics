include("WRDSdownload.jl")

"""
    dl_yearly_CS(CSdaterange, CSvariables, CSdatatable [, sectorpath])

Download Compustat variables *CSvariables* from WRDS coming from table *CSdatatable*
between *CSdaterange*.
"""
function dl_CS(CSdaterange, CSvariables, CSdatatable, sectorpath="/home/nicolas/Data/Inputs/sectors.csv")
    # Download Compustat data from server
    CSdf = CSdownload(CSdaterange, CSvariables, CSdatatable)
    sort!(CSdf, [:gvkey,:datadate])
    CSdf[:gvkey] = parse.(Int, CSdf[:gvkey]);
    sectors = CSV.read(sectorpath);
    sectors[:datadate] = Dates.Date.(map(x->replace(x, "/"=>"-"), sectors[:datadate]));
    a = join(CSdf, sectors, on=[:gvkey, :datadate, :cusip], kind=:left);
    @time b = by(a, [:gvkey, :datadate]) do df
        DataFrame(indfmt = df[:indfmt][1])
    end
    return join(b, a, on=[:gvkey, :datadate, :indfmt], kind=:inner)
end



"""
    CS_age!(CSdf)

By grouping *CSdf* by *gvkey* adds a column counting for how many years the gvkey had
observations in Compustat.\\
Adds a column for the year.
"""
function CS_age!(CSdf)
    # Add a column with the year of the observation
    CSdf[:year] = Dates.year.(CSdf[:datadate])
    # number of years in Compustat. Only works with annual data!!
    prov = by(CSdf, :gvkey) do df
        DataFrame(count = cumcount(df[:year]), datadate = df[:datadate])
    end
    return join(CSdf, prov, on=[:gvkey, :datadate], kind=:inner)
end


"""
    compute_be!(CSdf)

Computes Book-equity.\\
Uses computed "clean" preferred shares
"""
function compute_be!(CSdf)
    CSdf[Symbol("ps")] = coalesce.(CSdf[Symbol("pstkrv")],CSdf[Symbol("pstkl")],CSdf[Symbol("pstk")],0.0)
    CSdf[Symbol("txditc")] = coalesce.(CSdf[Symbol("txditc")],0.0)

    # Compute be and replace non-positive values by missing
    CSdf[Symbol("be")]=CSdf[Symbol("seq")]+CSdf[Symbol("txditc")]-CSdf[Symbol("ps")]
    CSdf[:be]=val2missing.(CSdf[:be],0)
    return CSdf
end

"""
    delistAdjust!(CRSPdf)

"""
function delistAdjust!(CRSPdf, freq="m")
    # Download delisting return table (monthly freq)
    delistdf = delistdownload(freq)
    delistdf[:permno] = Array{Int}(delistdf[:permno])
    delistdf = lineupDate!(delistdf, Dates.Month, :jdate, :dlstdt)
    CRSPdf = join(CRSPdf, delistdf, on = [:permno, :jdate], kind = :left)
    CRSPdf[:dlret]=coalesce.(CRSPdf[:dlret],0.0)
    # Set missing returns to 0 (only <0.001% in monthly)
    CRSPdf[:ret]=coalesce.(CRSPdf[:ret],0.0)
    # Compute adjusted return including delisting
    CRSPdf[:retadj]=(CRSPdf[:ret].+1).*(CRSPdf[:dlret].+1).-1
    return CRSPdf
end


function decME(CRSPdf)
    CRSPdf[:year] = Dates.year.(CRSPdf[:jdate])
    CRSPdf[:month] = Dates.month.(CRSPdf[:jdate])
    decme = CRSPdf[(CRSPdf[:month].==12),:][[:permno, :date, :jdate, :me, :year]]
    rename!(decme, :me => :dec_me)
    return decme
end


function julyJuneDates!(CRSPdf)
    ### July to June dates
    CRSPdf[:ffdate] = CRSPdf[:jdate]-Dates.Month(6)
    CRSPdf[:ffdate] = map(x->ceil(x, Dates.Month)-Dates.Day(1), CRSPdf[:ffdate]) #adjust to end of month
    CRSPdf[:ffyear] = Dates.year.(CRSPdf[:ffdate])
    CRSPdf[:ffmonth] = Dates.month.(CRSPdf[:ffdate])
    return CRSPdf
end

function driftweights!(CRSPdf, sortvars)
    # retx is the return ex dividends : use it for computations on me
    # Create :cumretx over the Fama-French year, i.e. from -18 to -6 month ago
    CRSPdf = groupcumret!(CRSPdf, [:permno, :ffyear], :retx, sortvars)
    # Lag :cumretx (the cumulated return ex dividend in the previous period)
    CRSPdf = grouplag!(CRSPdf, [:permno, :ffyear], :cumretx, 1, sortvars)
    CRSPdf[ismissing.(CRSPdf[:lagcumretx_1]), :lagcumretx_1] = 1

    # lag market cap
    CRSPdf = grouplag!(CRSPdf, [:permno, :ffyear], :me, 1, sortvars)
    CRSPdf[[:date, :me, :lagme_1]]

    # if first permno then use me/(1+retx) to replace the missing value
    CRSPdf = setfirstlme!(CRSPdf, [:permno, :ffyear], :lagme_1, sortvars)

    # baseline me
    mebase = CRSPdf[CRSPdf[:ffmonth] .== 1, [:permno, :ffyear, :lagme_1]]
    rename!(mebase, :lagme_1 => :mebase)

    # merge result back together
    CRSPdf = join(CRSPdf, mebase, on = [:permno, :ffyear], kind = :left);

    # Set the weight of the stock in the portfolio at month t using drifting base me (DataFramesMeta required)
    @time CRSPdf = @byrow! CRSPdf begin
        @newcol wt::Array{Union{Float64,Missing}}
        if :ffmonth == 1
            :wt = :lagme_1
        else
            :wt = :mebase*:lagcumretx_1
        end
    end;
    return CRSPdf
end


function juneDecMerge(CRSPdf, decme)
    decme[:year]=decme[:year].+1;
    decme=decme[[:permno,:year,:dec_me]];
    CRSPdf_jun =  CRSPdf[CRSPdf[:month] .== 6, :];
    CRSPdf_jun_me = join(CRSPdf_jun, decme, on=[:permno, :year], kind=:inner);
    return CRSPdf_jun_me
end


function ccmDownload()
    ccm = linktabledownload()
    # if missing last link is in a year from now
    ccm[:linkenddt] = coalesce.(ccm[:linkenddt],Dates.Date(now())+Dates.Year(1));
    # if missing, first link is the earliest from the DB
    ccm[:linkdt] = coalesce.(ccm[:linkdt],minimum(ccm[:linkdt]));
    ccm[:gvkey] = parse.(Int, ccm[:gvkey]);
    return ccm
end


function gvkeyMatchPermID!(CS_ccm, permidmatchpath="/home/nicolas/Data/permidmatch/matched.csv")
    matched = CSV.read(permidmatchpath);
    missingrows = ismissing.(matched[Symbol("Match OpenPermID")]);
    deleterows!(matched, findall(missingrows));
    endstring = x -> x[end-9:end]; #lambda fct to get end of string where permid is.
    matched[:permid] = parse.(Int, endstring.(matched[Symbol("Match OpenPermID")]));
    rename!(matched, :Input_LocalID => :gvkey);
    matched = matched[[:gvkey, :permid]];
    CS_ccm = join(CS_ccm, matched, kind=:left, on=[:gvkey]);
    return CS_ccm
end



function bmClassficiation(june_merge)
    # Compute book-to-market ratio
    june_merge[:beme]=(june_merge[:be].*1000)./june_merge[:dec_me]

    # select NYSE stocks for bucket breakdown
    # exchcd = 1 and positive beme and positive me and shrcd in (10,11) and at least 2 years in comp
    stocksfrobreakpoints = ( (june_merge[:exchcd].==1) .& (june_merge[:beme].>0)
                             .& (june_merge[:me].>0) .& (june_merge[:count].>1)
                             .& ((june_merge[:shrcd].==10).|(june_merge[:shrcd].==11)) );
    stocksfrobreakpoints = Array{Bool}(replace(stocksfrobreakpoints, missing=>false));
    nyse_breaks=june_merge[stocksfrobreakpoints, :];

    nyse_breaks = by(nyse_breaks, :jdate) do df
      DataFrame(percentiles_me = tuple(percentile(Array{Float64}(df[:me]), collect(10:10:100))...),
                percentiles_bm = tuple(percentile(Array{Float64}(df[:beme]), collect(10:10:100))...))
    end

    june_merge = join(june_merge, nyse_breaks, kind=:left, on=:jdate)

    bmranks = @byrow! june_merge begin
        @newcol ptf_2by3_size_value::Array{Union{Missing,String}}
        # @newcol ptf_5by5_size_value::Array{Union{Float64,Missing}}
        # :ptf_5by5_size_value = missing
        # @newcol ptf_10by10_size_value::Array{Union{Float64,Missing}}
        # :ptf_10by10_size_value = missing
        @newcol ranksize::Array{Union{Int,Missing}}
        @newcol rankbm::Array{Union{Int,Missing}}
        if !ismissing(:me)
            :ranksize = ranking(:me, :percentiles_me)
        end
        if !ismissing(:beme)
            :rankbm = ranking(:beme, :percentiles_bm)
        end
        :ptf_2by3_size_value = missing
        if !ismissing(:rankbm) && !ismissing(:ranksize)
            :ptf_2by3_size_value = by2x3(:ranksize, :rankbm)
        end
        if :permno==10667 && :ffyear==2002
            print(:rankbm)
        end
    end;
    return bmranks[[:permno, :date, :jdate, :beme, :percentiles_me, :percentiles_bm,
                    :ptf_2by3_size_value, :ranksize, :rankbm, :ffyear]]
end



function momentumClassification(CRSPdf, J=12, nbbreaks=10)
    # Calculate rolling cumulative return
    # by summing log(1+ret) over the formation period
    CRSPdf[:logret] = log.(CRSPdf[:retadj].+1)
    print(countmissing(CRSPdf[:logret]))
    @time rollretdf = by(CRSPdf, :permno) do df
        if length(df[:logret])>=J
            DataFrame(rollret = [Array{Union{Missing, Float64}}(missing, J-1); rolling(sum, df[:logret], J)])
        else
            DataFrame(rollret = Array{Union{Missing, Float64}}(missing, length(df[:logret])))
        end
    end;
    CRSPdf[:rollret] = rollretdf[:rollret];
    CRSPdf[:cumret] = exp.(CRSPdf[:rollret]).-1;
    @time umd = by(CRSPdf, :date) do df
        if length(collect(skipmissing(df[:cumret])))>0
            missingidxs = ismissing.(df[:cumret]);
            momrank = CategoricalArrays.cut(collect(skipmissing(df[:cumret])),
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
    return umd
end
