module TrendCycle

using RCall, SparseArrays, StatsBase, FindFcts, DataFrames, Dates
export HPfilter, neverHPfilter, granger, crossCorrel

function HPfilter(y::Vector{Float64}, lambda::Number)
    n = length(y)
    @assert n >= 4

    diag2 = lambda*ones(n-2)
    diag1 = [ -2lambda; -4lambda*ones(n-3); -2lambda ]
    diag0 = [ 1+lambda; 1+5lambda; (1+6lambda)*ones(n-4); 1+5lambda; 1+lambda ]

    D = spdiagm(-2=>diag2, -1=>diag1, 0=>diag0, 1=>diag1, 2=>diag2)

    return D\y
end

function neverHPfilter(NSdf, h, p, dateCol=:perID, varCol=:NS)
    NSdf = deleteMissingRows(NSdf, varCol)
    idx = Dates.Date.(NSdf[:,dateCol])
    NS = NSdf[:,varCol]
    R"remove(list = ls())"
    @rput NS
    @rput idx
    R"""
    library(zoo)
    library(xts)
    library(knitr)
    library(neverhpfilter)
    M = xts(NS, order.by = idx)
    colnames(M) <- "x"
    news_filter <- yth_filter(M, h = $h, p = $p)
    news_reg <- yth_glm(M, h = $h, p = $p)
    news_filter <- data.frame(date=index(news_filter), coredata(news_filter))
    """
    @rget news_filter
    colnames = names(news_filter)
    news_filter = convert(DataFrame, replace(convert(Matrix,news_filter), NaN=>missing))
    names!(news_filter, colnames)
    @rget news_reg
    return news_filter, news_reg
end


function granger()
end


function crossCorrel()
    crosscor()
end

end #module
