##################################################################
# Load data
##################################################################
using PyCall, StatsBase, Statistics, RCall, DataFrames, JLD2

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/DescriptiveStats/helpfcts.jl")
phase = "save"



################# Block 1A ############################################
# a/ Compute the sensitivity of each ptf to NS(HML)
# b/ Compute the sensitivity of each ptf to NS(HML), only for returns
#    and sentiments falling around an EAD.
# - Use always the 2x3 HML sentiment
# - Use 10x10, 5x5 and 2x3 portfolio returns
#######################################################################

if phase=="save"
    JLD2.@load "/home/nicolas/Data/bmszdecile.jld2"
    JLD2.@load "/home/nicolas/Data/HMLDic.jld2"
    JLD2.@load "/home/nicolas/Data/quintileDic.jld2"
    # JLD2.@load "/home/nicolas/Data/MktDic.jld2"
    ptf2x3 = @time HMLspread(HMLDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false)
    ptf2x3EAD = @time HMLspread(HMLDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true)
    ptf2x3 = keepSeriesOnly!(ptf2x3)
    ptf2x3EAD = keepSeriesOnly!(ptf2x3EAD)
    ptf2x3 = HMLspread!(ptf2x3)
    ptf2x3EAD = HMLspread!(ptf2x3EAD)
    specs10x10 = specsids(10)
    ptf10x10 = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false, specs10x10)
    ptf10x10EAD = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true, specs10x10)
    ptf10x10 = keepSeriesOnly!(ptf10x10)
    ptf10x10EAD = keepSeriesOnly!(ptf10x10EAD)
    specs5x5 = specsids(5)
    ptf5x5 = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], [], false, false, specs5x5)
    ptf5x5EAD = @time HMLspread(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], -1:1, false, true, specs5x5)
    ptf5x5 = keepSeriesOnly!(ptf5x5)
    ptf5x5EAD = keepSeriesOnly!(ptf5x5EAD)
    JLD2.@save "/home/nicolas/Data/ptf2x3.jld2" ptf2x3
    JLD2.@save "/home/nicolas/Data/ptf2x3EAD.jld2" ptf2x3EAD
    JLD2.@save "/home/nicolas/Data/ptf10x10.jld2" ptf10x10
    JLD2.@save "/home/nicolas/Data/ptf10x10EAD.jld2" ptf10x10EAD
    JLD2.@save "/home/nicolas/Data/ptf5x5.jld2" ptf5x5
    JLD2.@save "/home/nicolas/Data/ptf5x5EAD.jld2" ptf5x5EAD
elseif phase=="load"
    JLD2.@load "/home/nicolas/Data/ptf2x3.jld2"
    JLD2.@load "/home/nicolas/Data/ptf2x3EAD.jld2"
    JLD2.@load "/home/nicolas/Data/ptf10x10.jld2"
    JLD2.@load "/home/nicolas/Data/ptf10x10EAD.jld2"
    JLD2.@load "/home/nicolas/Data/ptf5x5.jld2"
    JLD2.@load "/home/nicolas/Data/ptf5x5EAD.jld2"
end


βmat = ones(10,10)
for val in 1:10
    for sz in 1:10
        βmat[val,sz] = formatRegR(RsimpleReg(ptf10x10[val*100+sz]["VWret"], ptf2x3["HMLsent"]))["β1_t-val"]
    end
end
Rheatmap(βmat, "Sentiment level of RES news", 9);


βmatEAD = ones(10,10)
for val in 1:10
    for sz in 1:10
        βmatEAD[val,sz] = formatRegR(RsimpleReg(ptf10x10EAD[val*100+sz]["VWret"], ptf2x3["HMLsent"]))["β1_t-val"]
    end
end
Rheatmap(βmatEAD, "Sentiment level of RES news", 9);

βmat2x3 = ones(3,2)
vsind = [0,0]
for val in [(1,3), (4,7), (8,10)]
    vsind[1]+=1
    vsind[2]=0
    for sz in [(1,5), (6,10)]
        vsind[2]+=1
        βmat2x3[vsind[1],vsind[2]] = formatRegR(RsimpleReg(ptf2x3EAD[[val, sz]]["VWret"], ptf2x3["HMLsent"]))["β1_t-val"]
    end
end
Rheatmap(βmat2x3, "Sentiment level of RES news", 9);

