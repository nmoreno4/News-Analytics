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
for crtvar in names(Data)[2:end]
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
        png(trendplot, "/home/nicolas/Data/Results/Trend and Cyclicality filtering/$(crtvar)_trend.png")
        
        hp_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:hp])).power
        trend_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:x_trend])).power
        x_dens = Periodograms.periodogram(convert(Array{Float64}, crtfilt[:x])).power
        spectralpower = plot([hp_dens[1:48], trend_dens[1:48], x_dens[1:48]], labels=["HP-filter", "trend", "raw"],
                color=[i for j = 1:1, i=[:red, :blue, :black]], title="Periodogram: $crtvar")
        png(spectralpower, "/home/nicolas/Data/Results/Trend and Cyclicality filtering/$(crtvar)_spectralpower.png")
    catch x
        error(x)
    end
end



















# crtNS = deleteMissingRows(NS["$freq"], Symbol("HML_$(topic)_VW_$freq"))
# plot(crtNS[:perID], [crtNS[Symbol("Gro_$(topic1)_VW_$freq")],crtNS[Symbol("Gro_$(topic2)_VW_$freq")],
#                      crtNS[Symbol("ALL_$(topic1)_VW_$freq")], crtNS[Symbol("ALL_$(topic2)_VW_$freq")],
#                      crtNS[Symbol("HML_$(topic1)_VW_$freq")], crtNS[Symbol("HML_$(topic2)_VW_$freq")]],
#     layout=(3,2), title = ["$i" for j = 1:1, i=["$(topic1): Value (R) / Growth (B)","$(topic2): Value (R) / Growth (B)", "$(topic1): Market","$(topic2): Market", "$(topic1): HML", "$(topic2): HML"]],
#     legend=false, legendtitle=["$i" for j = 1:1, i=["Gro", "Gro"]], titlefontsize=8, framestyle=:grid, tickfontsize=6)
# plot!(crtNS[:perID], [crtNS[Symbol("Val_$(topic1)_VW_$freq")], crtNS[Symbol("Val_$(topic2)_VW_$freq")]], legend=false)
# plot(crtNS[:perID], crtNS[Symbol("ALL_$(topic)_VW_$freq")])
# join(Data, NS["month"], on=:perID, kind=:left)
