using Mongo, TimeSeries, Plots, DataFrames, databaseQuerer, NaNMath, RCall, StatsBase
client = MongoClient()
MERGEconnect = MongoCollection(client, "NewsDB", "CRSPTRNAmerge2")
alldates = sort(Array{Dates.Date}(collect(fieldDistinct(MERGEconnect, ["date"])[1])))

# I have an extraordinary high value for alpha (class 5) on date 2015-01-31


function cumret(x, s = 1)
    res = Float64[s]
    cc=0
    for ret in x
        cc+=1
        push!(res, res[cc]*(1+ret))
    end
    return res
end

function TStoArray(TS)
    res = Float64[]
    x=collect(TS)
    for row in x
        push!(res, row[2][1])
    end
    return res
end

function nonnanidx(x)
    res=Int[]
    cc=0
    for i in x
        cc+=1
        if !isnan(i)
            push!(res, cc)
        end
    end
    return res
end

EWsent = Float64[]
VWsent = Float64[]
EWret = Float64[]
VWret = Float64[]
date = alldates[500]
for date in alldates
    sent = Float64[]
    wport = Float64[]
    returns = Float64[]
    cursor = find(MERGEconnect,
                Mongo.query("date" => date))
    for entry in cursor
        weight = entry["wport"]
        sentiment = entry["sentClasRel"]
        ret = entry["adjret"]
        if isnan(sentiment)
            sentiment=0
        end
        push!(wport, weight)
        push!(sent, sentiment)
        push!(returns, ret)
    end
    push!(EWsent, mean(sent))
    wvec = wport./sum(wport)
    push!(VWsent, sum(sent.*wvec))
    push!(EWret, mean(returns))
    push!(VWret, sum(returns.*wvec))
end

alldates = collect(alldates)
longdates = copy(alldates)
longdates = unshift!(longdates, longdates[1]-Dates.Day(1))
sentTS = TimeArray(alldates, hcat(VWsent, EWsent, VWret, EWret), ["VWsent", "EWsent", "VWret", "EWret"])
priceTS = TimeArray(longdates, hcat(cumret(VWret), cumret(EWret)), ["VWprice", "EWprice"])
# plotlyjs()
monthly = collapse(priceTS,month,last)
monthlyret = percentchange(monthly)
# plot(monthly)
# plot(collapse(sentTS,month,last,mean))
# cor(VWret[1:3500],VWsent[3:3502])
# mean(when(sentTS, dayname, "Monday"))
#
# using RCall
# X = TStoArray(sentTS["VWret"])
# Y = TStoArray(sentTS["VWsent"])
# @rput X
# @rput Y
# R"fit <- lm(Y ~ X)"
# R"summary(fit)"

