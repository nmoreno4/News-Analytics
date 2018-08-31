using DataFrames, CSV, ShiftedArrays, Statistics, DataFramesMeta
include("CRSP_CS/customfcts.jl")

##################################################################################################
#%% Data for ratios
##################################################################################################
CSdaterange = ["01/01/1999", "12/31/2017"]
ratiovariables = "gvkey, datadate, fyr,  SEQ, ceq, TXDITC, TXDB, ITCB, PSTKRV, PSTKL, PSTK,
                prcc_f, prcc_f, csho, epsfx, epsfi, oprepsx, opeps, ajex, ebit,
                spi, nopi, sale, ibadj, dvc, dvp, ib, oibdp, dp, oiadp,
                gp, revt, cogs, pi, ibc, dpc, at, ni, ibcom, icapt,
                mib, ebitda, xsga, xido, xint, mii, ppent, act, lct,
                dltt, dlc, che, invt, lt, rect, xopr, oancf, txp,
                txt, ap, xrd, xad, xlr, capx, re"
vars_ytd=["sale", "dp", "capx", "cogs", "xido", "xint", "xopr", "ni", "pi", "oibdp",
        "oiadp", "opeps", "oepsx", "epsfi", "epsfx", "ibadj", "ibcom", "mii", "ibc",
        "dpc", "xrd", "txt", "spi", "nopi"]
@time begin
    print("Downloading annual CS\n")
    # Download Compustat data from server
    annualratios = CSdownload(CSdaterange, ratiovariables, "compa.aco_indsta")
    # sort!(CSdf, [:gvkey,:datadate])
    # CSdf[:gvkey] = parse.(Int, CSdf[:gvkey]);
    print("Downloading annual CS has taken")
end

annualratios[[:datadate, :seq, :txditc, :gvkey]]
annualratios[:pstk_new]=coalesce.(annualratios[:pstkrv],annualratios[:pstkl],annualratios[:pstk])
@time prov = by(annualratios, :gvkey) do df
    lfyear = lag(df[:fyr])
    actDiff, cheDiff, lctDiff, dlcDiff, txpDiff = firstdiff(df[:act]), firstdiff(df[:che]), firstdiff(df[:lct]), firstdiff(df[:dlc]), firstdiff(df[:txp])
    dlttDiff, ceqDiff = firstdiff(df[:dltt]), firstdiff(df[:ceq])
    DataFrame(lagfyear = lfyear, gap = df[:fyr].-lfyear, actD = actDiff, cheD = cheDiff,
                lctD = lctDiff, dlcD = dlcDiff, txpD = txpDiff, lag_at1 = lag(df[:at]),
                dlttD = dlttDiff, ceqD = ceqDiff)
end
annualratios[:lagfyear]=prov[:lagfyear]
annualratios[:gap]=prov[:gap]
annualratios[:actD]=prov[:actD]
annualratios[:cheD]=prov[:cheD]
annualratios[:lctD]=prov[:lctD]
annualratios[:dlcD]=prov[:dlcD]
annualratios[:txpD]=prov[:txpD]
annualratios[:lag_at1]=prov[:lag_at1]
annualratios[:dlttD]=prov[:dlttD]
annualratios[:ceqD]=prov[:ceqD]
@time annualratios = @byrow! annualratios begin
    @newcol be::Array{Union{Float64,Missing}} #book equity
    @newcol bm::Array{Union{Float64,Missing}} #book-to-market
    if !ismissing(:seq) && :seq > 0
        :be = :seq + coalesce(:txditc, (:txdb + :itcb),0) - coalesce(:pstk_new,0)
        :be = :be<=0 ? missing : :be #keep only positive be
    end
    if !ismissing(:prcc_f*:csho) && :prcc_f*:csho > 0
        :bm = :be/(:prcc_f*:csho);
    end
end;
@time prov = by(annualratios, :gvkey) do df
    DataFrame(lag_be1 = lag(df[:be]), lag_bm1 = lag(df[:bm]))
end
annualratios[:lag_be1]=prov[:lag_be1]
annualratios[:lag_bm1]=prov[:lag_bm1]

