using TRMIdata, Plots, Dates, CSV

@time df = load_market_TRMI()

for i in names(df)
    print("$i \n")
end

reutersDate(x) = DateTime(x, "yyyy-mm-ddTHH:MM:SS.sssZ")
df[:windowTimestamp] = reutersDate.(df[:windowTimestamp])
social = df[df[:dataType].=="Social", :]
news = df[df[:dataType].=="News", :]
news_social = df[df[:dataType].=="News_Social", :]

crtvar = :stockIndexSentiment
# a = rollingAggregTRMI(news, Day(5), Month(6), crtvar)
# plot(a[:date][20:end], a[crtvar][20:end], xticks = Date(1998,1,1):Year(2): Date(2018,1,1), rotation=30)
b = aggregTRMI(news_social, Month(1), crtvar)
# plot(b[:date], b[crtvar], xticks = Date(1998,1,1):Year(1): Date(2018,1,1), rotation=30)

freq = [Month(1), Month(3)]
vars = [:stockIndexSentiment, :stockIndexOptimism, :stockIndexTrust, :stockIndexFear, :stockIndexStress,
        :stockIndexSurprise, :stockIndexUncertainty, :stockIndexMarketRisk, :stockIndexPriceDirection,
        :stockIndexPriceForecast, :stockIndexVolatility]
a = multipleTRMIvars(news, freq, vars, multipleTRMIvars)
CSV.write("/home/nicolas/Documents/CF DR paper/news_$(freq).csv", a)


# plot(res)
# ceil(minimum(social[:windowTimestamp]), Month):Month(1):ceil(maximum(social[:windowTimestamp]), Month)
# countmissing(x) = length(x)-length(collect(skipmissing(x)))
# countmissing(a[:stockIndexBuzz])
