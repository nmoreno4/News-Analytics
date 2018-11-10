using RCall, Statistics, StatsBase, TimeZones, Dates
include("/home/nicolas/github/News-Analytics/Denada_DB/WRDS/WRDSdownload.jl")

function sent_ret_series(sentMat, wMat, retMat, nbstoriesMat, ignoremissing=false)
    wMat = convert(Array, wMat)
    retMat = convert(Array, retMat)
    nbstoriesMat = convert(Array, nbstoriesMat)
    sentMat = convert(Array, sentMat)

    #Divide sentiment by nb of stories
    try
        sentMat = replace_nan(convert(Array{Union{Float64, Missing},2}, sentMat ./ nbstoriesMat))
    catch
        print(size(sentMat))
        print("\n==\n")
        print(size(nbstoriesMat))
        error("custom: arrays could not be broadcast to a common size")
    end

    VWsent, coveredMktCp = weightsum(wMat, sentMat, "VW", ignoremissing)
    VWret, coveredMktCp = weightsum(wMat, retMat, "VW", ignoremissing)

    EWsent, coveredMktCp = weightsum(wMat, sentMat, "EW", ignoremissing)
    EWret, coveredMktCp = weightsum(wMat, retMat, "EW", ignoremissing)
    return VWsent, VWret, EWsent, EWret, rowsummissing(nbstoriesMat), rowsummissing(wMat), rowcountmissing(sentMat), rowcountmissing(retMat)
end

function rowsummissing(X)
    res = Float64[]
    for row in 1:size(X,1)
        push!(res, missingsum(X[row,:], 0))
    end
    return res
end

function rowcountmissing(X)
    res = Float64[]
    for row in 1:size(X,1)
        push!(res, missingsum(0*X[row,:].+1, 0))
    end
    return res
end

function replace_nan(crtDF, replace_val=missing)
    for r in 1:size(crtDF,1)
        for c in 1:size(crtDF,2)
            if !(ismissing(crtDF[r,c])) && isnan(crtDF[r,c])
                crtDF[r,c] = replace_val
            end
        end
    end
    return crtDF
end

function queryDB(tdperiods, chosenVars, valR, sizeR, mongo_collection)
    #query filters for MongoDB
    periodspan = Dict("\$gte"=>tdperiods[1], "\$lte"=>tdperiods[2])
    bmfilter = Dict("\$gte"=>valR[1], "\$lte"=>valR[2])
    sizefilter = Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])

    # Get all the unique trading days
    uniqueTd = mongo_collection[:find](Dict("td"=>periodspan))[:distinct]("td")
    # Get all unique stock identifiers (permno) during the period
    uniquePermno = mongo_collection[:find](Dict("td"=>periodspan,
                                                "bmdecile"=>bmfilter,
                                                "sizedecile"=>sizefilter))[:distinct]("permno")

    #Create dataframes
    dfDict = Dict{String, DataFrame}()
    for queryVar in chosenVars
        dfDict[queryVar] = initDF(Int64.(uniquePermno), length(uniqueTd))
    end

    for td in tdperiods[1]:tdperiods[2]
        for filtDic in mongo_collection[:find](Dict("td"=>td,
                                                    "bmdecile"=>bmfilter,
                                                    "sizedecile"=>sizefilter),
                                               # Return only the variables we care about + the permno
                                               Dict(zip([chosenVars;"permno"], repeat([1],length(chosenVars)+1))))
            crtpermno = Int64(filtDic["permno"])
            for var in filtDic
                if !(var[1] in ["permno", "_id"])
                    if typeof(var[2]) in [Float64, Int64]
                        dfDict[var[1]][Symbol(crtpermno)][td] = Float64(var[2])
                    end
                end #if one of the desired variables
            end
        end
    end
    return dfDict
end


function initDF(colnames, nbrows, coltype=Union{Missing, Float64}, defaultfill=missing)
    df1 = DataFrame()
    for colname in colnames
        df1[Symbol(colname)] = Array{coltype,1}(defaultfill, nbrows)
    end
    return df1
end



