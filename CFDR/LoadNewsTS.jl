module LoadNewsTS
using DataFrames, CSV, Dates, StatsBase, Statistics
export loadTRMI, loadCFDR, loadRecession, loadTRNA, loadCRSP_Mkt

function loadTRMI(freq=Month(1), rootdir="/home/nicolas/Documents/CF DR paper")
    TRMIsocial = CSV.read("$(rootdir)/social_$(freq).csv")
    TRMIsocial[:date] = Date.(TRMIsocial[:date] .- Second(1))
    TRMInewssocial = CSV.read("$(rootdir)/news_social_$(freq).csv")
    TRMInewssocial[:date] = Date.(TRMInewssocial[:date] .- Second(1))
    TRMInews = CSV.read("$(rootdir)/news_$(freq).csv")
    TRMInews[:date] = Date.(TRMInews[:date] .- Second(1))
    return TRMIsocial, TRMInewssocial, TRMInews
end

function loadCFDR(rootdir="/home/nicolas/Documents/CF DR paper"; filename="results_CFDR_topics_complete")
    CFDR = CSV.read("$(rootdir)/$(filename).csv")
    cfdrdate(x) = ceil(DateTime(string(x), "yyyymm") + Minute(1), Month(1)) - Second(1)
    CFDR[:date] = Date.(cfdrdate.(CFDR[:date]))
    return CFDR
end

function loadTRNA(freq, WS, rootdir="/home/nicolas/Documents/CF DR paper")
    TRNA = CSV.read("$(rootdir)/$(freq)_$(WS)_MktNA.csv")
    TRNA[:date] = Date.(TRNA[:date] .- Second(1))
    return TRNA
end

function loadRecession(rootdir="/home/nicolas/Documents/CF DR paper")
    USREC = CSV.read("$(rootdir)/USREC.csv")
    USREC[:USREC] = Int.(USREC[:USREC]); USREC[:date] = Date.(USREC[:date] .- Day(1))
    USREC = cycleLoc(USREC); USREC[:latehalf] = 0
    for i in 1:size(USREC,1)
        if USREC[:cycleStrength][i]>0.5
            USREC[:latehalf][i] = 1
        end
    end
    return USREC
end

function cycleLoc(X)
    crt = X[:USREC][1]
    X[:cycleStrength] = 0.0
    splitIdx = [1]
    for i in 2:size(X,1)
        if crt!=X[:USREC][i]
            push!(splitIdx, i)
            crt = X[:USREC][i]
        end
    end
    push!(splitIdx, size(X,1))
    for i in 2:length(splitIdx)
        crtdf = X[splitIdx[i-1]:splitIdx[i], :]
        X[:cycleStrength][splitIdx[i-1]:splitIdx[i]] = collect(1:size(crtdf,1)) ./ size(crtdf,1)
    end
    return X
end

function loadCRSP_Mkt(rootdir="/home/nicolas/Documents/CF DR paper")
    MktRet = CSV.read("$(rootdir)/marketRet.csv")
    mktdate(x) = ceil(DateTime(string(x), "yyyymmdd") + Minute(1), Month(1)) - Second(1)
    MktRet[:date] = Date.(mktdate.(MktRet[:date]))
    return MktRet
end

end #module
