using MongoDF, Dates, DataFrames, DataFramesMeta, DataStructures, CSV

retvalues = ["date", "permno", "retadj", "me",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RES_excl_RESF_excl_nov24H_0_rel100", "posSum_RES_excl_RESF_excl_nov24H_0_rel100", "negSum_RES_excl_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100",
             "nS_BACT_inc_nov24H_0_rel100", "posSum_BACT_inc_nov24H_0_rel100", "negSum_BACT_inc_nov24H_0_rel100"]
NA = @time TRNAmongoDF(retvalues; monthrange = Year(5), startDate = DateTime(2002,12,31), endDate = DateTime(2017,12,31))

mysum(x) = length(collect(skipmissing(x)))>0 ? sum(skipmissing(x)) : missing
mystd(x) = length(collect(skipmissing(x)))>0 ? std(skipmissing(x)) : missing

SentALL, SentRES, SentRESF, SentBACT, SentNORES = [[] for i in 1:5]
CountALL, CountRES, CountRESF, CountBACT, CountNORES = [[] for i in 1:5]
DisagreementALL, DisagreementRES, DisagreementRESF, DisagreementBACT, DisagreementNORES = [[] for i in 1:5]
PosALL, PosRES, PosRESF, PosBACT, PosNORES = [[] for i in 1:5]
NegALL, NegRES, NegRESF, NegBACT, NegNORES = [[] for i in 1:5]
@time for date in sort(collect(Set(NA[:date])))
    crtdf = NA[findall(NA[:date].==date), :]
    totME = sum(skipmissing(crtdf[:me]))
    wVec = crtdf[:me] ./ totME
    sentALL = (crtdf[:posSum_nov24H_0_rel100] .+ crtdf[:negSum_nov24H_0_rel100]) ./ crtdf[:nS_nov24H_0_rel100]
    posALL = crtdf[:posSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    negALL = crtdf[:negSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    push!(SentALL, mysum(sentALL .* wVec))
    push!(CountALL, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementALL, mystd(sentALL .* wVec))
    push!(PosALL, mysum(posALL .* wVec))
    push!(NegALL, mysum(negALL .* wVec))
    sentRES = (crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    posRES = crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    negRES = crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    push!(SentRES, mysum(sentRES .* wVec))
    push!(CountRES, mysum(crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementRES, mystd(sentRES .* wVec))
    push!(PosRES, mysum(posRES .* wVec))
    push!(NegRES, mysum(negRES .* wVec))
    sentRESF = (crtdf[:posSum_RESF_inc_nov24H_0_rel100] .+ crtdf[:negSum_RESF_inc_nov24H_0_rel100]) ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    posRESF = crtdf[:posSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    negRESF = crtdf[:negSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    push!(SentRESF, mysum(sentRESF .* wVec))
    push!(CountRESF, mysum(crtdf[:nS_RESF_inc_nov24H_0_rel100]))
    push!(DisagreementRESF, mystd(sentRESF .* wVec))
    push!(PosRESF, mysum(posRESF .* wVec))
    push!(NegRESF, mysum(negRESF .* wVec))
    sentNORES = (crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    posNORES = crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    negNORES = crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    push!(SentNORES, mysum(sentNORES .* wVec))
    push!(CountNORES, mysum(crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementNORES, mystd(sentNORES .* wVec))
    push!(PosNORES, mysum(posNORES .* wVec))
    push!(NegNORES, mysum(negNORES .* wVec))
    sentBACT = (crtdf[:posSum_BACT_inc_nov24H_0_rel100] .+ crtdf[:negSum_BACT_inc_nov24H_0_rel100]) ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    posBACT = crtdf[:posSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    negBACT = crtdf[:negSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    push!(SentBACT, mysum(sentBACT .* wVec))
    push!(CountBACT, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementBACT, mystd(sentBACT .* wVec))
    push!(PosBACT, mysum(posBACT .* wVec))
    push!(NegBACT, mysum(negBACT .* wVec))
end
dailySeries = DataFrame(OrderedDict("date"=>sort(collect(Set(NA[:date]))), "SentALL"=>SentALL, "SentRES"=>SentRES, "SentRESF"=>SentRESF, "SentBACT"=>SentBACT, "SentNORES"=>SentNORES,
     "CountALL"=>CountALL, "CountRES"=>CountRES, "CountRESF"=>CountRESF, "CountBACT"=>CountBACT, "CountNORES"=>CountNORES,
     "DisagreementALL"=>DisagreementALL, "DisagreementRES"=>DisagreementRES, "DisagreementRESF"=>DisagreementRESF, "DisagreementBACT"=>DisagreementBACT, "DisagreementNORES"=>DisagreementNORES,
     "PosALL"=>PosALL, "PosRES"=>PosRES, "PosRESF"=>PosRESF, "PosBACT"=>PosBACT, "PosNORES"=>PosNORES,
     "NegALL"=>NegALL, "NegRES"=>NegRES, "NegRESF"=>NegRESF, "NegBACT"=>NegBACT, "NegNORES"=>NegNORES))

plot(Float64.(replace(DisagreementRES, missing=>NaN)))
CSV.write("/home/nicolas/Documents/CF DR paper/dailyMktNA.csv", dailySeries)

###
SentALL, SentRES, SentRESF, SentBACT, SentNORES = [[] for i in 1:5]
CountALL, CountRES, CountRESF, CountBACT, CountNORES = [[] for i in 1:5]
DisagreementALL, DisagreementRES, DisagreementRESF, DisagreementBACT, DisagreementNORES = [[] for i in 1:5]
PosALL, PosRES, PosRESF, PosBACT, PosNORES = [[] for i in 1:5]
NegALL, NegRES, NegRESF, NegBACT, NegNORES = [[] for i in 1:5]
@time for date in ceil(minimum(NA[:date]), Month):Month(1):ceil(maximum(NA[:date]), Month)
    crtdf = NA[findall((NA[:date].<date) .& (NA[:date].>=date-Month(1))), :]
    totME = sum(skipmissing(crtdf[:me]))
    wVec = crtdf[:me] ./ totME
    sentALL = (crtdf[:posSum_nov24H_0_rel100] .+ crtdf[:negSum_nov24H_0_rel100]) ./ crtdf[:nS_nov24H_0_rel100]
    posALL = crtdf[:posSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    negALL = crtdf[:negSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    push!(SentALL, mysum(sentALL .* wVec))
    push!(CountALL, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementALL, mystd(sentALL .* wVec))
    push!(PosALL, mysum(posALL .* wVec))
    push!(NegALL, mysum(negALL .* wVec))
    sentRES = (crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    posRES = crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    negRES = crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    push!(SentRES, mysum(sentRES .* wVec))
    push!(CountRES, mysum(crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementRES, mystd(sentRES .* wVec))
    push!(PosRES, mysum(posRES .* wVec))
    push!(NegRES, mysum(negRES .* wVec))
    sentRESF = (crtdf[:posSum_RESF_inc_nov24H_0_rel100] .+ crtdf[:negSum_RESF_inc_nov24H_0_rel100]) ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    posRESF = crtdf[:posSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    negRESF = crtdf[:negSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    push!(SentRESF, mysum(sentRESF .* wVec))
    push!(CountRESF, mysum(crtdf[:nS_RESF_inc_nov24H_0_rel100]))
    push!(DisagreementRESF, mystd(sentRESF .* wVec))
    push!(PosRESF, mysum(posRESF .* wVec))
    push!(NegRESF, mysum(negRESF .* wVec))
    sentNORES = (crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    posNORES = crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    negNORES = crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    push!(SentNORES, mysum(sentNORES .* wVec))
    push!(CountNORES, mysum(crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementNORES, mystd(sentNORES .* wVec))
    push!(PosNORES, mysum(posNORES .* wVec))
    push!(NegNORES, mysum(negNORES .* wVec))
    sentBACT = (crtdf[:posSum_BACT_inc_nov24H_0_rel100] .+ crtdf[:negSum_BACT_inc_nov24H_0_rel100]) ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    posBACT = crtdf[:posSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    negBACT = crtdf[:negSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    push!(SentBACT, mysum(sentBACT .* wVec))
    push!(CountBACT, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementBACT, mystd(sentBACT .* wVec))
    push!(PosBACT, mysum(posBACT .* wVec))
    push!(NegBACT, mysum(negBACT .* wVec))
end
monthlySeries = DataFrame(OrderedDict("date"=>collect(ceil(minimum(NA[:date]), Month):Month(1):ceil(maximum(NA[:date]), Month)), "SentALL"=>SentALL, "SentRES"=>SentRES, "SentRESF"=>SentRESF, "SentBACT"=>SentBACT, "SentNORES"=>SentNORES,
     "CountALL"=>CountALL, "CountRES"=>CountRES, "CountRESF"=>CountRESF, "CountBACT"=>CountBACT, "CountNORES"=>CountNORES,
     "DisagreementALL"=>DisagreementALL, "DisagreementRES"=>DisagreementRES, "DisagreementRESF"=>DisagreementRESF, "DisagreementBACT"=>DisagreementBACT, "DisagreementNORES"=>DisagreementNORES,
     "PosALL"=>PosALL, "PosRES"=>PosRES, "PosRESF"=>PosRESF, "PosBACT"=>PosBACT, "PosNORES"=>PosNORES,
     "NegALL"=>NegALL, "NegRES"=>NegRES, "NegRESF"=>NegRESF, "NegBACT"=>NegBACT, "NegNORES"=>NegNORES))
plot(Float64.(replace(SentALL, missing=>NaN)))
CSV.write("/home/nicolas/Documents/CF DR paper/monthlyMktNA.csv", monthlySeries)

###
SentALL, SentRES, SentRESF, SentBACT, SentNORES = [[] for i in 1:5]
CountALL, CountRES, CountRESF, CountBACT, CountNORES = [[] for i in 1:5]
DisagreementALL, DisagreementRES, DisagreementRESF, DisagreementBACT, DisagreementNORES = [[] for i in 1:5]
PosALL, PosRES, PosRESF, PosBACT, PosNORES = [[] for i in 1:5]
NegALL, NegRES, NegRESF, NegBACT, NegNORES = [[] for i in 1:5]
@time for date in ceil(minimum(NA[:date]), Week):Week(1):ceil(maximum(NA[:date]), Week)
    crtdf = NA[findall((NA[:date].<date) .& (NA[:date].>=date-Week(1))), :]
    totME = sum(skipmissing(crtdf[:me]))
    wVec = crtdf[:me] ./ totME
    sentALL = (crtdf[:posSum_nov24H_0_rel100] .+ crtdf[:negSum_nov24H_0_rel100]) ./ crtdf[:nS_nov24H_0_rel100]
    posALL = crtdf[:posSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    negALL = crtdf[:negSum_nov24H_0_rel100] ./ crtdf[:nS_nov24H_0_rel100]
    push!(SentALL, mysum(sentALL .* wVec))
    push!(CountALL, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementALL, mystd(sentALL .* wVec))
    push!(PosALL, mysum(posALL .* wVec))
    push!(NegALL, mysum(negALL .* wVec))
    sentRES = (crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    posRES = crtdf[:posSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    negRES = crtdf[:negSum_RES_inc_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]
    push!(SentRES, mysum(sentRES .* wVec))
    push!(CountRES, mysum(crtdf[:nS_RES_inc_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementRES, mystd(sentRES .* wVec))
    push!(PosRES, mysum(posRES .* wVec))
    push!(NegRES, mysum(negRES .* wVec))
    sentRESF = (crtdf[:posSum_RESF_inc_nov24H_0_rel100] .+ crtdf[:negSum_RESF_inc_nov24H_0_rel100]) ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    posRESF = crtdf[:posSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    negRESF = crtdf[:negSum_RESF_inc_nov24H_0_rel100] ./ crtdf[:nS_RESF_inc_nov24H_0_rel100]
    push!(SentRESF, mysum(sentRESF .* wVec))
    push!(CountRESF, mysum(crtdf[:nS_RESF_inc_nov24H_0_rel100]))
    push!(DisagreementRESF, mystd(sentRESF .* wVec))
    push!(PosRESF, mysum(posRESF .* wVec))
    push!(NegRESF, mysum(negRESF .* wVec))
    sentNORES = (crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] .+ crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100]) ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    posNORES = crtdf[:posSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    negNORES = crtdf[:negSum_RES_excl_RESF_excl_nov24H_0_rel100] ./ crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]
    push!(SentNORES, mysum(sentNORES .* wVec))
    push!(CountNORES, mysum(crtdf[:nS_RES_excl_RESF_excl_nov24H_0_rel100]))
    push!(DisagreementNORES, mystd(sentNORES .* wVec))
    push!(PosNORES, mysum(posNORES .* wVec))
    push!(NegNORES, mysum(negNORES .* wVec))
    sentBACT = (crtdf[:posSum_BACT_inc_nov24H_0_rel100] .+ crtdf[:negSum_BACT_inc_nov24H_0_rel100]) ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    posBACT = crtdf[:posSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    negBACT = crtdf[:negSum_BACT_inc_nov24H_0_rel100] ./ crtdf[:nS_BACT_inc_nov24H_0_rel100]
    push!(SentBACT, mysum(sentBACT .* wVec))
    push!(CountBACT, mysum(crtdf[:nS_nov24H_0_rel100]))
    push!(DisagreementBACT, mystd(sentBACT .* wVec))
    push!(PosBACT, mysum(posBACT .* wVec))
    push!(NegBACT, mysum(negBACT .* wVec))
end
weeklySeries = DataFrame(OrderedDict("date"=>collect(ceil(minimum(NA[:date]), Week):Week(1):ceil(maximum(NA[:date]), Week)), "SentALL"=>SentALL, "SentRES"=>SentRES, "SentRESF"=>SentRESF, "SentBACT"=>SentBACT, "SentNORES"=>SentNORES,
     "CountALL"=>CountALL, "CountRES"=>CountRES, "CountRESF"=>CountRESF, "CountBACT"=>CountBACT, "CountNORES"=>CountNORES,
     "DisagreementALL"=>DisagreementALL, "DisagreementRES"=>DisagreementRES, "DisagreementRESF"=>DisagreementRESF, "DisagreementBACT"=>DisagreementBACT, "DisagreementNORES"=>DisagreementNORES,
     "PosALL"=>PosALL, "PosRES"=>PosRES, "PosRESF"=>PosRESF, "PosBACT"=>PosBACT, "PosNORES"=>PosNORES,
     "NegALL"=>NegALL, "NegRES"=>NegRES, "NegRESF"=>NegRESF, "NegBACT"=>NegBACT, "NegNORES"=>NegNORES))
plot(Float64.(replace(SentALL, missing=>NaN)))
CSV.write("/home/nicolas/Documents/CF DR paper/weeklyMktNA.csv", weeklySeries)


####
date = ceil(dailySeries[:date][1], Month)
@time for date ceil(minimum(NA[:date]), Month):Month(1):ceil(maximum(NA[:date]), Month)
    crtdf = dailySeries[findall((dailySeries[:date].<date) .& (dailySeries[:date].>=date-Month(1))), :]
end