function weightsum(wMat, sMat, WS, ignoremissing)
    res = Union{Missing,Float64}[]
    coveredMktCp = Union{Missing,Float64}[]
    for row in 1:size(sMat,1)
        wrow = wMat[row,:];
        srow = sMat[row,:];
        if ignoremissing
            # Take as sum of market only stocks where there is a news (sum of weights = 1)
            idxtokeep = intersect(findall(nonmissing,srow), findall(nonmissing,wrow))
            if WS == "VW"
                a = wrow[idxtokeep]./sum(wrow[idxtokeep]).*srow[idxtokeep]
            elseif WS == "EW"
                a = mean(wrow[idxtokeep])./sum(wrow[idxtokeep]).*srow[idxtokeep]
            end
        else
            # Take as sum of market all stocks (sum of weights < 1)
            if WS == "VW"
                a = wrow./missingsum(wrow).*srow
            elseif WS == "EW"
                a = missingmean(wrow)./missingsum(wrow).*srow
            end
            nonmissingIdx = findall(nonmissing,a)
            # print(length(nonmissingIdx))
            # print("\n\n")
            try
                a = Array{Float64,1}(a[nonmissingIdx])
            catch
                a = Float64[]
            end
        end #if only use non-missing values
        push!(res, sum(a))
        push!(coveredMktCp, missingsum(wrow[findall(nonmissing,srow)]./missingsum(wrow)))
    end #for row
    return res, coveredMktCp
end



nonmissing(x) = !(ismissing(x))
function missingsum(x, retval=missing)
    if sum(nonmissing.(x))>0
        return sum(skipmissing(x))
    else
        return retval
    end
end
function missingmax(x)
    if sum(nonmissing.(x))>0
        return maximum(skipmissing(x))
    else
        return missing
    end
end
function missingmean(x)
    if sum(nonmissing.(x))>0
        return mean(skipmissing(x))
    else
        return missing
    end
end


function Rheatmap(X, mytitle, nbcolors=50)
    @rput X
    @rput mytitle
    R"library(plotly)"
    # R"colnames(X) <- paste('S', 1:10, sep='')"
    # R"rownames(X) <- paste('V', 1:10, sep='')"
    # R"Sys.setenv('plotly_username'='matlas')"
    # R"Sys.setenv('plotly_api_key'='Nicolas44')"
    R"p <- plot_ly(z = X, type = 'heatmap', name = mytitle, x = paste('S', 1:dim(X)[2], sep=''), y = paste('V', 1:dim(X)[1], sep=''), colorscale = 'Greys')"
    # R"plotly_IMAGE(p, format = 'png', out_file = paste('/home/nicolas/', mytitle, '.png', sep=''))"
    # R"image(1:ncol(X), 1:nrow(X), t(X), col = heat.colors($nbcolors), axes = FALSE)"
    # R"legend(grconvertX(2.5, 'device'), grconvertY(2, 'device'), c(min(X), mean(X), max(X)) fill = heat.colors($nbcolors), xpd = T)"
    # R"axis(1, 1:ncol(X), colnames(X))"
    # R"axis(2, 1:nrow(X), rownames(X))"
end
# RColorBrewer::brewer.pal.info




function bmszmat(resDic, sentvar="sent_rel100_nov24H", countvar="nbStories_rel100_nov24H")
    avgSentMatVW1 = ones(10,10)
    avgSentMatVW2 = ones(10,10)
    avgSentMatEW1 = ones(10,10)
    avgSentMatEW2 = ones(10,10)
    nbStoriesmat1 = ones(10,10)
    nbStoriesmat2 = ones(10,10)
    avgNbcompwStories = ones(10,10)
    avgNbcomp = ones(10,10)
    Mcap1 = ones(10,10)
    Mcap2 = ones(10,10)
    for val in 1:10
        for sz in 1:10
            VWsent, VWret, EWsent, EWret, nbStories, mCap, nbcompwStories, nbcomp  = sent_ret_series(resDic[val*100+sz][sentvar], resDic[val*100+sz]["dailywt"],
                resDic[val*100+sz]["dailyretadj"], resDic[val*100+sz][countvar])
            avgSentMatVW1[val, sz] = mean(VWsent)
            avgSentMatVW2[val, sz] = mean(VWsent[VWsent .!= 0.0])
            avgSentMatEW1[val, sz] = mean(EWsent)
            avgSentMatEW2[val, sz] = mean(EWsent[EWsent .!= 0.0])
            nbStoriesmat1[val, sz] = mean(nbStories)
            nbStoriesmat2[val, sz] = mean(nbStories[nbStories .!= 0.0])
            Mcap1[val, sz] = mean(mCap)
            Mcap2[val, sz] = mean(mCap[mCap .!= 0.0])
            avgNbcompwStories[val, sz] = mean(nbcompwStories)
            avgNbcomp[val, sz] = mean(nbcomp)
        end
    end
    return avgSentMatVW1, avgSentMatVW2, avgSentMatEW1, avgSentMatEW2, nbStoriesmat1, nbStoriesmat2, Mcap1, Mcap2, avgNbcompwStories, avgNbcomp
