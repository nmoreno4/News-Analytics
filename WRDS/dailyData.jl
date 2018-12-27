using WRDSdownload, DataFrames, Dates, StatsBase, TimeZones


CRSPdaterange = ["01/01/2003", "12/31/2017"]

############## CRSP Variable description ##############
# ret:
# retx:
# shrout:
# prc: Prc is the closing price or the negative bid/ask average for a trading day.
#      If the closing price is not available on any given trading day, the number in
#      the price field has a negative sign to indicate that it is a bid/ask average
#      and not an actual closing price. Please note that in this field the negative sign
#      is a symbol and that the value of the bid/ask average is not negative.
#      If neither closing price nor bid/ask average is available on a date,
#      prc is set to zero.
# vol: In monthly files, VOL is the sum of the trading volumes during that month.
#      In daily files, VOL is the total number of shares of a stock sold on day I.
#      It is expressed in units of one share, for daily data, and on hundred shares
#      for monthly data. Our data source for NYSE/AMEX reports the number rounded to
#      the nearest hundred. For example, 12,345 shares traded will be reported on the
#      Nasdaq Stock Exchange as 12,345 and on the NYSE or AMEX exchanges as 12,300.
#      Volume is set to -99 if the value is missing. A volume of zero usually indicates
#      that there were no trades during the time period and is usually paired with
#      bid/ask quotes in price fields.
# spread:
########################################################

print("Downloading daily data!...")
CRSPvariables = "a.permno, a.date,a.ret, a.vol, a.prc"
CRSPdatatable = ["crsp.dsf", "crsp.dsenames"]
CRSPdf = @time CRSPdownload(CRSPdaterange, CRSPvariables, CRSPdatatable)
print("Data downloaded!")
delistdf = delistdownload("d")
names!(delistdf, [:permno, :dlret, :date])
CRSPdf = @time join(CRSPdf, delistdf, on = [:date, :permno], kind = :left)

CRSPdf[ismissing.(CRSPdf[:dlret]), :dlret] = 0
# Set missing returns to 0 (only <0.001% in monthly)
CRSPdf[ismissing.(CRSPdf[:ret]), :ret] = 0
# Compute adjusted return including delisting
CRSPdf[:retadj]=(1 .+ CRSPdf[:ret]) .* (1 .+ CRSPdf[:dlret]) .- 1

# Compute trading volume as number of shares sold * share price
CRSPdf[:prc] = abs.(CRSPdf[:prc])
CRSPdf[:volume]=CRSPdf[:vol] .* CRSPdf[:prc]

CRSPdf[:retadj][i] = windsorize(CRSPdf[:retadj], 99.9, 0.01)

# Compute date-frequency identifiers
ys = Dates.year.(CRSPdf[:date])
qy = []
for (q, y) in zip(Dates.quarterofyear.(CRSPdf[:date]),  Dates.year.(CRSPdf[:date]))
    push!(qy, y*10+q)
end
wmy = []
for (y,m,w) in zip(Dates.year.(CRSPdf[:date]) ,Dates.month.(CRSPdf[:date]), Dates.week.(CRSPdf[:date]))
    push!(wmy, y*10000+m*100+w)
end
ymonth = []
for (y,m) in zip(Dates.year.(CRSPdf[:date]) ,Dates.month.(CRSPdf[:date]))
    push!(ymonth, y*100+m)
end

CRSPdf[:ys] = ys
CRSPdf[:qy] = qy
CRSPdf[:ymonth] = ymonth
CRSPdf[:wmy] = wmy
CRSPdf[:date] = convert(Array{DateTime}, CRSPdf[:date])
dates = [ZonedDateTime(d, tz"America/New_York") for d in CRSPdf[:date] .+ Dates.Hour(16)]
CRSPdf[:date] = [DateTime(astimezone(d, tz"UTC")) for d in dates]

sortedDays = sort(collect(Set(CRSPdf[:date])))
sortedDaysDict = Dict()
for i in 1:length(sortedDays)
    sortedDaysDict[sortedDays[i]] = i
end
CRSPdf[:td] = 0
for row in 1:size(CRSPdf[:date],1)
    CRSPdf[:td][row] = sortedDaysDict[CRSPdf[:date][row]]
end
DataFrames.deletecols!(CRSPdf, [:ret, :vol, :dlret])


using Mongoc, Dates, JSON
client = Mongoc.Client()
database = client["Dec2018"]
collection = database["PermnoDay"]

@time for row in 1:size(CRSPdf,1)
    document = Dict(zip(string.(names(CRSPdf)), [x[1] for x in DataFrames.columns(CRSPdf[row:row,:])]))
    keystodelete = String[]
    for (crtkey, val) in document
        if ismissing(val) || val===NaN
            delete!(document, crtkey)
        end
    end
    result = push!(collection, Mongoc.BSON(document))
end
