using CSV, JLD2, TrendCycle, FindFcts, Plots, DataFrames, Dates, DSP, Statistics

@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_TS.jld2"
@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/Nsurp_TS.jld2"
Data = CSV.read("/home/nicolas/Data/TS/Macro/Granger.csv")
Data = Data[Dates.Date(2018,1,1).>Data[:,:DATE].>=Dates.Date(2003,1,1),:]
Data[:perID] = ceil.(Data[:DATE] .+ Day(1), Month) .- Day(1)

#Create TS by frequency
NS = Dict()
for freq in ["day", "week", "month", "quarter"]
    NS[freq] = NS_TS["ALL_all_VW_$(freq)"][:,[:perID]]
    for topic in ["all", "RES", "RESF"]
        for WS in ["EW", "VW"]
            NS[freq][Symbol("Val_$(topic)_$(WS)_$freq")] = (NS_TS["SV_$(topic)_$(WS)_$freq"][:NS] .+ NS_TS["BV_$(topic)_$(WS)_$freq"][:NS]) ./ 2
            NS[freq][Symbol("Gro_$(topic)_$(WS)_$freq")] =  (NS_TS["SG_$(topic)_$(WS)_$freq"][:NS] .+ NS_TS["BG_$(topic)_$(WS)_$freq"][:NS]) ./ 2
            NS[freq][Symbol("HML_$(topic)_$(WS)_$freq")] = NS[freq][Symbol("Val_$(topic)_$(WS)_$freq")] .- NS[freq][Symbol("Gro_$(topic)_$(WS)_$freq")]
            for ptf in ["SV", "BV", "SG", "BG", "ALL"]
                NS[freq][Symbol("$(ptf)_$(topic)_$(WS)_$freq")] = NS_TS["$(ptf)_$(topic)_$(WS)_$freq"][:NS]
            end
        end
    end
end

Nsurp = Dict("df" => NS["day"][[Symbol("perID")]])
names!(Nsurp["df"], [:date])
for spec in 1:4
    val = DataFrame(Dict(:date=>Nsurp_TS["SV_$(spec)_VW"][:date], Symbol("Surp_Val_$(spec)")=>(Nsurp_TS["SV_$(spec)_VW"][:,2] .+ Nsurp_TS["SV_$(spec)_VW"][:,2]) ./ 2))
    gro = DataFrame(Dict(:date=>Nsurp_TS["SG_$(spec)_VW"][:date],  Symbol("Surp_Gro_$(spec)")=>(Nsurp_TS["SG_$(spec)_VW"][:,2] .+ Nsurp_TS["SG_$(spec)_VW"][:,2]) ./ 2))
    Nsurp["df"] = join(Nsurp["df"], val, kind=:left, on=:date)
    Nsurp["df"] = join(Nsurp["df"], gro, kind=:left, on=:date)
    Nsurp["df"][Symbol("Surp_HML_$(spec)")] = Nsurp["df"][Symbol("Surp_Val_$(spec)")] .- Nsurp["df"][Symbol("Surp_Gro_$(spec)")]
    for ptf in ["SV", "BV", "SG", "BG", "ALL"]
        names!(Nsurp_TS["$(ptf)_$(spec)_VW"], [:date, Symbol("Nsurp_$(ptf)_$(spec)_VW")])
        Nsurp["df"] = join(Nsurp["df"], Nsurp_TS["$(ptf)_$(spec)_VW"], kind=:left, on=:date)
    end
end
#Aggregate monthly/weekly/quarterly
Nsurp = Nsurp["df"]

monthlyNsurp = Dict()
for varia in names(Nsurp)[2:end]
    crtDF = Nsurp[[:date, varia]]
    crtDF[:ymonth] = Dates.yearmonth.(Nsurp[:date])
    result = by(crtDF, :ymonth) do xdf
        res = Dict()
        if length(collect(skipmissing(xdf[varia])))>0
            res[:x1] = mean(skipmissing(xdf[varia]))
        else
            res[:x1] = missing
        end
    end
    monthlyNsurp[varia] = result[:x1]
end
monthlyNsurp = DataFrame(monthlyNsurp)

Data = hcat(Data, monthlyNsurp, NS["month"], makeunique=true)



# crtNS = deleteMissingRows(Data, Symbol("HML_$(topic)_VW_month"), :Surp_HML_1)
# plot(crtNS[:DATE], [crtNS[Symbol("HML_$(topic)_VW_month")], crtNS[:Surp_HML_1]])
# plot(crtNS[:DATE], crtNS[:Surp_HML_1])
#
# crtNS = deleteMissingRows(Data, Symbol("HML_$(topic)_VW_month"), Symbol("HML_$(topic)_VW_$freq"))