end



function aroundEAD(EADmat, lagids, includearound=true)
    foo = convert(Array, EADmat)
    for col in 1:size(foo, 2)
        row=1
        while row<=size(foo, 1)
            if !ismissing(foo[row, col]) && foo[row, col]==1
                includearound ? foo[row, col] = missing : foo[row, col] = 1
                for lagid in lagids
                    if lagid>size(foo, 1)
                        lagid=size(foo, 1)
                    elseif (row+lagid)<1
                        lagid=row-1
                    end
                    includearound ? foo[row+lagid, col] = 1 : foo[row+lagid, col] = missing
                end
                row+=maximum([lagids;0])
            elseif !includearound
                foo[row, col] = 1
            end
            row+=1
        end
    end
    return foo
end


function polarityQuantile(sentMat, perc)
    foo = convert(Array{Union{Missing, Float64}}, convert(Array, sentMat).*missing)
    for col in 1:size(sentMat, 2)
        if perc[2]>1 #if I look for a percentile
            try
                thresh = percentile(collect(skipmissing(replace_nan(sentMat[:,col]))), perc)
            catch
                thresh =  [1000,999] #never falls in quantile since I have no data
            end
        else #if I look for a sent score between -1 and 1
            thresh = perc
        end
        row=1
        while row<=size(sentMat, 1)
            if !ismissing(sentMat[row, col]) && thresh[1]<=sentMat[row, col]<=thresh[2]
                foo[row, col] = 1
            end
            row+=1
        end
    end
    return foo
end


function conditionalEAD(resDic, val, sz, sentvar, countvar, perc, lagids, ignoremissing=false, includeonlyaroundEAD=true, isdecile=true)
    if isdecile
        idx = val*100+sz
    else
        idx = val*10+sz
    end
    wMat = convert(Array, resDic[idx]["dailywt"])
    nbstoriesMat = convert(Array, resDic[idx][countvar])
    sentMat = convert(Array, resDic[idx][sentvar])
    #Divide sentiment by nb of stories
    bis = replace_nan(convert(Array{Union{Float64, Missing},2}, sentMat ./ nbstoriesMat))
    eadMat = aroundEAD(resDic[idx]["EAD"], lagids, includeonlyaroundEAD)
    polMat = polarityQuantile(bis, perc)

    VWsent, coveredMktCp = weightsum(wMat, sentMat.*eadMat.*polMat, "VW", ignoremissing)

    EWsent, coveredMktCp = weightsum(wMat, sentMat.*eadMat.*polMat, "EW", ignoremissing)
    return VWsent, EWsent, rowsummissing(nbstoriesMat.*eadMat.*polMat), rowcountmissing(wMat), rowcountmissing(sentMat.*eadMat.*polMat),  rowcountmissing(wMat.*eadMat.*polMat)
end


function countmissing(X)
    totmissing = 0
    nonmissing = 0
    for row in 1:size(X,1)
        for col in 1:size(X,2)
            if ismissing(X[row,col])
                totmissing+=1
            else
                nonmissing+=1
            end
        end
    end
    return totmissing, nonmissing
end



function EADfiltmat(resDic, sentvar, countvar, perc, aroundDates=-1:1, includearound=true, specs = true)
    EADfiltMat = Dict()
    for spec in specs
        if length(specs)>50
            deciles = true
            val = floor(spec/100)
            sz = spec-floor(spec/100)*100
        else
            deciles = false
            val = floor(spec/10)
            sz = spec-floor(spec/10)*10
        end
        EADfiltMat[spec] = conditionalEAD(resDic, val,sz, sentvar, countvar, perc, aroundDates, false, includearound, deciles)
    end
    return EADfiltMat
end

function valszCondMeanEAD(EADmat1, EADmat2, specs, compVec = 1)
    if length(specs)>50
        doubleEntryMat = ones(10,10)
    else
        doubleEntryMat = ones(5,5)
    end
    for spec in specs
        if length(specs)>50
            val = Int(floor(spec/100))
            sz = Int(spec-floor(spec/100)*100)
        else
            val = Int(floor(spec/10))
            sz = Int(spec-floor(spec/10)*10)
        end
        if EADmat2==0 && length(compVec)==1
            doubleEntryMat[val,sz] = missingmean(EADmat1[spec][compVec])
        elseif length(compVec)==2 && EADmat2==0
            doubleEntryMat[val,sz] = missingmean(EADmat1[spec][compVec[1]])/missingmean(EADmat1[spec][compVec[2]])
        elseif length(compVec) == 2
            doubleEntryMat[val,sz] = missingmean(EADmat1[spec][compVec[1]])/missingmean(EADmat2[spec][compVec[2]])
        else
            doubleEntryMat[val,sz] = missingmean(EADmat1[spec][compVec])-missingmean(EADmat2[spec][compVec])
        end
    end
    return doubleEntryMat
