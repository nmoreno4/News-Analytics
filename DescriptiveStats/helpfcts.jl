using RCall, Statistics, StatsBase, TimeZones, Dates, RollingFunctions, DataFramesMeta
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
                    filtDic[var] = missing
                end
            end
            resDic["$(td)_$(filtDic["permno"])"] = Array{Union{Missing, Float64}}(missing,length(chosenVars)+2)
            i=0
            for var in chosenVars
                i+=1
                try
                    resDic["$(td)_$(filtDic["permno"])"][i] = filtDic[var]
                catch myerr
                    if myerr isa MethodError && filtDic[var] == nothing
                        resDic["$(td)_$(filtDic["permno"])"][i] = missing
                    end
                end
            end
            resDic["$(td)_$(filtDic["permno"])"][i+1] = filtDic["permno"]
            resDic["$(td)_$(filtDic["permno"])"][i+2] = td
        end
    end
    return resDic
end



function transposeDF(df)
    varsToStack = names(df)
    df[:id] = 1:size(df, 1)
    dfl = stack(df, varsToStack)
    dfnew = unstack(dfl, :variable, :id, :value)
    return dfnew
end


function queryDic_to_df(a, keylabels)
    b = DataFrame(a)
    b = transposeDF(b)
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
function custom_mean(X, retval=1)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==1
        return retval
    else
        return mean(collect(skipmissing(X)))
    end
end
function custom_mean_missing(X, retval=missing)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==1
        return retval
    else
        return mean(collect(skipmissing(X)))
    end
end
function custom_sum(X, retval=0)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==0
        return retval
    else
        return sum(collect(skipmissing(X)))
    end
end
function custom_sum_missing(X, retval=missing)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    if length(collect(skipmissing(X)))==0 && retval!==0
        return retval
    else
        return sum(collect(skipmissing(X)))
    end
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
    try
        return maximum(collect(skipmissing(X)))
    catch
        return missing
    end
end
function custom_min(X)
    X = replace(X, missing=>NaN, nothing=>NaN)
    X = replace(X, NaN=>missing)
    X = convert(Array{Union{Float64,Missing}}, X)
    try
        return minimum(collect(skipmissing(X)))
    catch
        return missing
    end
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
myrounding = x->round(x;digits=2)
getlast = x->x[end]




function df_custom_summary(dicDFs, ptfIDs, isindustries = false)
    repDF = Dict("indus"=>[], "vol"=>[], "bm"=>[], "me"=>[], "ret"=>[], "nNews_S"=>[], "sent"=>[],
                 "nbobs"=>[], "nPobs"=>[], "sentSTD"=>[], "sentSKEW"=>[], "sentKURT"=>[], "sentMED"=>[],
                 "sent_all"=>[], "nbStories_all"=>[], "nbStoriesMAX_stock"=>[], "nbStoriesMIN_stock"=>[],
                 "nbStoriesSTD_stock"=>[])
    for id in ptfIDs
        print(id)
        if isindustries
            id = id[1]
        end
        a = by(dicDFs[id], :permno) do df
            DataFrame(vol = custom_mean(df.vol), bm = custom_mean(df.bm), ret = custom_mean(df.dailyretadj),
                      me = custom_mean(df.me), nbStories = custom_sum(df.nbStories_rel100_nov24H),
                      sent = custom_mean(df.sent_rel100_nov24H), nbobs = length(df.dailyretadj),
                      sentSTD = custom_std(df.sent_rel100_nov24H), sentSKEW = custom_skew(df.sent_rel100_nov24H),
                      sentKURT = custom_kurt(df.sent_rel100_nov24H), sentMED = custom_median(df.sent_rel100_nov24H),
                      newsPerObs = custom_sum(df.nbStories_rel100_nov24H)/length(df.dailyretadj))
        end
        push!(repDF["indus"], id)
        push!(repDF["vol"], round(custom_mean(a[:vol]);digits=0))
        push!(repDF["bm"], round(custom_mean(a[:bm]);digits=2))
        push!(repDF["me"], round(custom_mean(a[:me]);digits=0))
        push!(repDF["ret"], round(((custom_mean(a[:ret])+1)^252-1)*100;digits=2))
        push!(repDF["nNews_S"], round(custom_mean(a[:nbStories]);digits=0))
        push!(repDF["sent"], round(custom_mean(a[:sent]);digits=2))
        push!(repDF["nbobs"], round(custom_sum(a[:nbobs]);digits=0))
        push!(repDF["nPobs"], round(custom_mean(a[:newsPerObs]);digits=2))
        push!(repDF["sentSTD"], round(custom_mean(a[:sentSTD]);digits=2))
        push!(repDF["sentSKEW"], round(custom_mean(a[:sentSKEW]);digits=2))
        push!(repDF["sentKURT"], round(custom_mean(a[:sentKURT]);digits=2))
        push!(repDF["sentMED"], round(custom_median(dicDFs[id][:sent_rel100_nov24H]);digits=2))
        push!(repDF["sent_all"], round(custom_mean(dicDFs[id][:sent_rel100_nov24H]);digits=2))
        push!(repDF["nbStories_all"], round(custom_sum(dicDFs[id][:nbStories_rel100_nov24H]);digits=2))
        push!(repDF["nbStoriesMAX_stock"], round(custom_max(a[:nbStories]);digits=0))
        push!(repDF["nbStoriesMIN_stock"], round(custom_min(a[:nbStories]);digits=0))
        push!(repDF["nbStoriesSTD_stock"], round(custom_std(a[:nbStories]);digits=0))
    end
    repDF = DataFrame(repDF)
    repDF = repDF[[:indus, :nNews_S, :sent, :me, :bm, :ret, :vol, :nbobs, :nPobs, :sentSTD, :sentSKEW,
                   :sentKURT, :sentMED, :sent_all, :nbStories_all, :nbStoriesMAX_stock, :nbStoriesMIN_stock,
                   :nbStoriesSTD_stock]]
    return repDF
