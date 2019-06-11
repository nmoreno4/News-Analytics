using JLD2, CSV
laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")
include("$(laptop)/DescriptiveStats/helpfcts.jl")
@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"

freq = "year"

data = aggDicFreq[1]
sort!(data, [:permno, :perid])
data[:gsector] = replace(data[:gsector], missing=>0)
data[:EAD] = replace(data[:EAD], missing=>0)

@time nomicro = data[data[:sizedecile].>2,:]

@time ptfperf = nomicro[nomicro[:gsector].==35,:]


allstocks = sensrankedptfs(data, freq)



meanvec = Float64[]
for i in 1:10
    push!(meanvec, mean(allstocks[i]))
end
Rplot(meanvec)
Rplot(ret2tick(allstocks[10] .- allstocks[1]))




@time for row in 1:size(data,1)
    crtbin = searchsortedfirst(0:intervallength:3250, ptfperf[row,:perid])-1
    if ptfperf[row,:perid]<3240
        crtid = bins[crtbin]
        if ptfperf[row,:permno] in Res[crtid][1]
            ptfperf[row, :NS_rank_crt] = 1
        elseif ptfperf[row,:permno] in Res[crtid][2]
            ptfperf[row, :NS_rank_crt] = 10
        end
    end

    if ptfperf[row,:perid]>intervallength
        fwdbin = searchsortedfirst(0:intervallength:3250, ptfperf[row,:perid])-2
        fwdid = bins[fwdbin]
        if ptfperf[row,:permno] in Res[fwdid][1]
            ptfperf[row, :NS_rank_fwd] = 1
        elseif ptfperf[row,:permno] in Res[fwdid][2]
            ptfperf[row, :NS_rank_fwd] = 10
        end
    end
end


spillers = ptfperf[ptfperf[:NS_rank_crt].==10,:]
nonspillers = ptfperf[ptfperf[:NS_rank_crt].==1,:]

spillret = Dict()
for (i,j) in bins
    y1 = spillers[spillers[:perid].>i,:]
    y1 = y1[y1[:perid].<j,:]
    byday = by(y1[[:perid, :permno, :cumret, :wt]], :perid) do df
        VWeight(df, :cumret)
    end
    spillret[(i,j)] = byday[:x1]
end
resspillret = Float64[]
for (i,j) in bins
    push!(resspillret, cumret(spillret[(i,j)]))
end
Rplot(ret2tick(resspillret))



nonspillret = Dict()
for (i,j) in bins
    y1 = nonspillers[nonspillers[:perid].>i,:]
    y1 = y1[y1[:perid].<j,:]
    byday = by(y1[[:perid, :permno, :cumret, :wt]], :perid) do df
        VWeight(df, :cumret)
    end
    nonspillret[(i,j)] = byday[:x1]
end
resnonspillret = Float64[]
for (i,j) in bins
    push!(resnonspillret, cumret(nonspillret[(i,j)]))
end
Rplot(ret2tick(resnonspillret))

Rplot(ret2tick(resspillret .- resnonspillret))
old2 = (spillret, nonspillret)



#out-of-sample
spillers = ptfperf[ptfperf[:NS_rank_fwd].==10,:]
nonspillers = ptfperf[ptfperf[:NS_rank_fwd].==1,:]

spillret = Dict()
for (i,j) in bins[2:end]
    y1 = spillers[spillers[:perid].>i,:]
    y1 = y1[y1[:perid].<j,:]
    byday = by(y1[[:perid, :permno, :cumret, :wt]], :perid) do df
        VWeight(df, :cumret)
    end
    spillret[(i,j)] = byday[:x1]
end
resspillret = Float64[]
for (i,j) in bins[2:end]
    push!(resspillret, cumret(spillret[(i,j)]))
end
Rplot(ret2tick(resspillret))



nonspillret = Dict()
for (i,j) in bins[2:end]
    y1 = nonspillers[nonspillers[:perid].>i,:]
    y1 = y1[y1[:perid].<j,:]
    byday = by(y1[[:perid, :permno, :cumret, :wt]], :perid) do df
        VWeight(df, :cumret)
    end
    nonspillret[(i,j)] = byday[:x1]
end
resnonspillret = Float64[]
for (i,j) in bins[2:end]
    push!(resnonspillret, cumret(nonspillret[(i,j)]))
end
Rplot(ret2tick(resnonspillret))

Rplot(ret2tick(resspillret .- resnonspillret))














secondyear = @time atest(byday, y1);
foo2 = DataFrame(secondyear[2:end,:])
names!(foo2, [:permno, :mktsens, :interactsens])
foo2[:interactsens] = replace(foo2[:interactsens], missing=>NaN)
bar2 = foo2[foo2[:mktsens].>3,:]
custom_perc(bar2[:interactsens], [1,10,20, 30,50,70,80,90,100])
lol2 = bar2[bar2[:interactsens].>2,:]
spillstocks2 = lol2[:permno]