end




function HMLspread(resDic, sentvar, countvar, perc, lagids, ignoremissing=false, includeonlyaroundEAD=true, specs = ([(1,3), (1,5)], [(1,3), (6,10)], [(8,10), (1,5)], [(8,10), (6,10)], [(4,7), (1,5)], [(4,7), (6,10)]))
    arrayDic = Dict()
    for spec in specs
        arrayDic[spec] = Dict()
        arrayDic[spec]["wMat"] = convert(Array, resDic[spec]["dailywt"])
        arrayDic[spec]["retMat"] = convert(Array, resDic[spec]["dailyretadj"])
        arrayDic[spec]["nbstoriesMat"] = convert(Array, resDic[spec][countvar])
        arrayDic[spec]["sentMat"] = convert(Array, resDic[spec][sentvar])
        arrayDic[spec]["bis"] = replace_nan(convert(Array{Union{Float64, Missing},2}, arrayDic[spec]["sentMat"] ./ arrayDic[spec]["nbstoriesMat"]))
        arrayDic[spec]["eadMat"] = aroundEAD(resDic[spec]["EAD"], lagids, includeonlyaroundEAD)
        arrayDic[spec]["polMat"] = polarityQuantile(arrayDic[spec]["bis"], perc)
        if perc == [0,100]
            arrayDic[spec]["polMat"] = ones(size(arrayDic[spec]["polMat"]))
        end
        arrayDic[spec]["VWsent"] = weightsum(arrayDic[spec]["wMat"], arrayDic[spec]["bis"].*arrayDic[spec]["eadMat"].*arrayDic[spec]["polMat"], "VW", ignoremissing)[1]
        arrayDic[spec]["VWret"] = weightsum(arrayDic[spec]["wMat"], arrayDic[spec]["retMat"].*arrayDic[spec]["eadMat"].*arrayDic[spec]["polMat"], "VW", ignoremissing)[1]
        arrayDic[spec]["EWsent"] = weightsum(arrayDic[spec]["wMat"], arrayDic[spec]["bis"].*arrayDic[spec]["eadMat"].*arrayDic[spec]["polMat"], "EW", ignoremissing)[1]
        arrayDic[spec]["EWret"] = weightsum(arrayDic[spec]["wMat"], arrayDic[spec]["retMat"].*arrayDic[spec]["eadMat"].*arrayDic[spec]["polMat"], "EW", ignoremissing)[1]
    end
    return arrayDic
end




function Rplot(X, ret2tick=false)
    @rput X
    if ret2tick
        R"ret2tick <- function(vec, startprice){return(Reduce(function(x,y) {x * exp(y)}, vec, init=startprice, accumulate=T))}"
        R"X <- ret2tick(X, 100)"
    end
    R"plot(X, type='l')"
end

function RsimpleReg(X, Y)
    @rput X; @rput Y
    R"reg = lm(X~Y)"
    R"regsummary = summary(reg)"
    @rget regsummary
    return regsummary
end

function formatRegR(regsummary)
    resDic = Dict()
    for var in 1:size(regsummary[:coefficients], 1)
        i=0
        for col in ["estimate", "std. err.", "t-val", "p-val"]
            i+=1
            resDic["β$(var-1)_$(col)"] = regsummary[:coefficients][var, i]
        end
    end
    resDic["R2"] = regsummary[:r_squared]
    resDic["adj_R2"] = regsummary[:adj_r_squared]
    resDic["f-stat"] = regsummary[:fstatistic]
    return resDic
end