end



function custom_corr_mat(dicDFs, ptfIDs)
    corrdic = Dict()
    for id in ptfIDs
        corrdic[id] = by(dicDFs[id], :td) do df
            DataFrame(sent = custom_mean(df.sent_rel100_nov24H))
        end
    end
    for id in corrdic
        corrdic[id[1]] = sort(id[2], :td)
    end
    corrmat = ones(length(ptfIDs),length(ptfIDs))
    corrmat = DataFrame(corrmat)
    names!(corrmat, [Symbol(x) for x in ptfIDs])
    for i in ptfIDs
        row = 0
        for j in ptfIDs
            row+=1
            corrmat[Symbol(i)][row] = cor(replace_nan(corrdic[i][:sent], 0), replace_nan(corrdic[j][:sent], 0))
        end
    end
    return corrmat
end


function ret2tick(vec, val=100)
    res = Float64[val]
    for i in vec
        if ismissing(i)
            i=0
        end
        val*=(1+i)
        push!(res, val)
    end
    return res
end

function cumret(vec)
    prices = ret2tick(vec)
    res = (prices[end]-prices[1])/prices[1]
    if length(vec)>0
        return res
    else
        return missing
    end
end


function add_per_id!(b, tdpers, skippedpers=0)
    b[:perid] = ones(length(b[:td]))
    let w=1
    for i in 1:length(b[:td])
        if b[:td][i]<=tdpers[w]
            b[:perid][i] = w+skippedpers
        else
            w+=1
            b[:perid][i] = w+skippedpers
        end
    end
    end
    return b
end


function endPerIdx(freq = Dates.quarterofyear, startperiod=1, endperiod=3776) #week, month
    datesvec = datesVec()
    periodchange = map(x->freq(x), datesvec[startperiod+1:endperiod])-map(x->freq(x), datesvec[startperiod:endperiod-1])
    islastdayofperiod = map(x->x!=0, [periodchange;1])
    return findall(islastdayofperiod)
end


