laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/premium_help.jl")


for i in names(aggDicFreq[1])
    print("$i \n")
end

data = aggDicFreq[1][[:permno, :perid, :cumret, :sum_perSent_, :sum_perNbStories_, :wt, :momrank, :bmdecile, :sizedecile, :EAD, :aggSent_]]
sort!(data, [:permno, :perid])


anomaly = :bmdecile
# thresh = 1
vtype = "equal"
allptfs = Dict()
for thresh in [1,10]
    @time byday = by(data, :perid) do df
        df = df[isnotmissing.(df[anomaly]), :]
        res = Dict()
        if vtype == "bigger"
            v = df[df[anomaly].>=thresh,:]
        elseif vtype == "smaller"
            v = df[df[anomaly].<=thresh,:]
        elseif vtype=="equal"
            v = df[df[anomaly].==thresh,:]
        end
        v = v[isnotmissing.(v[:sum_perNbStories_]),:]
        vwithoutnews = v[ismissing.(v[:sum_perNbStories_]),:]
        res[:VWret_v] = VWeight(v, :cumret)
        res[:VWsent_v] = VWeight(v, :aggSent_)
        res[:coverage_v] = sum(v[:sum_perNbStories_])

        if vtype == "bigger"
            lom = df[df[anomaly].<thresh,:]
        elseif vtype == "smaller"
            lom = df[df[anomaly].>thresh,:]
        elseif vtype=="equal"
            lom = df[df[anomaly].!=thresh,:]
        end
        lom = vcat(lom, vwithoutnews)
        res[:VWret_lom] = VWeight(lom, :cumret)
        res[:VWsent_lom] = VWeight(lom, :aggSent_)
        res[:coverage_lom] = custom_sum(lom[:sum_perNbStories_])
        DataFrame(res)
    end
    allptfs[thresh] = byday
end


regres = Dict("R2_1" => Float64[], "R2_2" => Float64[], "ret_tstat" => Float64[], "interaction_tstat" => Float64[])
for i in 1:10
    byday = allptfs[i]
    @rput byday
    R"mod = lm(VWret_lom ~ VWret_v + VWret_v:coverage_v, data=byday)"
    R"mod1 = lm(VWret_lom ~ VWret_v, data=byday)"
    R"res = summary(mod)";
    R"res1 = summary(mod1)";
    @rget res; @rget res1;
    push!(regres["R2_1"], res[:adj_r_squared])
    push!(regres["R2_2"], res1[:adj_r_squared])
    push!(regres["ret_tstat"], res[:coefficients][2,3])
    push!(regres["interaction_tstat"], res[:coefficients][3,3])
end
hcat(regres["R2_1"], regres["R2_2"])
regres["R2_1"] .- regres["R2_2"]
Rplot(regres["R2_1"] .- regres["R2_2"])
regres["interaction_tstat"]




### Double extremes
anomaly = :bmdecile
# thresh = 1
vtype = "bigger"
allptfs = Dict()
for bucketsize in 1:3
    @time byday = by(data, :perid) do df
        df = df[isnotmissing.(df[anomaly]), :]
        res = Dict()
        if vtype == "bigger"
            v = df[df[anomaly].>=(10-bucketsize),:]
            g = df[df[anomaly].<=(0+bucketsize),:]
        elseif vtype=="equal"
            v = df[df[anomaly].==(10-bucketsize),:]
            g = df[df[anomaly].==(0+bucketsize),:]
        end
        v = v[isnotmissing.(v[:sum_perNbStories_]),:]
        vwithoutnews = v[ismissing.(v[:sum_perNbStories_]),:]
        g = g[isnotmissing.(g[:sum_perNbStories_]),:]
        gwithoutnews = g[ismissing.(g[:sum_perNbStories_]),:]
        res[:VWret_v] = VWeight(v, :cumret)
        res[:VWsent_v] = VWeight(v, :aggSent_)
        res[:coverage_v] = sum(v[:sum_perNbStories_])
        res[:VWret_g] = VWeight(g, :cumret)
        res[:VWsent_g] = VWeight(g, :aggSent_)
        res[:coverage_g] = sum(g[:sum_perNbStories_])

        if vtype == "bigger"
            lom = df[df[anomaly].<(10-bucketsize),:]
            lom = lom[lom[anomaly].>(0+bucketsize),:]
        elseif vtype=="equal"
            lom = df[df[anomaly].!=(10-bucketsize),:]
            lom = lom[lom[anomaly].!=(0+bucketsize),:]
        end
        lom = vcat(lom, vwithoutnews, gwithoutnews)
        lom = df
        res[:VWret_lom] = VWeight(lom, :cumret)
        res[:VWsent_lom] = VWeight(lom, :aggSent_)
        res[:coverage_lom] = custom_sum(lom[:sum_perNbStories_])
        DataFrame(res)
    end
    allptfs[bucketsize] = byday