function HMLspread!(ptf2x3)
    ptf2x3["Hsent"] = (ptf2x3[[(1,3), (1,5)]]["VWsent"] .+ ptf2x3[[(1,3), (6,10)]]["VWsent"]) ./ 2
    ptf2x3["Lsent"] = (ptf2x3[[(8,10), (1,5)]]["VWsent"] .+ ptf2x3[[(8,10), (6,10)]]["VWsent"]) ./ 2
    ptf2x3["HMLsent"] = ptf2x3["Hsent"].-ptf2x3["Lsent"]
    ptf2x3["Hret"] = (ptf2x3[[(1,3), (1,5)]]["VWret"] .+ ptf2x3[[(1,3), (6,10)]]["VWret"]) ./ 2
    ptf2x3["Lret"] = (ptf2x3[[(8,10), (1,5)]]["VWret"] .+ ptf2x3[[(8,10), (6,10)]]["VWret"]) ./ 2
    ptf2x3["HMLret"] = ptf2x3["Hret"].-ptf2x3["Lret"]
    return ptf2x3
end



function specsids(dims)
    res = []
    for val in 1:dims
        for sz in 1:dims
            if dims == 10
                push!(res, val*100+sz)
            elseif dims == 5
                push!(res, val*10+sz)
            end
        end
    end
    return res
end



function keepSeriesOnly!(ptfDicts)
    for ptfDic in ptfDicts
        try
            delete!(ptfDicts[ptfDic[1]], "nbstoriesMat")
            delete!(ptfDicts[ptfDic[1]], "wMat")
            delete!(ptfDicts[ptfDic[1]], "eadMat")
            delete!(ptfDicts[ptfDic[1]], "retMat")
            delete!(ptfDicts[ptfDic[1]], "sentMat")
            delete!(ptfDicts[ptfDic[1]], "polMat")
            delete!(ptfDicts[ptfDic[1]], "bis")
        catch
            nothing
        end
    end
    return ptfDicts
end




function queryDB_singlefilt(filtvar, tdperiods, chosenVars, cRange, mongo_collection)
    #query filters for MongoDB
    periodspan = Dict("\$gte"=>tdperiods[1], "\$lte"=>tdperiods[2])
    myfilter = Dict("\$gte"=>cRange[1], "\$lte"=>cRange[2])

    # Get all the unique trading days
    uniqueTd = mongo_collection[:find](Dict("td"=>periodspan))[:distinct]("td")
    # Get all unique stock identifiers (permno) during the period
    uniquePermno = mongo_collection[:find](Dict("td"=>periodspan,
                                                filtvar=>myfilter))[:distinct]("permno")

    #Create dataframes
    dfDict = Dict{String, DataFrame}()
    for queryVar in chosenVars
        dfDict[queryVar] = initDF(Int64.(uniquePermno), length(uniqueTd))
    end

    for td in tdperiods[1]:tdperiods[2]
        for filtDic in mongo_collection[:find](Dict("td"=>td,
                                                    filtvar=>myfilter),
                                               # Return only the variables we care about + the permno
                                               Dict(zip([chosenVars;"permno"], repeat([1],length(chosenVars)+1))))
            crtpermno = Int64(filtDic["permno"])
            for var in filtDic
                if !(var[1] in ["permno", "_id"])
                    if typeof(var[2]) in [Float64, Int64]
                        dfDict[var[1]][Symbol(crtpermno)][td] = Float64(var[2])
                    end
                end #if one of the desired variables
            end
        end
    end
    return dfDict
end



function datesVec(y_start=2003, y_end = 2017, d_start="01", d_end = "31", m_start="01", m_end = "12")
    FF_factors = FF_factors_download(["$(m_start)/$(d_start)/$(y_start)", "$(m_end)/$(d_end)/$(y_end)"])
    dates = map(DateTime, FF_factors[:date])+Dates.Hour(16)
    pushfirst!(dates, Dates.DateTime(2001,12,31,20))
    dates = [ZonedDateTime(d, tz"America/New_York") for d in dates]
    dates = [DateTime(astimezone(d, tz"UTC")) for d in dates]
    return dates
end


function trading_day(dates, crtdate, offset = Dates.Hour(0))
  i=0
  res = 0
  for d in dates
    i+=1
    if dates[i]-offset < crtdate <= dates[i+1]-offset
      return i
      break
    end
  end
  return res
end