function aggperiod(DFs, operationsDic, newstopics, freq = Dates.quarterofyear, startperiod=1, endperiod=3776)
    ptfaggper = Dict()
    for i in operationsDic
        for j in i[2][2]
            ptfaggper[j] = []
        end
    end
    for top in newstopics
        ptfaggper[Symbol("aggSent_$(top)")] = []
    end
    ptfaggper = DataFrame(ptfaggper)
    orignames = Symbol[]
    newnames = Symbol[]
    if freq==Dates.day
        for opDic in operationsDic
            for i in 1:length(operationsDic[opDic[1]][2])
                crtcolname = operationsDic[opDic[1]][2][i]
                crtorigVar = operationsDic[opDic[1]][3][i]
                if crtorigVar != :perid
                    push!(orignames, crtorigVar)
                    push!(newnames, crtcolname)
                else
                    push!(orignames, :td)
                    push!(newnames, :perid)
                end
            end
        end
        b = DFs[orignames]
        names!(b, newnames)
        for top in newstopics
            b[Symbol("aggSent_$(top)")] = replace_nan(convert(Array{Union{Float64, Missing}}, b[Symbol("sum_perSent_$(top)")] ./ b[Symbol("sum_perNbStories_$(top)")]), missing)
        end
        ptfaggper = b
    end

    # ptfaggper = DataFrame(permno=[], perid=[], persent=[], pernbstories=[], cumret=[], EAD=[], wt=[], aggSent=[])
    if freq != Dates.day
        tdpers = endPerIdx(freq, startperiod, endperiod)
        for permno in Set(DFs[:permno])
            b = @where(DFs, :permno .== permno)
            sort!(b, :td)
            starttdpers = 1
            for i in tdpers
                if minimum(b[:td])<i
                    break
                end
                starttdpers+=1
            end
            endtdpers = length(tdpers)
            addmax = false
            for i in length(tdpers)-1:1
                if maximum(b[:td])>=tdpers[i]
                    if maximum(b[:td])==tdpers[i]
                        break
                    else
                        addmax = true
                    end
                end
                endtdpers-=1
            end
            if addmax
                crttdpers = [tdpers[starttdpers:endtdpers];maximum(b[:td])]
            else
                crttdpers = tdpers[starttdpers:endtdpers]
            end
            b = add_per_id!(b, crttdpers, starttdpers-1)


            # changesinperid = perchangerows(b[:perid])
            # for j in 2:length(changesinperid)
            #     res = Dict()
            #     for opDic in operationsDic
            #         for i in 1:length(operationsDic[opDic[1]][2])
            #             crtfct = operationsDic[opDic[1]][1]
            #             crtcolname = operationsDic[opDic[1]][2][i]
            #             crtorigVar = b[j-1:j, operationsDic[opDic[1]][3][i]]
            #             res[crtcolname] = crtfct(crtorigVar)
            #         end
            #     end
            #     for top in newstopics
            #         res[Symbol("aggSent_$(top)")] = custom_replace_nan(convert(Union{Float64, Missing}, res[Symbol("sum_perSent_$(top)")] / res[Symbol("sum_perNbStories_$(top)")]), missing)
            #     end
            #     ptfaggper = vcat(ptfaggper, DataFrame(res))
            # end


            # for crtperid in Set(b[:perid])
            #     cdf = @where(b, :perid .== crtperid)
            #     res = Dict()
            #     for opDic in operationsDic
            #         for i in 1:length(operationsDic[opDic[1]][2])
            #             crtfct = operationsDic[opDic[1]][1]
            #             crtcolname = operationsDic[opDic[1]][2][i]
            #             crtorigVar = cdf[operationsDic[opDic[1]][3][i]]
            #             res[crtcolname] = crtfct(crtorigVar)
            #         end
            #     end
            #     aggper = DataFrame(res)
            #     for top in newstopics
            #         aggper[Symbol("aggSent_$(top)")] = replace_nan(convert(Array{Union{Float64, Missing}}, aggper[Symbol("sum_perSent_$(top)")] ./ aggper[Symbol("sum_perNbStories_$(top)")]), missing)
            #     end
            #     ptfaggper = vcat(ptfaggper, aggper)
            # end


            aggper = by(b, :perid) do df
                res = Dict()
                for opDic in operationsDic
                    for i in 1:length(operationsDic[opDic[1]][2])
                        res[operationsDic[opDic[1]][2][i]] = operationsDic[opDic[1]][1](df[operationsDic[opDic[1]][3][i]])
                    end
                end
                DataFrame(res)
                # DataFrame(permno=minimum(df.permno), persent = custom_sum(df.sent_rel100_nov24H, missing), pernbstories = custom_sum(df.nbStories_rel100_nov24H),
                #           cumret = cumret(df.dailyretadj), EAD = custom_max(df.EAD), wt = df.dailywt[end], perid = mean(df.perid))
            end
            delete!(aggper, :perid_1)
            for top in newstopics
                aggper[Symbol("aggSent_$(top)")] = replace_nan(convert(Array{Union{Float64, Missing}}, aggper[Symbol("sum_perSent_$(top)")] ./ aggper[Symbol("sum_perNbStories_$(top)")]), missing)
            end
            ptfaggper = vcat(ptfaggper, aggper)

        end
    end #if not daily
    return ptfaggper