end

byday = allptfs[3]
byday[:excesscoverage] = byday[:coverage_v] .- byday[:coverage_g]
byday[:highcoverage_v] = convert(Array{Int}, byday[:coverage_v] .> mean(byday[:coverage_v]) + 1*std(byday[:coverage_v]))
byday[:highcoverage_g] = convert(Array{Int}, byday[:coverage_g] .> mean(byday[:coverage_g]) + 1*std(byday[:coverage_g]))
@rput byday
R"mod = lm(VWret_lom ~ VWret_v + VWret_v:highcoverage_v + VWret_g + VWret_g:highcoverage_g, data=byday)"
R"res = summary(mod)";
R"print(res)";







### notonlynewsreturns
anomaly = :bmdecile
# thresh = 1
vtype = "bigger"
allptfs = Dict()
for bucketsize in 1
    @time byday = by(data, :perid) do df
        df = df[isnotmissing.(df[anomaly]), :]
        res = Dict()
        if vtype == "bigger"
            v = df[df[anomaly].>=(10-bucketsize),:]
            g = df[df[anomaly].<=(0+bucketsize),:]
        elseif vtype=="equal"
            v = df[df[anomaly].==(10-bucketsize),:]
            g = df[df[anomaly].==(0+bucketsize),:]
        end
        res[:VWret_v] = VWeight(v, :cumret)
        res[:VWsent_v] = VWeight(v, :aggSent_)
        res[:coverage_v] = custom_sum(v[:sum_perNbStories_])
        res[:VWret_g] = VWeight(g, :cumret)
        res[:VWsent_g] = VWeight(g, :aggSent_)
        res[:coverage_g] = custom_sum(g[:sum_perNbStories_])

        if vtype == "bigger"
            lom = df[df[anomaly].<(10-bucketsize),:]
            lom = lom[lom[anomaly].>(0+bucketsize),:]
        elseif vtype=="equal"
            lom = df[df[anomaly].!=(10-bucketsize),:]
            lom = lom[lom[anomaly].!=(0+bucketsize),:]
        end
        # lom = df
        res[:VWret_lom] = VWeight(lom, :cumret)
        res[:VWsent_lom] = VWeight(lom, :aggSent_)
        res[:coverage_lom] = custom_sum(lom[:sum_perNbStories_])
        DataFrame(res)
    end
    allptfs[bucketsize] = byday
end

byday = allptfs[1]
byday[:excesscoverage] = byday[:coverage_v] .- byday[:coverage_g]
byday[:highcoverage_v] = convert(Array{Int}, byday[:coverage_v] .> mean(byday[:coverage_v]) + 1*std(byday[:coverage_v]))
byday[:highcoverage_g] = convert(Array{Int}, byday[:coverage_g] .> mean(byday[:coverage_g]) + 1*std(byday[:coverage_g]))
@rput byday
R"mod = lm(VWret_lom ~ VWret_v + VWret_v:highcoverage_v + VWret_g + VWret_g:highcoverage_g, data=byday)"
R"res = summary(mod)";
R"print(res)";
