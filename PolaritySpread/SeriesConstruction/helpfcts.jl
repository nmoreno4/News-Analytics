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
function subperiodCol(crtdf, perlength, offset)
    let subperiod = 1
        rowcount = 1
        foo = @byrow! crtdf begin
            @newcol subperiod::Array{Int}
            if rowcount <= perlength*subperiod-offset
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








function sizeValRetSent(td, valR, sizeR, sentMeasure, storiescount, mongo_collection, wtvar, retvar)
    dayretvec = Float64[]
    daywtvec = Union{Float64, Missing}[]
    daysentvec = Union{Float64, Missing}[]
    dayStoriesCountvec = Union{Int64}[]
    for filtDic in mongo_collection[:find](Dict("td"=>td, "rankbm"=>Dict("\$gte"=>valR[1], "\$lte"=>valR[2]),
                                            "ranksize"=>Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])),
                                     Dict(wtvar=>1, retvar=>1, sentMeasure=>1, storiescount=>1))
        push!(dayretvec, filtDic[retvar])
        if typeof(filtDic[wtvar])==Float64
            push!(daywtvec, filtDic[wtvar])
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


# missingsum(x) = sum(skipmissing(x))
nonmissing(x) = !(ismissing(x))
function missingsum(x)
    if sum(nonmissing.(x))>0
        return sum(skipmissing(x))
    else
        return missing
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



function aggperiod(resDic, ptf, chosenvar, perlength, aggfunct, offset=0)
    if perlength>1
        if typeof(resDic)==Dict{Any,Any}
            resMat = replace_nan(subperiodCol(resDic[ptf][chosenvar], perlength, offset));
        elseif typeof(resDic)==DataFrame
            resMat = replace_nan(subperiodCol(resDic, perlength, offset));
        end
        resMat = aggregate(resMat, :subperiod, [aggfunct]);
    else
        if typeof(resDic)==Dict{Any,Any}
            resMat = replace_nan(resDic[ptf][chosenvar][(1+offset):end,:])
        else
            resMat = resDic
        end
    end
    return resMat
end


function sent_ret_series(sentMat, wMat, retMat, nbstoriesMat)
    try
        sentMat = replace_nan(convert(Array{Union{Float64, Missing},2}, convert(Array, sentMat) ./ convert(Array, nbstoriesMat)))
    catch
        print(size(sentMat))
        print("\n==\n")
        print(size(nbstoriesMat))
        error("custom: arrays could not be broadcast to a common size")
    end
    wMat = convert(Array, wMat)
    retMat = convert(Array, retMat)

    VWsent, coveredMktCp = weightsum(wMat, sentMat, "VW", false)
    VWret, coveredMktCp = weightsum(wMat, retMat, "VW", false)

    EWsent, coveredMktCp = weightsum(wMat, sentMat, "EW", true)
    EWret, coveredMktCp = weightsum(wMat, retMat, "EW", true)
    return VWsent, VWret, EWsent, EWret
end


function aggSeriesToDic!(aggseriesDic, resDic, ptfs, sentvar, nbstoriesvar, perlength, offset, wtvar="dailywt", retvar="dailyretadj")
    @time for crtptf in ptfs
        ptf = crtptf[1]
        print(ptf)
        sentMat = aggperiod(resDic, ptf, sentvar, perlength, missingsum, offset);
        nbstoriesMat = aggperiod(resDic, ptf, nbstoriesvar, perlength, missingsum, offset);
        wMat = aggperiod(resDic, ptf, wtvar, perlength, missingmean, 0);
        retMat = aggperiod(resDic, ptf, retvar, perlength, cumret, 0);
        #delete useless subperiod identifyier column
        if perlength>1
            for cdf in (sentMat, nbstoriesMat, wMat, retMat)
                delete!(cdf, :subperiod)
            end
        end
        #Compute the time series
        aggseriesDic["VWsent_$(ptf)"], aggseriesDic["VWret_$(ptf)"], aggseriesDic["EWsent_$(ptf)"], aggseriesDic["EWret_$(ptf)"] = sent_ret_series(sentMat, wMat, retMat, nbstoriesMat)
    end
    return aggseriesDic
end


function findSentColumns(mydf)
    sentidx, otheridx = Int[], Int[]
    for i in 1:length(names(mydf))
        if length(String(names(mydf)[i]))>5 && String(names(mydf)[i])[3:6]=="sent"
            push!(sentidx, i)
        else
            push!(otheridx, i)
        end
    end
    return sentidx, otheridx
end


function HMLspreads!(seriesDic)
    for WS in ["EW", "VW"]
        for var in ["ret", "sent"]
            seriesDic["$(WS)$(var)_H"] = (seriesDic["$(WS)$(var)_BH"].+seriesDic["$(WS)$(var)_SH"])/2
            seriesDic["$(WS)$(var)_L"] = (seriesDic["$(WS)$(var)_BL"].+seriesDic["$(WS)$(var)_SL"])/2
            seriesDic["$(WS)$(var)_HML"] = seriesDic["$(WS)$(var)_H"]-seriesDic["$(WS)$(var)_L"]
        end
    end
    return seriesDic
end