end


function perchangerows(peridvec)
    oldper = Int(0)
    ids = Int[]
    row = 0
    for i in peridvec
        row+=1
        if i>oldper
            push!(ids, row)
            oldper = i
        end
    end
    return ids
end




function EW_VW_series(aggDF, newcols, symbs, wt=:wt, perSymb=:perid)
    wtSUM = by(aggDF, perSymb) do df
        DataFrame(wtSUM = custom_sum(df[:wt]))
    end
    wtSUM=Dict(zip(wtSUM[perSymb], wtSUM[:wtSUM]))
    # print(@with(aggDF, cols(sentSymb) + cols(wt)))
    for ncol in newcols
        aggDF[ncol] = Array{Union{Float64,Missing}}(missing, length(aggDF[perSymb]))
    end
    df2 = @byrow! aggDF begin
        @newcol wtSUM::Array{Union{Float64,Missing}}
        :wtSUM = wtSUM[:perid]
    end
    for (symb, coln) in zip(symbs, newcols)
        df2[coln] = @with(df2, cols(symb) .* (cols(wt) ./ cols(:wtSUM)) )
    end
    resDF = by(df2, perSymb) do df
        res = Dict()
        for (symb, coln) in zip(symbs, newcols)
            res[Symbol("VW_$(symb)")] = custom_sum_missing(df[coln])
            res[Symbol("EW_$(symb)")] = custom_mean_missing(df[symb])
        end
        DataFrame(res)
    end
    delete!(aggDF, newcols)
    sort!(resDF, perSymb)
    return resDF
    # return resDF[[:perid, :VWsent, :VWret, :VWcov, :EWsent, :EWret, :EWcov]]
end


function maptd_per(freq, startperiod=1, endperiod=3776)
    datesvec = datesVec()
    periodchange = map(x->freq(x), datesvec[startperiod+1:endperiod])-map(x->freq(x), datesvec[startperiod:endperiod-1])
    islastdayofperiod = map(x->x!=0, [periodchange;1])
    tdper = Dict()
    let per = 1
    for d in 1:endperiod-startperiod+1
        if islastdayofperiod[d]
            tdper[per] = d
            per+=1
        end
    end
    end
    return tdper
end




function add_aroundEAD!(ptfDF, around_EAD)
    ptfDF[Symbol("aroundEAD$(around_EAD)")] = Array{Union{Float64,Missing}}(missing, length(ptfDF[:EAD]))
    for subdf in groupby(ptfDF, :permno)
        a = replace(subdf[:EAD], missing=>0)
        b = convert(Array{Bool}, replace(subdf[:EAD], missing=>false, 1=>true))
        furthestLag = [abs.(a[1:end-abs(minimum(collect(around_EAD)))]-a[abs(minimum(collect(around_EAD)))+1:end]); [0 for x in 1:abs(minimum(collect(around_EAD)))]]
        furthestLag[findall(b)] .= 0
        furthestLag = replace(runmax(furthestLag, maximum(collect(around_EAD))-minimum(collect(around_EAD))+1 ), 0=>missing)
        subdf[Symbol("aroundEAD$(around_EAD)")] = furthestLag
    end
    return ptfDF
end


function custom_replace_nan(x, replacevalue=missing)
    if isnan(x)
        return replacevalue
    else
        return x
    end
end