function dregressions_idiosync(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase, alphas = 0, classification = 0, classvar = "β", percclass = 0)
    if NaNMath.mean_count(stock[2]["sentClasRel"])[2]>=minobs
        cc+=1
        goodidx = nonnanidx(stock[2]["sentClasRel"])
        datestokeep = stock[2]["date"][goodidx]
        X = stock[2]["sentClasRel"][goodidx]
        lagidx = goodidx-retlag
        lcc=0
        for i in lagidx
            lcc+=1
            if i==0
                lagidx[lcc]=1
            end
            if i>length(stock[2]["adjret"])
                lagidx[lcc]=length(stock[2]["adjret"])
            end
        end
        Y = stock[2]["adjret"][lagidx]
        @rput X
        @rput Y
        if length(sentTS[datestokeep]) == length(Y)
            Z = TStoArray(sentTS[datestokeep]["VWret"])
            @rput Z
        else
            Z = Y
            @rput Z
            print("hey")
        end
        # print(stock)
        # print(sentTS[datestokeep])
        # print(Y)
        if controlmarketret
            R"fit <- lm(Y ~ X + Z)"
        else
            R"fit <- lm(Y ~ X)"
        end
        R"tvalalpha = summary(fit)[['coefficients']][1,'t value']"
        R"tvalY = summary(fit)[['coefficients']][2,'t value']"
        R"betaalpha = summary(fit)[['coefficients']][1,'t value']"
        R"betaY = summary(fit)[['coefficients']][2,'t value']"
        @rget tvalalpha
        @rget tvalY
        @rget betaalpha
        @rget betaY
        if phase == "classification"
            try
                push!(daytvalY[crtmonth],tvalY)
                push!(daytvalalpha[crtmonth],tvalalpha)
                push!(daytbetaalpha[crtmonth],betaalpha)
                push!(daytbetaY[crtmonth],betaY)
            catch
                daytvalY[crtmonth] = Float64[]
                daytvalalpha[crtmonth] = Float64[]
                daytbetaalpha[crtmonth] = Float64[]
                daytbetaY[crtmonth] = Float64[]
                push!(daytvalY[crtmonth],tvalY)
                push!(daytvalalpha[crtmonth],tvalalpha)
                push!(daytbetaalpha[crtmonth],betaalpha)
                push!(daytbetaY[crtmonth],betaY)
            end
        elseif phase == "ranking"
            class = 0
            classval = 0
            if classvar == "β"
                classval = betaY
            elseif classvar == "t-stat"
                classval = tvalY
            end
            if classval < percclass[crtmonth][1]
                class = 1
            elseif percclass[crtmonth][1] <= classval < percclass[crtmonth][2]
                class = 2
            elseif percclass[crtmonth][2] <= classval < percclass[crtmonth][3]
                class = 3
            elseif percclass[crtmonth][3] <= classval < percclass[crtmonth][4]
                class = 4
            elseif percclass[crtmonth][4] <= classval
                class = 5
            end
            try
                push!(classification[crtmonth][class], stock[1])
            catch
                classification[crtmonth] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(classification[crtmonth][class], stock[1])
            end
            try
                push!(alphas[crtmonth][class], betaalpha)
            catch
                alphas[crtmonth] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(alphas[crtmonth][class], betaalpha)
            end
        end #if phase
    end #if enough observation
    if phase == "classification"
        return cc, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY
    elseif phase == "ranking"
        return cc, classification, alphas
    end
end