@time annualratios = @byrow! annualratios begin
    @newcol icapt::Array{Union{Float64,Missing}} #invested capital
    @newcol ocf::Array{Union{Float64,Missing}} #operating CF
    @newcol capei::Array{Union{Float64,Missing}} #Shillers Cyclically Adjusted P/E Ratio
    @newcol evm::Array{Union{Float64,Missing}} #entreprise value multiple
    @newcol pe_op_basic::Array{Union{Float64,Missing}} #price-to-operating EPS, excl. EI (basic)
    @newcol pe_op_dil::Array{Union{Float64,Missing}} #price-to-operating EPS, excl. EI (diluted)
    @newcol pe_exi::Array{Union{Float64,Missing}} #price-to-earnings, excl. EI (diluted)
    @newcol pe_inc::Array{Union{Float64,Missing}} #price-to-earnings, incl. EI (diluted)
    @newcol ps::Array{Union{Float64,Missing}} #price-to-sales ratio
    @newcol pcf::Array{Union{Float64,Missing}} #price-to-cash flow
    @newcol dpr::Array{Union{Float64,Missing}} #dividend payout ratio
    @newcol npm::Array{Union{Float64,Missing}} #net profit margin
    @newcol opmbd::Array{Union{Float64,Missing}} #operating profit margin before depreciation
    @newcol opmad::Array{Union{Float64,Missing}} #operating profit margin after depreciation
    @newcol gpm::Array{Union{Float64,Missing}} #gross profit margin
    @newcol ptpm::Array{Union{Float64,Missing}} #pretax profit margin
    @newcol cfm::Array{Union{Float64,Missing}} #cash flow margin
    @newcol roa::Array{Union{Float64,Missing}} #Return on Assets
    @newcol roe::Array{Union{Float64,Missing}} #Return on Equity
    @newcol roce::Array{Union{Float64,Missing}} #Return on Capital Employed
    #...
    @newcol leverage::Array{Union{Float64,Missing}} #As defined in Vuolteenhao (2002)
    @newcol tobinQ::Array{Union{Float64,Missing}} #
    @newcol altmanZ::Array{Union{Float64,Missing}} #
    #...
    :icapt=coalesce(:icapt,+(:dltt,:pstk,:mib,:ceq))
    :ocf=coalesce(:oancf,:ib - :actD + :cheD + :lctD - :dlcD - :txpD + :dp)
    :capei = :ib
    :evm=+(coalesce(:dltt,0), coalesce(:dlc,0), coalesce(:mib,0), coalesce(:pstk_new,0),
            coalesce(:prcc_f*:csho,0))/coalesce(:ebitda,:oibdp,:sale-:cogs-:xsga)
    :pe_op_basic=:opeps/:ajex
    :pe_op_dil=:oprepsx/:ajex
    :pe_exi=:epsfx/:ajex
    :pe_inc=:epsfi/:ajex
    :ps=:sale
    :pcf=:ocf
    if !ismissing(:ibadj) && :ibadj > 0
        :dpr=:dvc/:ibadj
    end
    :npm=:ib/:sale
    :opmbd=coalesce(:oibdp,:sale-:xopr,:revt-:xopr)/:sale
    :opmad=coalesce(:oiadp,:oibdp-:dp,:sale-:xopr-:dp,:revt-:xopr-:dp)/:sale
    :gpm=coalesce(:gp,:revt-:cogs,:sale-:cogs)/:sale
    :ptpm=coalesce(:pi,:oiadp-:xint+:spi+:nopi)/:sale
    :cfm=coalesce(:ibc+:dpc,:ib+:dp)/:sale
    :roa=coalesce(:oibdp,:sale-:xopr,:revt-:xopr)/((:at+:lag_at1)/2)
    if !ismissing((:be+:lag_be1)/2) && ((:be+:lag_be1)/2)>0
        :roe=:ib/((:be+:lag_be1)/2)
    end
    :roce=coalesce(:ebit,:sale-:cogs-:xsga-:dp)/((:dltt+:dlttD+:dlc+:dlcD+:ceq+:ceqD)/2)
    # I stopped at efftax
    #...
    :leverage = :be/(:be+:dltt+:dlc)
    :tobinQ = (:at + :prcc_c*:csho - :be) / :at
    if !ismissing(:at) && !ismissing(:lt) && (:lt>0 && :at>0)
        :altmanZ=3.3*(:ebit/:at) +0.99*(:sale/:at) +0.6*(:prcc_f*:csho/:lt) +1.2*(coalesce(:act,0)/:at) + 1.4*(coalesce(:re,0)/:at)
    end
    #...
end;
