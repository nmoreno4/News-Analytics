module TSmap
using Dates, CSV

export TSfreq

########## Time filter ##################
function TSfreq(FFpath="/run/media/nicolas/Research/FF/dailyFactors.csv", rowstoread=1:3776)
    print("I read rows $(rowstoread) from file $(FFpath)\n")
    FFfactors = CSV.read(FFpath)[rowstoread,:]
    todate = x -> Date(string(x),"yyyymmdd")
    dates = todate.(FFfactors[:Date])
    ys = Dates.year.(dates)
    qy = []
    for (q, y) in zip(Dates.quarterofyear.(dates),  Dates.year.(dates))
        push!(qy, y*10+q)
    end
    wmy = []
    for (y,m,w) in zip(Dates.year.(dates) ,Dates.month.(dates), Dates.week.(dates))
        push!(wmy, y*10000+m*100+w)
    end
    ymonth = []
    for (y,m) in zip(Dates.year.(dates) ,Dates.month.(dates))
        push!(ymonth, y*100+m)
    end
    return Dict(:weekdays=>weekdays, :wmy=>wmy, :months=>months, :qy=>qy, :ymonth=>ymonth, :ys=>ys)
end

end #module