function dregressions_marketNA(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase, alphas = 0, classification = 0, classvar = "β", percclass = 0)
    if NaNMath.mean_count(stock[2]["adjret"])[2]>=minobs
        cc+=1
        # print("\n-------- $cc ---------------")
        # print(stock[1])
        # print(crtmonth)
        # print(stock[2]["adjret"])
        # print(stock[2]["date"])
        crtdates = stock[2]["date"]
        crtrets = stock[2]["adjret"]
        if crtdates[1]==crtdates[2]
            print("************************")
            crtdates = sort(collect(Set(crtdates)))
            looprets = copy(crtrets)
            crtrets = Float64[]
            ccloc=0
            for i in looprets
                ccloc+=1
                if ccloc%2 == 0
                    push!(crtrets, i)
                end
            end
        end
        goodidx = nonnanidx(crtrets)
        datestokeep = crtdates[goodidx]
        X = TStoArray(sentTS[datestokeep]["VWsent"])
        # print(goodidx)
        # print(datestokeep)
        # print(X)
        # print("====")
        lagidx = goodidx-retlag
        lcc=0
        for i in lagidx
            lcc+=1
            if i==0
                lagidx[lcc]=1
            end
            if i>length(crtrets)
                lagidx[lcc]=length(crtrets)
            end
        end
        # print(lagidx)
        # print(goodidx)
        # print(stock[2]["adjret"])
        Y = crtrets[lagidx]
        @rput X
        @rput Y
        if length(sentTS[datestokeep]) == length(Y)
            Z = TStoArray(sentTS[datestokeep]["VWret"])
            @rput Z
        else
            Z = Y
            @rput Z
            print("hey")
            print(Z)
            print(TStoArray(sentTS[datestokeep]["VWret"]))
            print(X)
            print(goodidx)
            print(lagidx)
            print(datestokeep)
            print(length(X))
            print(length(Y))
            print(length(Z))
        end
        if length(X)!=length(Y)
            R"fit <- lm(Y ~ Z)"
        else
            if controlmarketret
                R"fit <- lm(Y ~ X + Z)"
            else
                R"fit <- lm(Y ~ X)"
            end
        end
        R"tvalalpha = summary(fit)[['coefficients']][1,'t value']"
        R"tvalY = summary(fit)[['coefficients']][2,'t value']"
        R"betaalpha = summary(fit)[['coefficients']][1,'t value']"
        R"betaY = summary(fit)[['coefficients']][2,'t value']"
        @rget tvalalpha
        @rget tvalY
        @rget betaalpha
        @rget betaY
        if phase == "classification"
            try
                push!(daytvalY[crtmonth],tvalY)
                push!(daytvalalpha[crtmonth],tvalalpha)
                push!(daytbetaalpha[crtmonth],betaalpha)
                push!(daytbetaY[crtmonth],betaY)
            catch
                daytvalY[crtmonth] = Float64[]
                daytvalalpha[crtmonth] = Float64[]
                daytbetaalpha[crtmonth] = Float64[]
                daytbetaY[crtmonth] = Float64[]
                push!(daytvalY[crtmonth],tvalY)
                push!(daytvalalpha[crtmonth],tvalalpha)
                push!(daytbetaalpha[crtmonth],betaalpha)
                push!(daytbetaY[crtmonth],betaY)
            end
        elseif phase == "ranking"
            class = 0
            classval = 0
            if classvar == "β"
                classval = betaY
            elseif classvar == "t-stat"
                classval = tvalY
            end
            if classval < percclass[crtmonth][1]
                class = 1
            elseif percclass[crtmonth][1] <= classval < percclass[crtmonth][2]
                class = 2
            elseif percclass[crtmonth][2] <= classval < percclass[crtmonth][3]
                class = 3
            elseif percclass[crtmonth][3] <= classval < percclass[crtmonth][4]
                class = 4
            elseif percclass[crtmonth][4] <= classval
                class = 5
            end
            try
                push!(classification[crtmonth][class], stock[1])
            catch
                classification[crtmonth] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(classification[crtmonth][class], stock[1])
            end
            try
                push!(alphas[crtmonth][class], betaalpha)
            catch
                alphas[crtmonth] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(alphas[crtmonth][class], betaalpha)
            end
        end #if phase
    end #if enough observation
    if phase == "classification"
        return cc, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY
    elseif phase == "ranking"
        return cc, classification, alphas
    end
end