βmatEAD2x3 = ones(3,2)
vsind = [0,0]
for val in [(1,3), (4,7), (8,10)]
    vsind[1]+=1
    vsind[2]=0
    for sz in [(1,5), (6,10)]
        vsind[2]+=1
        βmatEAD2x3[vsind[1],vsind[2]] = formatRegR(RsimpleReg(ptf2x3EAD[[val, sz]]["VWret"], ptf2x3["HMLsent"]))["β1_t-val"]
    end
end
Rheatmap(βmatEAD2x3, "Sentiment level of RES news", 9);


foo = formatRegR(RsimpleReg(ptf10x10[202]["VWret"], ptf2x3["HMLsent"]))
foo = formatRegR(RsimpleReg(ptf10x10EAD[202]["VWret"], ptf2x3["HMLsent"]))
foo = formatRegR(RsimpleReg(ptf2x3EAD[[(1,3), (6,10)]]["VWret"], ptf2x3EAD["HMLsent"]))
foo = formatRegR(RsimpleReg(ptf2x3EAD[[(1,3), (1,5)]]["VWret"], ptf2x3EAD["HMLsent"]))

Rplot(ptf2x3EAD["HMLret"], true)
ptf2x3["HMLret"]


################# Block 1B ############################################
# Same as Block 1A, but aggregating, weekly, monthly and quarterly.
#######################################################################