λ = 14400
H = [4,6,12,24,36,48,60]
P = [2,3,4,6,12,24,36]
function appendData()
    newData = deepcopy(Data)
    for crtvar in names(Data)[2:end]
        print(typeof(Data))
        try
            crtNS = deleteMissingRows(Data, Symbol(crtvar))
            crtfilt, reg = neverHPfilter(crtNS, 24, 12; dateCol=:DATE, varCol=Symbol(crtvar))
            AICopt = Dict()
            for h in H
                for p in P
                    if h>=1.6*p
                        temp, reg = neverHPfilter(crtNS, h, p; dateCol=:DATE, varCol=Symbol(crtvar))
                        AICopt[(h,p)] = reg[:aic]
                    end
                end
            end
            h, p = findmin(AICopt)[2]
            ofilt, oreg = neverHPfilter(crtNS, h, p; dateCol=:DATE, varCol=Symbol(crtvar))
            names!(ofilt, [Symbol("optim_$x") for x in names(ofilt)])
            crtfilt = hcat(crtfilt, ofilt)
            crtfilt[:x] = replace(crtfilt[:x], 0=>missing)
            crtfilt = deleteMissingRows(crtfilt, :x_trend, :x)
            crtfilt[:optim_x_trend] = replace(crtfilt[:optim_x_trend], missing=>NaN)
            crtfilt[:hp] = HPfilter(convert(Array{Float64}, crtfilt[:x]), λ)
            trendplot = plot(crtfilt[:date], [crtfilt[:hp], crtfilt[:x_trend], crtfilt[:x], crtfilt[:optim_x_trend]],
                              labels=["HP-filter", "trend", "raw", "optim_trend - AIC selection: h=$h, p=$p"], color=[i for j = 1:1, i=[:red, :blue, :black, :lime]],
                              linewidth=[i for j = 1:1, i=[2,3,1,3]], title="Hamilton trend: $crtvar",
                              xticks = crtfilt[:date][1]:Year(1):crtfilt[:date][end],rotation=30,
                              legend=:top, legendfontsize=7)

            names!(crtfilt, [[:DATE];[Symbol("$(crtvar)_$x") for x in names(crtfilt)[2:end]]])
            newData = join(newData, crtfilt, on=:DATE, kind=:left)

            png(trendplot, "/home/nicolas/Data/Results/Trend and Cyclicality filtering/$(crtvar)_trend.png")
            # hp_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:hp])).power
            # trend_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:x_trend])).power
            # x_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:x])).power
            # spectralpower = plot([hp_dens[1:48], trend_dens[1:48], x_dens[1:48]], labels=["HP-filter", "trend", "raw"],
            #         color=[i for j = 1:1, i=[:red, :blue, :black]], title="Periodogram: $crtvar")
            # png(spectralpower, "/home/nicolas/Data/Results/Trend and Cyclicality filtering/$(crtvar)_spectralpower.png")
        catch x
            print(x)
        end
    end
    return newData
end


newData = appendData()





































































using JLD2, Causality, CSV, DataFrames, Dates, Plots, HypothesisTests, FindFcts, TrendCycle

@time JLD2.@load "/home/nicolas/Data/Prcessed Data MongoDB/NS_TS.jld2"
Data = CSV.read("/home/nicolas/Data/TS/Macro/Granger.csv")
Data = Data[Dates.Date(2018,1,1).>Data[:,:DATE].>=Dates.Date(2003,1,1),:]
Data[:DATE] = ceil.(Data[:DATE] .+ Day(1), Month) .- Day(1)

#Add monthly NS to Macro dataframe
for ptf in ["SV", "BV", "SG", "SV", "ALL"]
    for topic in ["all", "RES", "RESF"]
        for WS in ["EW", "VW"]
            Data[Symbol("$(ptf)_$(topic)_$(WS)_month")] = NS_TS["$(ptf)_$(topic)_$(WS)_month"][:NS]
        end
    end
end

plot(X)
ADFTest(collect(skipmissing(NS_TS["ALL_RESF_VW_quarter"][:NS])), :none, 1)
ApproximateOneSampleKSTest(collect(skipmissing(NS_TS["ALL_all_VW_day"][:NS])), Distributions.Gaussian())

for i in names(Data)
    print("$i \n")
end

G_Index
G_D12
G_E12
G_b/m
G_tbl
G_AAA
G_BAA
G_lty
G_ntis
G_Rfree
G_infl
G_ltr
G_corpr
G_svar
G_csp
G_CRSP_SPvw
G_CRSP_SPvwx

x = Symbol("G_E12")
y = :ALL_RES_VW_month
res = grangerVARCaus(Data, x, y)
res[:x1_VAR_coeffs]
plot(Data[:G_ntis])
x = :G_AAA
h = 12; p = 4
filt, reg = neverHPfilter(Data[[:DATE, x]], h, p, :DATE, x)
filt = deleteMissingRows(filt, :x_trend, :x_cycle, :x_random)
display(plot(filt[:date], [filt[:x_trend], filt[:x_cycle]]))
display(plot(Data[:DATE], Data[x]))
reg[:aic]


using DSP
X =  HPfilter(collect(skipmissing(NS_TS["SG_RES_VW_week"][:NS])), 250)
plot(X)
plot(Periodograms.periodogram(X).power[1:100])
plot(Periodograms.periodogram(collect(skipmissing(Data[x]))).power[1:10])
plot(collect(skipmissing(NS_TS["SV_RES_VW_week"][:NS])))

large_Cyc_change = 5 #%
large_Trend_change = 1/8 #%
λ = (large_Cyc_change/large_Trend_change)^2
SmS = HPfilter(collect(skipmissing(Data[x])), λ)
plot(SmS)

R"grangertest(d.x2 ~ d.x1, order = 3)"
R"grangertest(d.x1 ~ d.x2, order = 12)"
plot(X)
