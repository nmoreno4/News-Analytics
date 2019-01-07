module TSmap
using Dates, CSV

export TSfreq, yearID, quarterID, monthID, weekID, dayID, halfmonthID, semesterID

########## Time filter ##################
function TSfreq(FFpath="/home/nicolas/Data/FF/dailyFactors.csv", rowstoread=1:3776)
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

function yearID(x)
    y = Dates.year(x)
    return ceil(Date(y,2), Year) - Dates.Day(1)
end

function quarterID(x)
    q = Dates.quarterofyear(x)
    y = Dates.year(x)
    if q==1
        m=3
    elseif q==2
        m=6
    elseif q==3
        m=9
    elseif q==4
        m=9
    end
    return ceil(Date(y,m,15), Month) - Dates.Day(1) #y*10+q
end


function semesterID(x)
    q = Dates.quarterofyear(x)
    y = Dates.year(x)
    if q<=2 # Comprised between January and June
        m=6
    elseif 3<=q<=4 # Comprised between July and December
        m=12
    end
    return ceil(Date(y,m,15), Month) - Dates.Day(1) #y*10+q
end


function monthID(x)
    m = Dates.month(x)
    y = Dates.year(x)
    return ceil(Date(y,m,15), Month) - Dates.Day(1) #y*100+m
end


"""
Does not provide satisfaction at the moment since it splits the month
in two (unequal?) parts.
"""
function halfmonthID(x)
    d = Dates.dayofmonth(x)
    m = Dates.month(x)
    y = Dates.year(x)
    if d<=15 # Comprised in first two weeks of month
        w=2
    elseif 15<d # Comprised in after two weeks of month
        w=4
    end
    return toprev(Date(y,m) + Week(w), Friday)
end


function weekID(x)
    w = Dates.dayofweekofmonth(x)
    m = Dates.month(x)
    y = Dates.year(x)
    return toprev(Date(y,m) + Week(w), Friday) #y*10000+m*100+w
end


function dayID(x, initDate=Dates.Date(2003,1,1))
    # return Dates.value(Dates.Date(x)-initDate)
    return x
end


end #module