function meanresults(crtquint, alphas, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    ret, VWret, wport, BMclass, Sizeclass, StoriesCount, SentClasRel = quintileret(crtquint, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    a = Float64[]
    for row in ret
        push!(a, mean(row))
    end
    m = (mean(a)+1)^252-1
    sd = std(a)*(252^0.5)
    mVW = (mean(VWret)+1)^252-1
    sdVW = std(VWret)*(252^0.5)
    a = Float64[]
    for row in wport
        push!(a, mean(row))
    end
    w = mean(a)
    a = Float64[]
    for row in BMclass
        push!(a, mean(row))
    end
    BM = mean(a)
    a = Float64[]
    for row in Sizeclass
        push!(a, mean(row))
    end
    Size = mean(a)
    a = Float64[]
    for row in StoriesCount
        push!(a, NaNMath.mean(row))
    end
    Count =  NaNMath.mean(a)
    a = Float64[]
    for row in SentClasRel
        push!(a, NaNMath.mean(row))
    end
    Sent =  NaNMath.mean(a)
    a = Float64[]
    for d in alphas
        push!(a, mean(d[2][crtquint]))
    end
    malpha = mean(a)
    return m, sd, mVW, sdVW, w, BM, malpha, Size, Count, Sent
end

function quintileret(quint, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    resret = []
    resVWret = Float64[]
    reswport = []
    resBMclass = []
    resSizeclass = []
    resStoriesCount = []
    resSentClasRel = []
    for date in classification
        dateret = Float64[]
        datewport = Float64[]
        dateBMclass = Float64[]
        dateSizeclass = Float64[]
        dateStoriesCount = Float64[]
        dateSentClasRel = Float64[]
        for permno in date[2][quint]
            cursor = find(MERGEconnect,
                            Mongo.query("date" => Dict("\$gt"=>date[1]-prevperlag,
                                 "\$lte"=>date[1]+nextperlag),
                                        "permno" =>permno))
            rets = Float64[]
            wports = Float64[]
            BMclasss = Float64[]
            Sizeclasss = Float64[]
            StoriesCount = Float64[]
            SentClasRel = Float64[]
            for entry in cursor
                push!(rets, entry["adjret"])
                push!(wports, entry["wport"])
                ptf10x10 = entry["ptf_10by10_size_value"]
                crtBMclass = round((ceil(ptf10x10)-ptf10x10)*10)
                push!(BMclasss, crtBMclass)
                crtSizeclass = ceil(ptf10x10)
                push!(Sizeclasss, crtSizeclass)
                push!(StoriesCount, entry["storiesCount"])
                push!(SentClasRel, entry["sentClasRel"])
            end
            if length(rets)>0
                push!(dateret, geomean(rets+1)-1)
                push!(datewport, mean(wports))
                push!(dateBMclass, mean(BMclasss))
                push!(dateSizeclass, mean(Sizeclasss))
                push!(dateStoriesCount, mean(StoriesCount))
                push!(dateSentClasRel, mean(SentClasRel))
            end
        end
        push!(resret, dateret)
        push!(resVWret, NaNMath.sum(dateret.*(datewport./NaNMath.sum(datewport))))
        push!(reswport, datewport)
        push!(resBMclass, dateBMclass)
        push!(resSizeclass, dateSizeclass)
        push!(resStoriesCount, dateStoriesCount)
        push!(resSentClasRel, dateSentClasRel)
    end
    return resret, resVWret, reswport, resBMclass, resSizeclass, resStoriesCount, resSentClasRel
end

finalresults = []


for i in 1:12
print(i)
idionews = true
if i <= 3
    periodspan = Dates.Month(3)
    minobs = 15
elseif i <= 6
    periodspan = Dates.Month(1)
    minobs = 10
elseif i <= 9
    periodspan = Dates.Month(6)
    minobs = 20
elseif i <= 12
    periodspan = Dates.Month(12)
    minobs = 20
end
if i%3==0
    retlag = 0
elseif i%3==1
    retlag=1
elseif i%3==2
    retlag=-1
end

controlmarketret = true
classvar = "β"
print("$retlag - $controlmarketret - $idionews \n")

monthlydates = Dates.Date(2003,1,31):periodspan:Dates.Date(2017,6,30)
daytvalY = Dict()
daytvalalpha = Dict()
daytbetaalpha = Dict()
daytbetaY = Dict()
chosenstocks = []
cc = 0
for crtmonth in monthlydates
    monthdic = Dict()
    cursor = find(MERGEconnect,
                    Mongo.query("date" => Dict("\$gte"=>crtmonth-periodspan,
                                               "\$lt"=>crtmonth)))
    for entry in cursor
        try
            push!(monthdic[entry["permno"]]["date"], entry["date"])
            push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
            push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        catch
            monthdic[entry["permno"]] = Dict()
            monthdic[entry["permno"]]["date"] = Dates.Date[]
            monthdic[entry["permno"]]["adjret"] = Float64[]
            monthdic[entry["permno"]]["sentClasRel"] = Float64[]
            push!(monthdic[entry["permno"]]["date"], entry["date"])
            push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
            push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        end
    end
    for stock in monthdic
        phase = "classification"
        if idionews
            cc, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY = dregressions_idiosync(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase)
        else
            cc, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY = dregressions_marketNA(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase)
        end
    end
    push!(chosenstocks, [cc, length(monthdic)])
end

percclass = Dict()
if classvar == "β"
    dayrankers = copy(daytbetaY)
elseif classvar =="t-stat"
    dayrankers = copy(daytvalY)
end
for date in dayrankers
    percclass[date[1]] = percentile(date[2], [20,40,60,80])
end


classification = Dict()
alphas = Dict()
for crtmonth in monthlydates
    monthdic = Dict()
    cursor = find(MERGEconnect,
                    Mongo.query("date" => Dict("\$gte"=>crtmonth-periodspan,
                                               "\$lt"=>crtmonth)))
    for entry in cursor
        try
            push!(monthdic[entry["permno"]]["date"], entry["date"])
            push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
            push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        catch
            monthdic[entry["permno"]] = Dict()
            monthdic[entry["permno"]]["date"] = Dates.Date[]
            monthdic[entry["permno"]]["adjret"] = Float64[]
            monthdic[entry["permno"]]["sentClasRel"] = Float64[]
            push!(monthdic[entry["permno"]]["date"], entry["date"])
            push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
            push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        end
    end
    for stock in monthdic
        phase = "ranking"
        if idionews
            cc, classification, alphas = dregressions_idiosync(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase, alphas, classification, classvar, percclass)
        else
            cc, classification, alphas = dregressions_marketNA(cc, stock, sentTS, retlag, daytvalY, daytvalalpha, daytbetaalpha, daytbetaY, crtmonth, minobs, controlmarketret, phase, alphas, classification, classvar, percclass)
        end
    end
end


lagspecs = [(Dates.Month(0), periodspan), #same period as portfolio formation
            (periodspan, Dates.Month(0))] # following period of same length as portfolio formation
for lagspec in lagspecs
    nextperlag = lagspec[1]
    prevperlag = lagspec[2]
    per = []
    for j in 1:5
        a = meanresults(j, alphas, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
        push!(per, a)
    end
    push!(finalresults, per)
end

print(finalresults)

end #for 1:12

df = DataFrame(avgret = Float64[], sd = Float64[], VWavgret = Float64[], VWsd = Float64[], wport = Float64[], BMrank = Float64[], alpha = Float64[], Sizerank = Float64[], StoriesCount = Float64[], avgSent = Float64[])
for rtype in finalresults
    push!(df, hcat(rtype[1][1],rtype[1][2],rtype[1][3],rtype[1][4], rtype[1][5], rtype[1][6],rtype[1][7],rtype[1][8],rtype[1][9], rtype[1][10]))
    push!(df, hcat(rtype[2][1],rtype[2][2],rtype[2][3],rtype[2][4], rtype[2][5], rtype[2][6],rtype[2][7],rtype[2][8],rtype[2][9], rtype[2][10]))
    push!(df, hcat(rtype[3][1],rtype[3][2],rtype[3][3],rtype[3][4], rtype[3][5], rtype[3][6],rtype[3][7],rtype[3][8],rtype[3][9], rtype[3][10]))
    push!(df, hcat(rtype[4][1],rtype[4][2],rtype[4][3],rtype[4][4], rtype[4][5], rtype[4][6],rtype[4][7],rtype[4][8],rtype[4][9], rtype[4][10]))
    push!(df, hcat(rtype[5][1],rtype[5][2],rtype[5][3],rtype[5][4], rtype[5][5], rtype[5][6],rtype[5][7],rtype[5][8],rtype[5][9], rtype[5][10]))
end

using CSV
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/angetal.csv"
CSV.write(output, df)