function queryDB_singlefilt_Dic(filtvar, tdperiods, chosenVars, cRange, mongo_collection)
    #query filters for MongoDB
    periodspan = Dict("\$gte"=>tdperiods[1], "\$lte"=>tdperiods[2])
    myfilter = Dict("\$gte"=>cRange[1], "\$lte"=>cRange[2])

    # Get all the unique trading days
    uniqueTd = mongo_collection[:find](Dict("td"=>periodspan))[:distinct]("td")
    # Get all unique stock identifiers (permno) during the period
    uniquePermno = mongo_collection[:find](Dict("td"=>periodspan,
                                                filtvar=>myfilter))[:distinct]("permno")

    #Create dataframes
    # dfDict = Dict{String, DataFrame}()
    # for queryVar in chosenVars
    #     dfDict[queryVar] = initDF(Int64.(uniquePermno), length(uniqueTd))
    # end
    resDic = Dict()
    keylabels = []

    for td in tdperiods[1]:tdperiods[2]
        for filtDic in mongo_collection[:find](Dict("td"=>td,
                                                    filtvar=>myfilter),
                                               # Return only the variables we care about + the permno
                                               Dict(zip([chosenVars;"permno"], repeat([1],length(chosenVars)+1))))
            filtDic["permno"] = Int64(filtDic["permno"])
            for var in chosenVars
                if !(var in collect(keys(filtDic)))
                    filtDic[var] = NaN
                end
            end
            resDic["$(td)_$(filtDic["permno"])"] = [collect(values(filtDic));td]
            if keylabels == []
                keylabels = [collect(keys(filtDic)); "td"]
            elseif keylabels!=[collect(keys(filtDic)); "td"]
                print([collect(keys(filtDic)); "td"])
                print("sth weird happened")
            end
        end
    end
    return resDic, keylabels
end


function queryDB_doublefilt_Dic(filtvars, tdperiods, chosenVars, v1Range, v2Range, mongo_collection)
    #query filters for MongoDB
    periodspan = Dict("\$gte"=>tdperiods[1], "\$lte"=>tdperiods[2])
    filter1 = Dict("\$gte"=>v1Range[1], "\$lte"=>v1Range[2])
    filter2 = Dict("\$gte"=>v2Range[1], "\$lte"=>v2Range[2])

    # Get all the unique trading days
    uniqueTd = mongo_collection[:find](Dict("td"=>periodspan))[:distinct]("td")
    # Get all unique stock identifiers (permno) during the period
    uniquePermno = mongo_collection[:find](Dict("td"=>periodspan,
                                                filtvars[1]=>filter1,
                                                filtvars[2]=>filter2))[:distinct]("permno")

    #Create dataframes
    # dfDict = Dict{String, DataFrame}()
    # for queryVar in chosenVars
    #     dfDict[queryVar] = initDF(Int64.(uniquePermno), length(uniqueTd))
    # end
    resDic = Dict()
    keylabels = []

    for td in tdperiods[1]:tdperiods[2]
        for filtDic in mongo_collection[:find](Dict("td"=>td,
                                                    filtvars[1]=>filter1,
                                                    filtvars[2]=>filter2),
                                               # Return only the variables we care about + the permno
                                               Dict(zip([chosenVars;"permno"], repeat([1],length(chosenVars)+1))))
            filtDic["permno"] = Int64(filtDic["permno"])
            for var in chosenVars
                if !(var in collect(keys(filtDic)))
                    filtDic[var] = NaN
                end
            end
            resDic["$(td)_$(filtDic["permno"])"] = [collect(values(filtDic));td]
            if keylabels == []
                keylabels = [collect(keys(filtDic)); "td"]
            elseif keylabels!=[collect(keys(filtDic)); "td"]
                print([collect(keys(filtDic)); "td"])
                print("sth weird happened")
            end
        end
    end
    return resDic, keylabels
end



function transposeDF(df)
    varsToStack = names(df)
    df[:id] = 1:size(df, 1)
    dfl = stack(df, varsToStack)
    dfnew = unstack(dfl, :variable, :id, :value)
    return dfnew
end


function queryDic_to_df(a, keylabels)
    b = @time DataFrame(a)
    b = @time transposeDF(b)
    delete!(b, :variable)
    names!(b, [Symbol(x) for x in keylabels])
    return b
end


function custom_std(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return std(collect(skipmissing(X)))
end
function custom_mean(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return mean(collect(skipmissing(X)))
end
function custom_sum(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return sum(collect(skipmissing(X)))
end
function custom_skew(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return skewness(collect(skipmissing(X)))
end
function custom_kurt(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return kurtosis(collect(skipmissing(X)))
end
function custom_perc(X, plevel)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return percentile(collect(skipmissing(X)), plevel)
end
function custom_max(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return maximum(collect(skipmissing(X)))
end
function custom_min(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    return minimum(collect(skipmissing(X)))
end
function custom_median(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))>0
        return median(collect(skipmissing(X)))
    else
        return missing
    end
end
myrounding =x->round(x;digits=2)