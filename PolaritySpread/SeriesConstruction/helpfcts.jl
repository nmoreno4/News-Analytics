using DataFrames

# Find the most frequent character appearing in a tuple of strings
function findFreqCharac(mytuple)
    a = [chr for str in mytuple for chr in str]
    return findmax(countmap(a))[2]
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
    return res
end



function mergeptf(dic1, dic2, mvar)
    foo = hcat(dic1[mvar],dic2[mvar])
    return vec(mapslices(mean, foo, dims = 2))
end




function marketptf(ptfDic, mvar)
    foo = hcat(ptfDic["SH"][mvar].*ptfDic["SH"]["wt"],ptfDic["BH"][mvar].*ptfDic["BH"]["wt"],
               ptfDic["SL"][mvar].*ptfDic["SL"]["wt"], ptfDic["BL"][mvar].*ptfDic["BL"]["wt"],
               ptfDic["M"][mvar].*ptfDic["M"]["wt"])
    weights = hcat(ptfDic["SH"]["wt"],ptfDic["BH"]["wt"],ptfDic["SL"]["wt"],ptfDic["BL"]["wt"])
    return vec(mapslices(sum, foo, dims = 2))./(vec(mapslices(sum, weights, dims = 2)))
end




function initptf(sentMeasure)
    if sentMeasure[1:3]!="dzi"
        return Dict{String,Array{Float64,1}}("VWret"=>Float64[], "EWret"=>Float64[],
                                           "VWsent"=>Float64[], "EWsent"=>Float64[], "wt"=>Float64[])
    else
        return Dict{String,Array{Float64,1}}("VWret"=>Float64[], "EWret"=>Float64[], "EWsumSent"=>Float64[],
                                             "VWsumSent"=>Float64[], "sumStories"=>Float64[], "wt"=>Float64[])
    end
end




function fillptf(valR, sizeR, sentMeasure = "spread_rel50nov3D_m", storiescount="nbStories_rel50nov24H", tdmax=100)
    ptfDict = initptf(sentMeasure)
    for td in 1:tdmax
        foo = sizeValRetSent(td, valR, sizeR, sentMeasure, storiescount)
        if sentMeasure[1:3]!="dzi"
            push!(ptfDict["VWret"], foo[1]); push!(ptfDict["EWret"], foo[2]); push!(ptfDict["VWsent"], foo[3])
            push!(ptfDict["EWsent"], foo[4]); push!(ptfDict["wt"], foo[5])
        else
            push!(ptfDict["VWret"], foo[1]); push!(ptfDict["EWret"], foo[2]); push!(ptfDict["EWsumSent"], foo[3])
            push!(ptfDict["VWsumSent"], foo[4]); push!(ptfDict["wt"], foo[5]); push!(ptfDict["sumStories"], foo[6])
        end
    end
    return ptfDict
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



function countNaN(crtDF, nonnan=false)
    NaNcount = [0]
    for r in 1:size(crtDF,1)
        for c in 1:size(crtDF,2)
            # Count values that are NaN
            if !nonnan && !(ismissing(crtDF[r,c])) && isnan(crtDF[r,c])
                NaNcount[1]+=1
            # Count values that are non-NaN
            elseif nonnan && !(ismissing(crtDF[r,c])) && !(isnan(crtDF[r,c]))
                NaNcount[1]+=1
            end
        end
    end
    return NaNcount[1]
end


"""
Adds a column to a Dataframe indicating the period of the row.
"""
function subperiodCol(crtdf, perlength)
    let subperiod = 1
        rowcount = 1
        foo = @byrow! crtdf begin
            @newcol subperiod::Array{Int}
            if rowcount <= perlength*subperiod
                :subperiod = subperiod
            else
                subperiod+=1
                :subperiod = subperiod
            end
            rowcount+=1
        end
        return foo
    end
end



function initDF(colnames, nbrows, coltype=Union{Missing, Float64}, defaultfill=missing)
    df1 = DataFrame()
    for colname in colnames
        df1[Symbol(colname)] = Array{coltype,1}(defaultfill, nbrows)
    end
    return df1
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
                                                "rankbm"=>bmfilter,
                                                "ranksize"=>sizefilter))[:distinct]("permno")

    #Create dataframes
    dfDict = Dict{String, DataFrame}()
    for queryVar in chosenVars
        dfDict[queryVar] = initDF(Int64.(uniquePermno), length(uniqueTd))
    end

    for td in tdperiods[1]:tdperiods[2]
        for filtDic in mongo_collection[:find](Dict("td"=>td,
                                                    "rankbm"=>bmfilter,
                                                    "ranksize"=>sizefilter),
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








function sizeValRetSent(td, valR, sizeR, sentMeasure, storiescount, mongo_collection)
    dayretvec = Float64[]
    daywtvec = Union{Float64, Missing}[]
    daysentvec = Union{Float64, Missing}[]
    dayStoriesCountvec = Union{Int64}[]
    for filtDic in mongo_collection[:find](Dict("td"=>td, "rankbm"=>Dict("\$gte"=>valR[1], "\$lte"=>valR[2]),
                                            "ranksize"=>Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])),
                                     Dict("wt"=>1, "dailyretadj"=>1, sentMeasure=>1, storiescount=>1))
        push!(dayretvec, filtDic["dailyretadj"])
        if typeof(filtDic["wt"])==Float64
            push!(daywtvec, filtDic["wt"])
        else
            push!(daywtvec, missing)
        end
        if haskey(filtDic, sentMeasure)
            push!(daysentvec, filtDic[sentMeasure])
        else
            push!(daysentvec, missing)
        end
        if haskey(filtDic, storiescount)
            push!(dayStoriesCountvec, filtDic[storiescount])
        else
            push!(dayStoriesCountvec, 0)
        end
    end
    VWret = sum(skipmissing(dayretvec.*daywtvec))/sum(skipmissing(daywtvec))
    EWret = mean(dayretvec)
    if sentMeasure[1:3]!="dzi"
        EWsent = mean(skipmissing(daysentvec))
        VWsent = sum(skipmissing(daysentvec.*daywtvec))/sum(skipmissing(daywtvec))
        return (VWret, EWret, EWsent, VWsent, sum(skipmissing(daywtvec)))
    else
        EWsumSent = sum(skipmissing(daysentvec))
        VWsumSent = sum(skipmissing( daysentvec.*( (daywtvec./sum(skipmissing(daywtvec)))*length(collect(skipmissing(daywtvec))) ) ))
        sumStories = sum(skipmissing(dayStoriesCountvec))
        return (VWret, EWret, EWsumSent, VWsumSent, sum(skipmissing(daywtvec)), sumStories)
    end
end


missingsum(x) = sum(skipmissing(x))
nonmissing(x) = !(ismissing(x))
function missingmean(x)
    try
        return mean(skipmissing(x))
    catch
        missing
    end
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
            a = Array{Float64,1}(a[findall(nonmissing,a)])
        end #if only use non-missing values
        push!(res, sum(a))
        push!(coveredMktCp, missingsum(wrow[findall(nonmissing,srow)]./missingsum(wrow)))
    end #for row
    return res, coveredMktCp
end


function dfColSum(crtDF)
    res = Array{Union{Missing,Float64},1}(missing, size(crtDF, 2))
    for col in 1:size(crtDF, 2)
        res[col] = sum(skipmissing(crtDF[:,col]))
    end
    return res
end
