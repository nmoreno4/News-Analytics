push!(LOAD_PATH, "$(pwd())/panelregression")
using RCall, CSV, DataFrames, keeponekind, splitperiod

@rlibrary plm
@rlibrary stargazer
#add lagged newsday, Value return

@time monthdf = removetdrows(df, 20)

@time valmonth = keeponlyptf(monthdf, "value")
@time gromonth = keeponlyptf(monthdf, "growth")

@time weekdf = removetdrows(df, 5)

@time valweek = keeponlyptf(weekdf, "value")
@time groweek = keeponlyptf(weekdf, "growth")

function regress(df, formule = "retadj~lagMA_20__1sent"; typemod="random")
    @rput df
    @time R"df <- as.data.frame(lapply(df, unlist))"
    @time R"E <- plm::pdata.frame(df, index = c('permno', 'td'), drop.index=TRUE, row.names=TRUE)"
    R"print(as.formula($(formule)))"
    @time R"model <- plm::plm(as.formula($(formule)), data=E, model = $(typemod))"
    @time R"print(summary(model))"
    @time R"print(stargazer::stargazer(model))"
end


@time regress(valmonth, "agg_20ret~MA_20sent*agg_20EAD+MA_20VWvaluesent+MA_20VWgrowthsent+MA_20hmlsent+lagMA_20__1hmlsent+lagMA_20__2hmlsent+lagMA_20__3hmlsent+lagMA_20__4hmlsent+lagMA_20__5hmlsent", typemod = "random")
@time regress(gromonth, "agg_20ret~MA_20sent*agg_20EAD+MA_20VWvaluesent+MA_20VWgrowthsent+MA_20hmlsent+lagMA_20__1hmlsent+lagMA_20__2hmlsent+lagMA_20__3hmlsent+lagMA_20__4hmlsent+lagMA_20__5hmlsent")
@time regress(monthdf, "agg_20ret~MA_20sent*agg_20EAD+MA_20VWvaluesent+MA_20VWgrowthsent+MA_20hmlsent+lagMA_20__1hmlsent+lagMA_20__2hmlsent+lagMA_20__3hmlsent+lagMA_20__4hmlsent+lagMA_20__5hmlsent")
@time regress(df, "retadj ~ sent*EAD*isgrowth+sent*EAD*isvalue+sent*lag1EAD*isvalue+sent*lag1EAD*isgrowth+sent*lag2EAD*isvalue+sent*lag2EAD*isgrowth+sent*lag_1EAD*isvalue+sent*lag_1EAD*isgrowth+sent*lag_1newsday*isvalue+sent*lag_1newsday*isgrowth+sent*EAD*MA_20sent*isvalue+sent*EAD*MA_20sent*isgrowth+mktrf+hml+smb+umd+lag_1ret+isvalue*VWvaluesent+isgrowth*VWgrowthsent")
valmonth[:lagMA_5__1VWvaluesent]
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"

a = monthdf[(monthdf[:permno].==10001),:]
b = Array{Float64}(a[:lagMA_20__1hmlsent])
e = Array{Float64}(a[:lagMA_20__2hmlsent])
f = Array{Float64}(a[:lagMA_20__3hmlsent])
g = Array{Float64}(a[:lagMA_20__1VWvaluesent])
h = Array{Float64}(a[:lagMA_20__2VWvaluesent])
i = Array{Float64}(a[:lagMA_20__3VWvaluesent])
d = Array{Float64}(a[:MA_20hmlsent])
c = Array{Float64}(a[:hml])

@rput b
@rput c
@rput d
@rput e
@rput f
@rput g
@rput h
@rput i
R"mod = lm(c~d)"
R"summary(mod)"
