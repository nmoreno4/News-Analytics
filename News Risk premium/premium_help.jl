using RCall

function VWeight(v, namestoVW)
    res = Dict()
    v = v[isnotmissing.(v[:cumret]),:]
    v = v[isnotmissing.(v[:wt]),:]
    totweight = custom_sum(v[:wt])
    stockweight = v[:wt] ./ totweight
    return custom_sum(v[namestoVW] .* stockweight)
end



function EWeight(v, namestoVW)
    res = Dict()
    v = v[isnotmissing.(v[:cumret]),:]
    v = v[isnotmissing.(v[:wt]),:]
    totweight = custom_sum(v[:wt])
    stockweight = custom_mean(v[:wt]) ./ totweight
    return custom_sum(v[namestoVW] .* stockweight)
end



function Rplot(x)
    @rput x
    R"plot(x)"
end


function atest(byday, data)
    ranks = [0,0,0]'
    a = by(data, :permno) do p1
    # for permno in sort(collect(Set(y1[:permno])))
    #     p1 = y1[y1[:permno].==permno,:]

        isfirst = true
        rightpers = []
        for i in 1:length(byday[:perid])
            if byday[:perid][i] in p1[:perid] && isfirst
                rightpers = byday[i,:]
                isfirst = false
            elseif byday[:perid][i] in p1[:perid] && !isfirst
                rightpers = vcat(rightpers, byday[i,:])
            end
        end

        rmat = hcat(rightpers[:x1], p1[[:cumret, :sum_perNbStories_]])
        rmat[:sum_perNbStories_] = replace(rmat[:sum_perNbStories_], missing=>0)
        names!(rmat, [:mktret, :stockret, :stockcov])
        @rput rmat
        R"mod = lm(stockret ~ mktret + mktret:stockcov, data=rmat)"
        R"res = summary(mod)";
        @rget res
        try
            if size(res[:coefficients], 1) ==3
                ranks = vcat(ranks, [p1[:permno][1], res[:coefficients][2,3], res[:coefficients][3,3]]')
            else
                ranks = vcat(ranks, [p1[:permno][1], res[:coefficients][2,3], NaN]')
            end
        catch
            print("failed")
            print(p1[:permno][1])
        end
    end
    return ranks
end



function HS_LS_classification(byday, y1)
    firstyear = @time atest(byday, y1)
    foo = DataFrame(firstyear[2:end,:])
    names!(foo, [:permno, :mktsens, :interactsens])
    foo[:interactsens] = replace(foo[:interactsens], missing=>NaN)
    # bar = foo[foo[:mktsens].>3,:]
    threshs = custom_perc(foo[:interactsens], 0:10:100)
    stockClass = Dict()
    for i in 1:(length(threshs)-1)
        stockClass[i] = foo[(foo[:interactsens].>threshs[i]) .& (foo[:interactsens].<threshs[i+1]),:permno]
    end
    return stockClass
end



function classifyconditionalsensitivity(data, freq, freqIds)
    data[:periodclassifier] = string(0)
    for i in 1:length(data[:periodclassifier])
        data[:periodclassifier][i] = string(freqIds[freq][Int(data[:perid][i])])
    end

    @time a = by(data, :periodclassifier) do df
        res = Dict()
        byday = by(df[[:perid, :permno, :cumret, :wt]], :perid) do df2
            VWeight(df2, :cumret)
        end
        res["stock_groups"] = HS_LS_classification(byday, df)
    end

    return a
end




function sensrankedptfs(ptfperf, freq)
    freqIds = freqIdentifiers()

    stockrankings = classifyconditionalsensitivity(ptfperf, freq, freqIds)

    ptfperf[:periodclassifier] = string(0)
    for i in 1:length(ptfperf[:periodclassifier])
        ptfperf[:periodclassifier][i] = string(freqIds[freq][Int(ptfperf[:perid][i])])
    end

    ptfperf[:NS_rank_crt] = 0
    ptfperf[:NS_rank_prev] = 0

    @time for row in 1:size(ptfperf,1)
        crtper = ptfperf[row,:periodclassifier]
        crtstock = ptfperf[row,:permno]
        crtranks = stockrankings[string.(stockrankings[:periodclassifier]).=="2007", :x1]
        for r in 1:10
            if crtstock in crtranks[1][r]
                ptfperf[row, :NS_rank_crt] = r
                break
            end
        end
    end

    allptfs = Dict()
    for i in 1:10
        spillers = ptfperf[ptfperf[:NS_rank_crt].==i,:]
        spillret = Dict()
        for per in string.(stockrankings[:periodclassifier])
            y1 = spillers[spillers[:periodclassifier].==per,:]
            byday = by(y1[[:perid, :permno, :cumret, :wt]], :perid) do df
                VWeight(df, :cumret)
            end
            spillret[per] = byday[:x1]
        end
        resspillret = Float64[]
        for per in string.(stockrankings[:periodclassifier])
            push!(resspillret, cumret(spillret[per]))
        end
        allptfs[i] = resspillret
    end
    allptfs = DataFrame(allptfs)
    return allptfs
end
