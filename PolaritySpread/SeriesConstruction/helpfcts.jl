# Find the most frequent character appearing in a tuple of strings
function findFreqCharac(mytuple)
    a = [chr for str in mytuple for chr in str]
    return findmax(countmap(a))[2]
end

function ret2tick(vec, val=100)
    res = Float64[]
    for i in vec
        val*=(1+i)
        push!(res, val)
    end
    return res
end

function mergeptf(dic1, dic2, mvar)
    foo = hcat(dic1[mvar],dic2[mvar])
    return vec(mapslices(mean, foo, dims = 2))
end

function marketptf(mvar)
    foo = hcat(SH[mvar].*SH["wt"],BH[mvar].*BH["wt"], SL[mvar].*SL["wt"],BL[mvar].*BL["wt"], M[mvar].*M["wt"])
    weights = hcat(SH["wt"],BH["wt"],SL["wt"],BL["wt"],M["wt"])
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

function sizeValRetSent(td, valR, sizeR, sentMeasure, storiescount)
    dayretvec = Float64[]
    daywtvec = Union{Float64, Missing}[]
    daysentvec = Union{Float64, Missing}[]
    dayStoriesCountvec = Union{Int64}[]
    for filtDic in collection[:find](Dict("td"=>td, "rankbm"=>Dict("\$gte"=>valR[1], "\$lte"=>valR[2]),
                                            "ranksize"=>Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])))
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
