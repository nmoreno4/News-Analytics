module RegFormat
using GLM, StatsBase

export

function regptfspill(crtptf, newsShockVar, WS ; control = :rawnewsstrength_mkt, relcoveragetype = 1)
    fitness = Dict("ret_tstat_simple" => Float64[], "R2_1" => Float64[], "R2_2" => Float64[],
                   "ret_tstat" => Float64[], "interaction_tstat" => Float64[], "R2_gain"=>Float64[])
    if relcoveragetype==1
       crtptf[:relcoverage] = crtptf[:rawnewsstrength_ptf] ./ crtptf[:rawnewsstrength_mkt]
    elseif relcoveragetype==2
       crtptf[:relcoverage] = crtptf[:coverage_ptf] ./ crtptf[:coverage_mkt]
    end

    crtptf[:newsShock] = crtptf[newsShockVar]
    crtptf[:controlShock] = crtptf[control]
    crtptf = convert(DataFrame, crtptf)
    res, res1 = 0, 0
    if WS=="VW"
        crtWS = :VWret_ptf
    elseif WS=="EW"
        crtWS = :EWret_ptf
    end

    if sum(crtptf[:newsShock])!=0 && sum(crtptf[crtWS])!=0
        if WS == "VW"
           res = lm(@formula(VWret_mkt ~ VWret_ptf + VWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(VWret_mkt ~ VWret_ptf + controlShock&VWret_ptf), crtptf)
        elseif WS=="EW"
           res = lm(@formula(EWret_mkt ~ EWret_ptf + EWret_ptf&newsShock + controlShock&EWret_ptf), crtptf)
           res1 = lm(@formula(EWret_mkt ~ EWret_ptf + controlShock&EWret_ptf), crtptf)
        end
    else
        show(crtptf[[:VWret_mkt, :VWret_ptf, :newsShock, :controlShock]])
        if sum(crtptf[:newsShock])==0
            crtptf[:newsShock][1] = rand()
        end
        if sum(crtptf[:VWret_ptf])==0
            crtptf[:VWret_ptf][1] = rand()
        end
        print(crtptf[:VWret_ptf])
        if WS == "VW"
           res = lm(@formula(VWret_mkt ~ VWret_ptf + VWret_ptf&newsShock + controlShock&VWret_ptf), crtptf)
           res1 = lm(@formula(VWret_mkt ~ VWret_ptf + controlShock&VWret_ptf), crtptf)
        elseif WS=="EW"
           res = lm(@formula(EWret_mkt ~ EWret_ptf + EWret_ptf&newsShock + controlShock&EWret_ptf), crtptf)
           res1 = lm(@formula(EWret_mkt ~ EWret_ptf + controlShock&EWret_ptf), crtptf)
        end
    end
    regDF = OLScoeftableToDF(res)
    regDF1 = OLScoeftableToDF(res1)
    push!(fitness["R2_1"], adjr2(res))
    push!(fitness["R2_2"], adjr2(res1))
    push!(fitness["R2_gain"], adjr2(res)-adjr2(res1))

    if WS == "VW"
       push!(fitness["ret_tstat"], regDF[findall(regDF[:depvar].=="VWret_ptf & newsShock")[1], Symbol("t value")])
       push!(fitness["ret_tstat_simple"], regDF[findall(regDF[:depvar].=="VWret_ptf & controlShock")[1], Symbol("t value")])
       push!(fitness["interaction_tstat"], regDF[findall(regDF[:depvar].=="VWret_ptf & newsShock")[1], Symbol("t value")])
    elseif WS=="EW"
        push!(fitness["ret_tstat"], regDF[findall(regDF[:depvar].=="EWret_ptf & newsShock")[1], Symbol("t value")])
        push!(fitness["ret_tstat_simple"], regDF[findall(regDF[:depvar].=="EWret_ptf & controlShock")[1], Symbol("t value")])
        push!(fitness["interaction_tstat"], regDF[findall(regDF[:depvar].=="EWret_ptf & newsShock")[1], Symbol("t value")])
    end
    return fitness
end

end #module
