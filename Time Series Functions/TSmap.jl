module TSmap
using Dates, CSV

export TSfreq

########## Time filter ##################
function TSfreq(FFpath="/run/media/nicolas/Research/FF/dailyFactors.csv", rowstoread=1:3776)
    print("I read rows $(rowstoread) from file $(FFpath)\n")
    FFfactors = CSV.read(FFpath)[rowstoread,:]
    todate = x -> Date(string(x),"yyyymmdd")
    dates = todate.(FFfactors[:Date])
    ymonth = convert(Array{Any}, Dates.yearmonth.(dates))
    for i in 1:length(ymonth)
        ymonth[i] = "$(ymonth[i])"
    end
    months = Dates.month.(dates)
    weekdays = Dates.dayname.(dates)
    ys = convert(Array{Any}, Dates.year.(dates))
    wmy = []
    for (i,j,k) in zip(Dates.week.(dates), ys,months)
        push!(wmy, "$k $j $i")
    end
    qy = []
    for (i,j) in zip(Dates.quarterofyear.(dates), ys)
        push!(qy, "$j $i")
    end
    return Dict(:weekdays=>weekdays, :wmy=>wmy, :months=>months, :qy=>qy, :ymonth=>ymonth, :ys=>ys)
end

end #module