function addEvents(aggDF, freq, tdperiods, eventWindows, ptf)
    tdper = maptd_per(freq, tdperiods[1], tdperiods[2])
    ranges = Dict()
    revertranges = Dict()
    for eventwindow in eventWindows
        ranges[eventwindow[1]] = Dict()
        for ewSpec in eventwindow[2]
            ranges[eventwindow[1]][ewSpec] = Dict()
            for i in aggDF[:perid]
                ranges[eventwindow[1]][ewSpec][i] = tdper[i]+eventwindow[1][1]:tdper[i]+eventwindow[1][2]
                revertranges[tdper[i]+eventwindow[1][2]] = i
            end
        end
    end
    for window in ranges
        ws = window[1][2]-window[1][1]
        for vars in window[2]
            aggDF[Symbol("$(window[1])_$(vars[1])")] = Array{Union{Missing, Float64},1}(missing, length(aggDF[:perid]))
            if typeof(vars[1])==Symbol
                quintileDFs[ptf][Symbol("$(window[1])_$(vars[1])")] = running(cumret, quintileDFs[ptf][vars[1]], ws)
            elseif length(vars[1])==2
            end
        end
    end
    sort!(aggDF, [:permno, :perid])
    sort!(quintileDFs[ptf], [:permno, :td])
    togetperid = by(aggDF, :permno) do df
        res = Dict()
        res[:perid] = df[:perid]
        DataFrame(res)
    end
    aggpermnoperid = agg_permno_perid_barrier(togetperid[:permno], togetperid[:perid])
    @time aggper = by(quintileDFs[ptf], :permno) do df
        alltd = convert(Array{Union{Int64, Missing}}, collect(tdperiods[1]:tdperiods[2]))
        #add missing to alltd
        alltd = findnotcommondates(alltd, df[:td])
        res = Dict()
        vecWmissing = Dict()
        for window in ranges
            for vars in window[2]
                if typeof(vars[1])==Symbol
                    vecWmissing[vars[1]] = returnswithmissing(df[vars[1]], alltd, df[:td])
                elseif length(vars[1])==2
                    for sousvar in vars[1]
                        vecWmissing[sousvar] = returnswithmissing(df[sousvar], alltd, df[:td])
                    end
                end
            end
            break #only need to consider vars once
        end
        for window in ranges
            ws = window[1][2]-window[1][1]
            for vars in window[2]
                if typeof(vars[1])==Symbol
                    runningvar = running(cumret, vecWmissing[vars[1]], ws)
                elseif length(vars[1])==2
                    runningvar = convert(Array{Union{Float64, Missing}}, running(custom_sum_missing, vecWmissing[vars[1][1]], ws) ./ running(custom_sum, vecWmissing[vars[1][2]], ws)) #Careful: order sentiment -> nbStories matters
                end
                eventrows = assign_eventdate_barrier(aggpermnoperid[df[:permno][1]], vars[2], length(runningvar), ws)
                try
                    push!(runningvar, missing)
                    res[Symbol("$(window[1])_$(vars[1])")] = runningvar[eventrows]
                catch err
                    # error(err)
                    error("er $eventrows - rv $(countmissing(runningvar)) - wd $(window[1]) - vs $(vars[2][1]) + $(vars[2][123]) - pid $(aggpermnoperid[df[:permno][1]]) - lrv $(length(runningvar)) - ws $ws")
                end
            end
        end
        DataFrame(res)
    end
    aggDF = hcat(aggDF, aggper)
    return aggDF
end


function assign_eventdate_barrier(peridvec, ranges, tdlimit, ws)
    res = Array{Union{Missing, Int64},1}(missing, length(peridvec))
    for i in 1:length(res)
        desiredid = ranges[peridvec[i]]
        if maximum(desiredid)>=tdlimit && maximum(desiredid)-tdlimit>=ws
            res[i] = tdlimit+1
        elseif maximum(desiredid)>=tdlimit && maximum(desiredid)-tdlimit<ws
            res[i] = tdlimit
        elseif maximum(desiredid)<=0
            res[i] = tdlimit+1
        else
            res[i] = maximum(desiredid)
        end
        # print("\n $([maximum(desiredid), tdlimit]) \n")
    end
    return res
end


function agg_permno_perid_barrier(permnovec, peridvec)
    res = Dict()
    for permno in Set(permnovec)
        res[permno] = Int[]
    end
    for i in 1:length(peridvec)
        push!(res[permnovec[i]], peridvec[i])
    end
    return res
end



function findnotcommondates(alltd, chosentd)
    j=1
    for i in 1:length(alltd)
        if j<=length(chosentd) && alltd[i]==chosentd[j]
            j+=1
        else
            alltd[i]=missing
        end
    end
    return alltd
end


function findminperid(revertranges, mintd, eventspan)
    for i in 0:eventspan
        print(i)
        if mintd in collect(keys(revertranges)).+i
            return revertranges[mintd]
        end
    end
end



function returnswithmissing(dataseries, alltd, seriestd)
    res = Array{Union{Missing, Float64},1}(missing, length(alltd))
    j=1
    for i in 1:length(alltd)
        if !(ismissing(alltd[i])) && alltd[i]==seriestd[j]
            res[i] = dataseries[j]
            j+=1
        end
    end
    return res
end



function rollingdiff(X, d)
    res = Float64[]
    for i in 1:(length(X)-d)
        push!(res, X[i+d]-X[i])
    end
    return res
end