################# Block 2 ######################################################
# 1/ Filter for news falling around EAD (0, -1:1 and -5:1)
# 2/ Filter for news NOT falling around those EAD (0, -1:1 and -5:1)
# 3/ Do the filter for both all news categories and only RES news
# 4/ Create double entry matrix (Size/BM) of either:
#       a) the sentiment level of the filtered data (compVec = 1)
#       b) the difference in sentiment  between opposing filters (1/ vs. 2/)
#       c) the number of news of the filtered data (news coverage) (compVec = 3)
#       d) the difference in news coverage between opposing filters (1/ vs. 2/)
#################################################################################
chosenSplit = resDic
filtEADmats = Dict()
for filttype in [(0, true)]#, (0, false), (-1:1, true), (-1:1, false), (-5:1, true), (-5:1, false)]
    @time filtEADmats[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H", "nbStories_rel100_nov24H", [0,100], filttype[1], filttype[2])
end
# JLD2.@save "/home/nicolas/Data/mbszdeciles_filtEADmats.jld2" filtEADmats
filtEADmatsRES = Dict()
for filttype in [(0, true), (0, false), (-1:1, true), (-1:1, false), (-5:1, true), (-5:1, false)]
    @time filtEADmatsRES[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H_RES", "nbStories_rel100_nov24H_RES", [0,100], filttype[1], filttype[2])
end
# JLD2.@save "/home/nicolas/Data/mbszdeciles_filtEADmatsRES.jld2" filtEADmatsRES
filtEADmatsRES[0] = 0
filtEADmats[0] = 0

JLD2.@load "/home/nicolas/Data/mbszdeciles_filtEADmats.jld2"
JLD2.@load "/home/nicolas/Data/mbszdeciles_filtEADmatsRES.jld2"
chosenDic = "resDic"
allSplits = Dict()
allSplits["$(chosenDic)_ALL_sent"] = Dict()
for filtpair in [[(0, true), (0, false)], [(-1:1, true), (-1:1, false)], [(-5:1, true), (-5:1, false)], [(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]
    allSplits["$(chosenDic)_ALL_sent"][filtpair] = valszCondMeanEAD(filtEADmats[filtpair[1]], filtEADmats[filtpair[2]])
end
allSplits["$(chosenDic)_RES_sent"] = Dict()
for filtpair in [[(0, true), (0, false)], [(-1:1, true), (-1:1, false)], [(-5:1, true), (-5:1, false)], [(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]
    allSplits["$(chosenDic)_RES_sent"][filtpair] = valszCondMeanEAD(filtEADmatsRES[filtpair[1]], filtEADmatsRES[filtpair[2]])
end
allSplits["$(chosenDic)_ALL_cov"] = Dict()
for filtpair in [[(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]
    allSplits["$(chosenDic)_ALL_cov"][filtpair] = valszCondMeanEAD(filtEADmats[filtpair[1]], filtEADmats[filtpair[2]], 3)
end
allSplits["$(chosenDic)_RES_cov"] = Dict()
for filtpair in [[(0, true), 0], [(0, false), 0], [(-1:1, true), 0], [(-1:1, false), 0], [(-5:1, true), 0], [(-5:1, false), 0]]
    allSplits["$(chosenDic)_RES_cov"][filtpair] = valszCondMeanEAD(filtEADmatsRES[filtpair[1]], filtEADmatsRES[filtpair[2]], 3)
end
filtpair = [(0, true), (0, true)]
allSplits["$(chosenDic)_RES_relcov"] = Dict()
allSplits["$(chosenDic)_RES_relcov"][filtpair] = valszCondMeanEAD(filtEADmatsRES[filtpair[1]], filtEADmatsRES[filtpair[2]], [3,4])
Rheatmap(allSplits["$(chosenDic)_RES_relcov"][filtpair], "Sentiment level of RES news", 9);
filtpair = [(0, true), (0, true)]
allSplits["$(chosenDic)_ALL_relcov"] = Dict()
allSplits["$(chosenDic)_ALL_relcov"][filtpair] = valszCondMeanEAD(filtEADmats[filtpair[1]], filtEADmats[filtpair[2]], [3,4])
Rheatmap(allSplits["$(chosenDic)_ALL_relcov"][filtpair], "Sentiment level of RES news", 9);



#Condition on polarity

filtPolEADmats = Dict()
for filttype in [([], false, [0,20]), ([], false, [0,100]), ([], false, [80,100]), ([], false, [-1,0])]
    @time filtPolEADmats[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H", "nbStories_rel100_nov24H", filttype[3], filttype[1], filttype[2])
end
JLD2.@save "/home/nicolas/Data/mbszdeciles_filtPolEADmats.jld2" filtPolEADmats
filtPolEADmatsRES = Dict()
for filttype in [([], false, [0,20]), ([], false, [0,100]), ([], false, [80,100]), ([], false, [-1,0])]
    @time filtPolEADmatsRES[filttype] = EADfiltmat(chosenSplit, "sent_rel100_nov24H_RES", "nbStories_rel100_nov24H_RES", filttype[3], filttype[1], filttype[2])
end
JLD2.@save "/home/nicolas/Data/mbszdeciles_filtPolEADmatsRES.jld2" filtPolEADmatsRES

JLD2.@load "/home/nicolas/Data/mbszdeciles_filtPolEADmats.jld2"
JLD2.@load "/home/nicolas/Data/mbszdeciles_filtPolEADmatsRES.jld2"
allSplitsPol = Dict()
chosenSplit = "resDic"
allSplitsPol["$(chosenSplit)_ALL_sent"] = Dict()
for filtpair in [[([], false, [0,20]), ([], false, [0,100])], [([], false, [80,100]), ([], false, [0,100])], [([], false, [-1,0]), ([], false, [0,100])]]
    allSplitsPol["$(chosenSplit)_ALL_sent"][filtpair] = valszCondMeanEAD(filtPolEADmats[filtpair[1]], filtPolEADmats[filtpair[2]], [3, 4])
end
allSplitsPol["$(chosenSplit)_ALL_sent_RES"] = Dict()
for filtpair in [[([], false, [0,20]), ([], false, [0,100])], [([], false, [80,100]), ([], false, [0,100])], [([], false, [-1,0]), ([], false, [0,100])]]
    allSplitsPol["$(chosenSplit)_ALL_sent_RES"][filtpair] = valszCondMeanEAD(filtPolEADmatsRES[filtpair[1]], filtPolEADmatsRES[filtpair[2]], [3, 4])
end
filtpair = [([], false, [80,100]), ([], false, [0,100])]
Rheatmap(allSplitsPol["$(chosenSplit)_ALL_sent_RES"][filtpair], "Sentiment level of RES news", 9);



@time allNewsCat = bmszmat(resDic, "sent_rel100_nov24H", "nbStories_rel100_nov24H")
@time resNewsCat = bmszmat(resDic, "sent_rel100_nov24H_RES", "nbStories_rel100_nov24H_RES")

Rheatmap(resNewsCat[1].-allNewsCat[1], 10)
Rheatmap(allNewsCat[9]./allNewsCat[10], 10)
Rheatmap(allNewsCat[1], 10)
foo = allNewsCat[9]./allNewsCat[10]
Rheatmap(((allNewsCat[1].-mean(allNewsCat[1]))./std(allNewsCat[1]))./((foo.-mean(foo))./std(foo)), 50)



bar = aroundEAD(resDic[306]["EAD"], -5:3)
print(missingsum(bar[:,100]))
print("\n")
print(missingsum(resDic[306]["EAD"][:,100]))

#Double-entry aroundEAD and Polarity filter


# When do earnings news arrive?




function aroundEAD(EADmat, lagids)
    let foo = convert(Array, resDic[306]["EAD"])
    for col in size(foo, 2)
        print(missingsum(foo[:,1]))
        print("\n")
        row=1
        while row<=size(foo, 1)
            if !ismissing(foo[row, col]) && foo[row, col]==1
                for lagid in lagids
                    foo[row+lagid, col] = 1
                end
                foo[row-1, col] = 1
                print(foo[row-1, col])
                row+=maximum(lagids)
            end
            row+=1
        end
        print(missingsum(foo[:,1]))
        break
    end
    # return foo
    end #let block
end

bar = aroundEAD(resDic[306]["EAD"], [-5,-4,-3,-2,-1,1,2,3])
print(missingsum(bar[:,2]))
print("\n")
print(missingsum(resDic[306]["EAD"][:,2]))













let tsmat = 0
for crtsize in 1
    for spec in 1:10
        foo = convert(Array{Union{Missing,Float64}}, resDic[crtsize*100+spec]["sent_rel100_nov24H"])

        allvals = Float64[]
        for row in 1:size(foo,1)
            crtdate = Float64[]
            for col in 1:size(foo,2)
                if !ismissing(foo[row,col]) && !isnan(foo[row,col])
                    push!(crtdate, foo[row,col])
                end
            end
            push!(allvals, mean(crtdate))
        end
        if tsmat==0
            tsmat = allvals'
        else
            tsmat = vcat(tsmat, allvals')
        end
    end
end
@rput tsmat
show(size(tsmat))
end


function tsagg(X, per)
    res = Float64[]
    for i in 0:ceil(length(X)/per)
        i = Int(i)
        push!(res, NaNMath.mean(X[i*per+1:minimum([length(X), (i+1)*per])]))
    end
    return res
end

let per = 60
tsval = tsagg(tsmat[1,:], per)'
for row in 2:size(tsmat,1)
    X = tsmat[row,:]
    tsval = vcat(tsval, tsagg(X, per)')
end
@rput tsval
end

R"plot(res, type = 'l')"
R"matplot(t(tsval[c(2,6),]), type = 'l', col = 1:2)"
@rget tsval
tsval = tsval[:,1:end-1]
corrmat = ones((size(tsval,1), size(tsval,1)))
for row in 1:size(tsval,1)
    for row2 in 1:size(tsval,1)
        corrmat[row, row2] = cor(tsval[row,:], tsval[row2,:])
    end
end

@rput corrmat
R"colnames(corrmat) <- paste('S', 1:10, sep='')"
R"rownames(corrmat) <- paste('V', 1:10, sep='')"


R"image(1:ncol(corrmat), 1:nrow(corrmat), t(corrmat), col = heat.colors(50), axes = FALSE)"
R"axis(1, 1:ncol(corrmat), colnames(corrmat))"
R"axis(2, 1:nrow(corrmat), rownames(corrmat))"
R"for (x in 1:ncol(corrmat))
  for (y in 1:nrow(corrmat))
    text(x, y, corrmat[y,x])"





let finalmat = 0
for crtsize in 1:10
    meansresults = Float64[]
    for spec in 1:10
        foo = convert(Array{Union{Missing,Float64}}, resDic[crtsize*100+spec]["sent_rel100_nov24H"])

        allvals = Float64[]
        for row in 1:size(foo,1)
            for col in 1:size(foo,2)
                if !ismissing(foo[row,col]) && !isnan(foo[row,col])
                    push!(allvals, foo[row,col])
                end
            end
        end
        push!(meansresults, mean(allvals))
    end
    if finalmat==0
        finalmat = meansresults
    else
        finalmat = hcat(finalmat, meansresults)
    end
end
@rput finalmat
show(finalmat)
end

R"colnames(finalmat) <- paste('S', 1:10, sep='')"
R"rownames(finalmat) <- paste('V', 1:10, sep='')"


R"image(1:ncol(finalmat), 1:nrow(finalmat), t(finalmat), col = heat.colors(50), axes = FALSE)"
R"axis(1, 1:ncol(finalmat), colnames(finalmat))"
R"axis(2, 1:nrow(finalmat), rownames(finalmat))"
R"for (x in 1:ncol(finalmat))
  for (y in 1:nrow(finalmat))
    text(x, y, finalmat[y,x])"