function idPtf(All_rets, ptf1Mat, ptf2Mat)
    All_ptf_ids = Array{Union{Missing,Float64},2}(undef, size(All_rets,1), size(All_rets,2))
    All_ptf_ids = convert(DataFrame, All_ptf_ids)
    names!(All_ptf_ids, names(All_rets))
    @time for row in 1:size(ptf1Mat,1)
        for col  in 1:size(ptf1Mat,2)
            if !ismissing(ptf1Mat[row,col])
                All_ptf_ids[names(ptf1Mat)[col]][row] = 1
            end
        end
    end
    @time for row in 1:size(ptf2Mat,1)
        for col  in 1:size(ptf2Mat,2)
            if !ismissing(ptf2Mat[row,col])
                All_ptf_ids[names(ptf2Mat)[col]][row] = 1
            end
        end
    end
    return All_ptf_ids
end


function countmissing(myIter,nonmissings)
    counter = 0
    for row in 1:size(myIter,1)
        for col in 1:size(myIter,2)
            if nonmissings && !ismissing(myIter[row,col])
                counter+=1
            elseif !nonmissings && ismissing(myIter[row,col])
                counter+=1
            end
        end
    end
    return counter
end



function constructRmatrix(finalSeriesDicBis, perlength, offset, finalSeriesDic, recentperiod)
    recentperiod = recentperiod/perlength
    foo = countmissing(finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"], true) #ACHTUNG: weird number of total observations (+18M vs 22M??)
    Rmatrix = Array{Union{Float64,Missing},2}(undef, foo, 23)
    let i=1
    for row in 1:size(finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"],1)
        print(row)
        for col in 1:size(finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"],2)
            if !ismissing(finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"][row, col])
                Rmatrix[i, 1] = col
                Rmatrix[i, 2] = row
                Rmatrix[i, 3] = finalSeriesDicBis["retadj_p$(perlength)_o$(offset)"][row, col]-finalSeriesDic["res_p$(perlength)_o$(offset)"][:RF][row]
                Rmatrix[i, 4] = finalSeriesDicBis["sent_p$(perlength)_o$(offset)"][row, col]
                row>1 ? Rmatrix[i, 5] = finalSeriesDicBis["sent_p$(perlength)_o$(offset)"][row-1, col] : Rmatrix[i, 5] = missing
                row>2 ? Rmatrix[i, 6] = finalSeriesDicBis["sent_p$(perlength)_o$(offset)"][row-2, col] : Rmatrix[i, 6] = missing
                Rmatrix[i, 7] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWret_HML][row]-finalSeriesDic["res_p$(perlength)_o$(offset)"][:RF][row]
                Rmatrix[i, 8] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWret_ALL][row]-finalSeriesDic["res_p$(perlength)_o$(offset)"][:RF][row]
                Rmatrix[i, 9] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_HML][row]
                Rmatrix[i, 10] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_ALL][row]
                Rmatrix[i, 11] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_H][row]
                Rmatrix[i, 12] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_L][row]
                row>1 ? Rmatrix[i, 13] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_H][row-1] : Rmatrix[i, 13] = missing
                row>1 ? Rmatrix[i, 14] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:VWsent_L][row-1] : Rmatrix[i, 14] = missing
                ismissing(finalSeriesDicBis["L_id_p$(perlength)_o$(offset)"][row, col]) ?  Rmatrix[i, 15] = 0 : Rmatrix[i, 15] = finalSeriesDicBis["L_id_p$(perlength)_o$(offset)"][row, col]
                ismissing(finalSeriesDicBis["H_id_p$(perlength)_o$(offset)"][row, col]) ?  Rmatrix[i, 16] = 0 : Rmatrix[i, 16] = finalSeriesDicBis["H_id_p$(perlength)_o$(offset)"][row, col]
                row>recentperiod ? Rmatrix[i, 17] = 1 : Rmatrix[i, 17] = 0
                Rmatrix[i, 18] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:SMB][row]
                Rmatrix[i, 19] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:HML][row]
                Rmatrix[i, 20] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:Mkt_RF][row]
                Rmatrix[i, 21] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:Mom][row]
                Rmatrix[i, 22] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:RMW][row]
                Rmatrix[i, 23] = finalSeriesDic["res_p$(perlength)_o$(offset)"][:CMA][row]
                i+=1
            end
        end
    end
    end #let block
    Rmatrix = convert(DataFrame, Rmatrix)
    names!(Rmatrix, [:permno, :td, :ret_i_t, :sent_i_t, :sent_i_tl1, :sent_i_tl2, :ret_HML_t,
                     :ret_Mkt_t, :sent_HML_t, :sent_Mkt_t, :sent_H_t, :sent_L_t, :sent_H_tl1,
                     :sent_L_tl1, :isL, :isH, :isRecent, :SMB, :HML, :Mkt_RF, :Mom, :RMW, :CMA])
    return Rmatrix
end


function regressionSessionR(Rmatrix)
    Hmatrix =  Rmatrix[replace(Rmatrix[:isH], missing=>0) .== 1.0, :];
    Lmatrix =  Rmatrix[replace(Rmatrix[:isH], missing=>0) .== 1.0, :];
    @rput Rmatrix;
    @rput Hmatrix;
    @rput Lmatrix;
    R"library(plm)";
    R"library(stargazer)";
    R"library(lmtest)";
    R"A <- plm::pdata.frame(Rmatrix, index=c('permno', 'td'))";
    R"H <- plm::pdata.frame(Hmatrix, index=c('permno', 'td'))";
    R"L <- plm::pdata.frame(Lmatrix, index=c('permno', 'td'))";
    return 0
end
