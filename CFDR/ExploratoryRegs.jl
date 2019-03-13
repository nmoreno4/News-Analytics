using LoadNewsTS, RegressionFcts, Dates

TRMIsocial, TRMInewssocial, TRMInews = loadTRMI(Month(1))
CFDR = loadCFDR(filename="results_CFDR_topics_complete")
TRNA = loadTRNA(Month(1), "VW")
USREC = loadRecession()


CFDR = join(CFDR, USREC, on=:date, kind=:inner)
CFDR = join(CFDR, MktRet, on=:date, kind=:inner)


X = hcat(TRMIsocial, TRMInewssocial, TRMInews, makeunique=true)
X = join(X, CFDR, on=:date, kind=:inner)
Y = join(TRNA, X, on=:date, kind=:inner)

@rput X
R"""
lag = 0
lead = 2
sz = dim(X)[1]
print(summary(lm(CF[(1+lag):(sz-lead)] ~ stockIndexSentiment_1[(1+lag):(sz-lead)] + diff(stockIndexSentiment_1), data=X)))
print(summary(lm(DR[(1+lag):(sz-lead)] ~ stockIndexSentiment_1[(1+lag):(sz-lead)] + diff(stockIndexSentiment_1), data=X)))
print(summary(lm(CF[(1+lag):(sz-lead)] ~ diff(stockIndexSentiment_1), data=X)))
print(summary(lm(DR[(1+lag):(sz-lead)] ~ diff(stockIndexSentiment_1), data=X)))
"""

A = CFDR[CFDR[:USREC].==1,:]
B = CFDR[CFDR[:USREC].==0,:]
@rput CFDR; @rput A; @rput B
R"""
print(summary(lm(sprtrn ~ CF + DR, data=CFDR)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=CFDR)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=A)))
print(summary(lm(sprtrn ~ latehalf*CF + latehalf*DR, data=B)))
"""
cor(CFDR[:CF], CFDR[:DR])

plot(ret2tick(Y[:DR]))

for i in names(Y)
    print("$i \n")
end

cor(Y[:stockIndexSentiment_1], Y[:SentALL])
vfloat(x) = convert(Array{Float64}, x)
plot(autocor(vfloat(Y[:stockIndexSentiment])))
plot!(autocor(vfloat(Y[:stockIndexSentiment_1])))
plot!(autocor(vfloat(Y[:stockIndexSentiment_2])))
plot(Y[:stockIndexSentiment])
plot!(Y[:DR])
@rput X
R"acf(Y[,'stockIndexUncertainty'])"
R"""
lag = 1
lead = 0
sz = dim(Y)[1]
print(summary(lm(DR[(1+lag):(sz-lead)]~stockIndexSentiment_1[(1+lead):(sz-lag)]*SentALL[(1+lead):(sz-lag)], data=Y)))
print(summary(lm(CF~stockIndexSentiment_1*SentALL, data=Y)))
print(summary(lm(CF[(1+lag):(sz-lead)]~diff(stockIndexSentiment_1)*diff(SentALL), data=Y)))
"""
R"""
sz = dim(Y)[1]
print("AAA")
print(summary(lm(CF~SentALL, data=Y)))
print("BBB")
print(summary(lm(CF[2:sz]~diff(SentALL), data=Y)))
print("CCC")
print(summary(lm(CF[2:sz]~SentALL[1:sz-1], data=Y)))
print("DDD")
print(summary(lm(DR~SentALL, data=Y)))
print("EEE")
print(summary(lm(DR[2:sz]~diff(SentALL), data=Y)))
print("FFF")
print(summary(lm(DR[2:sz]~SentALL[1:sz-1], data=Y)))
"""


names(X)
lags = [1,2,0]
leads = [0,0,1]
vars = ["CF", "stockIndexSentiment_1", "stockIndexSentiment_1"]
vNames = ["CF", "TRMI_NS_sent", "TRMI_NS_sent"]
lmR(X, lags, leads, vars, vNames, true)
