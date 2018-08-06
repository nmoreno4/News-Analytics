push!(LOAD_PATH, "$(pwd())/panelregression")
using RCall, CSV, DataFrames, keeponly, splitperiod

@rlibrary plm

monthdf = splitperiod(df, 20)

@time valmonth = keeponlyptf(b, "value")
@time gromonth = keeponlyptf(b, "growth")

function regress(df, formule = "retadj~sent*EAD", typemod="within")
    @rput df
    @time R"df <- as.data.frame(lapply(df, unlist))"
    @time R"E <- plm::pdata.frame(df, index = c('permno', 'td'), drop.index=TRUE, row.names=TRUE)"
    R"print(as.formula($(formule)))"
    @time R"model <- plm::plm(as.formula($(formule)), data=E, model = $(typemod))"
    @time R"print(summary(model))"
end

@time regress(valmonth, "agg_20ret~SUM_20sent")
@time regress(gromonth)

R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
R"model <- plm::plm(retadj~sent+sent*EAD, data=E)"
