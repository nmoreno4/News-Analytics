push!(LOAD_PATH, "$(pwd())/Custom functions")
push!(LOAD_PATH, "$(pwd())/Ang et al")
push!(LOAD_PATH, "$(pwd())/CF_DR_News/Data Treatment/WRDSmodules")
using Mongo, TimeSeries, Plots, DataFrames, databaseQuerer, NaNMath, RCall, StatsBase, aggregateQueries, TimeSeriesFcts, WRDSdownload, HypothesisTests,otherAng, CSV, JLD2
# plotlyjs()

yend=2004
mend=6
dend=30

client = MongoClient()
MERGEconnect = MongoCollection(client, "NewsDB", "CRSPTRNAmerge4")
alldates = sort(Array{Dates.Date}(collect(fieldDistinct(MERGEconnect, ["date"])[1])))
alldates = filterdates(alldates, Dates.Date(yend,mend,dend))

VWsent, VWret, EWsent, EWret = aggregSentiment(alldates, MERGEconnect)
VWsentPos, VWret, EWsentPos, EWret = aggregSentiment(alldates, MERGEconnect, "Pos")
VWsentNeg, VWret, EWsentNeg, EWret = aggregSentiment(alldates, MERGEconnect, "Neg")

# b = VWsent[2:end]-VWsent[1:end-1]
# @rput VWret
# @rput VWsent
# R"acf(VWsent)"
# R"reg = lm(VWsent[2:3650] ~ b)"
# R"summary(reg)"


FFfactors = FF_factors_download(["01/01/2003", "$(mend)/$(dend)/$(yend)"], "FACTORS_DAILY")
if FFfactors[:date]!=alldates
    error("FF factors do not span over the same period as my dates")
end
Series = Dict("Mktsent"=>VWsent, "MktPos"=>VWsentPos, "MktNeg"=>VWsentNeg,
              "Mktret"=>FFfactors[:mktrf], "hml"=>FFfactors[:hml],
              "smb"=>FFfactors[:smb], "umd"=>FFfactors[:umd])

allresults = []
df = DataFrame(EW_return = Array{Float64, 1}(200)*NaN, EW_stdev = Array{Float64, 1}(200)*NaN, VW_return = Array{Float64, 1}(200)*NaN, VW_stdev = Array{Float64, 1}(200)*NaN, weight_port = Array{Float64, 1}(200)*NaN, BM_rank = Array{Float64, 1}(200)*NaN, Size_rank = Array{Float64, 1}(200)*NaN, Stories_count = Array{Float64, 1}(200)*NaN, EW_Sent = Array{Float64, 1}(200)*NaN, alpha4factors = Array{Float64, 1}(200)*NaN, alpha3factors = Array{Float64, 1}(200)*NaN, alpha1factors = Array{Float64, 1}(200)*NaN, betaexpost = Array{Float64, 1}(200)*NaN, Avg_α_coeff = Array{Float64, 1}(200)*NaN, Avg_α_tstat = Array{Float64, 1}(200)*NaN, Avg_β_coeff = Array{Float64, 1}(200)*NaN, Avg_β_tstat = Array{Float64, 1}(200)*NaN, Avg_ϵ² = Array{Float64, 1}(200)*NaN, Avg_resError = Array{Float64, 1}(200)*NaN)
setting=3
allreturnseries = []
allalphaseries = []
allbetaseries = []
allstoriesCountseries = []
allsentimentseries = []
for setting in [3,15]
    ##### Setting the Variables #########
    if setting in [1,2,3,13,14,15]
        formationspan = Dates.Month(1)
        postformationspan = Dates.Month(1)
        minobs = (10, 15)
    elseif setting in [4,5,6,16,17,18]
        formationspan = Dates.Month(3)
        postformationspan = Dates.Month(1)
        minobs = (15, 45)
    elseif setting in [7,8,9,19,20,21]
        formationspan = Dates.Month(6)
        postformationspan = Dates.Month(1)
        minobs = (20, 60)
    elseif setting in [10,11,12,22,23,24]
        formationspan = Dates.Month(12)
        postformationspan = Dates.Month(1)
        minobs = (30, 90)
    end
    if setting%3==0
        retlag = 0
    elseif setting%3==1
        retlag=1
    elseif setting%3==2
        retlag=-1
    end
    if setting <= 12
        idionews = true
    else
        idionews = false
    end
    firstdate = Dates.Date(2003,1,31)
    lastdate = Dates.Date(yend,mend,dend)
    ΔNA = false
    βAsym = false
    classvar = ["β" , "_coeff"]
    controlmarketret = true
    controlmarketsent = false
    FFcontrol = false
    freqinterval = Dates.Month(1)
    crtspec = "setting : $setting - retlag : $retlag - $formationspan - idionews : $idionews \n"
    finalresults = []
    # (nextper, prevper)
    lagspecs = [(Dates.Month(0), formationspan), # same period as ptf formation
                (postformationspan, Dates.Month(0))] # following period

    params = Dict("idionews"=>idionews, "retlag"=>retlag, "minobs"=>minobs,
                  "controlmarketret"=>controlmarketret, "controlmarketsent"=>controlmarketsent, "FFcontrol"=>FFcontrol, "βAsym"=>βAsym)

    #### Assign stocks to a portfolio ranking ######
    FormationPeriods = firstdate:freqinterval:lastdate
    phase = "classification"
    # Dictionary where I store the breakpoints for the quintiles
    ClassregResults = Dict("α_coeff" => Dict(), "α_tstat" => Dict(),
                      "β_coeff" => Dict(), "β_tstat" => Dict(),
                      "βPos_coeff" => Dict(), "βPos_tstat" => Dict(),
                      "βNeg_coeff" => Dict(), "βNeg_tstat" => Dict(),
                      "γ_coeff" => Dict(), "γ_tstat" => Dict(),
                      "ζ_coeff" => Dict(), "ζ_tstat" => Dict(),
                      "𝐬_coeff" => Dict(), "𝐬_tstat" => Dict(),
                      "𝐡_coeff" => Dict(), "𝐡_tstat" => Dict(),
                      "𝐮_coeff" => Dict(), "𝐮_tstat" => Dict(),
                      "adjR²" => Dict(), "ϵ²" => Dict(),
                      "P(F-stat)" => Dict(),
                      "residualStdError" => Dict())
    cc = [0,0,0,0]
    for crtPeriodFormation in FormationPeriods
        #### Gather all sentiments and returns at the date ####
        print("$crtPeriodFormation - $crtspec")
        perDict = Dict()
        # Find all entries (irrespective of permID) matching over the current period
        # of portfolio formation.
        cursor = matchingDay(MERGEconnect, crtPeriodFormation, formationspan)
        # Order all those matching entries and regroup them by permID in the form:
        # permID => (date=>Date[])
        #        => (adjret=>Float64[])
        #        => (sentClasRel=>Float64[])
        #        => (Pos=>Float64[])
        #        => (Neg=>Float64[])
        for entry in cursor
            perDict = matchesToDic(entry, perDict)
        end
        # Loop over all the permIDs from the Dict()
        # Store all the results of the regression in ClassregResults, a dictionary
        # which we will use to compute the quintiles. Each variable results are stored
        # in arrays and are regrouped by periods
        for stock in perDict
            cc, ClassregResults = mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, ClassregResults)
        end
    end

    # Store the quintiles accoring to the classification variable (β)
    if βAsym
        percclass = Dict("Pos"=>Dict(), "Neg"=>Dict())
        for date in ClassregResults["$(classvar[1])Pos$(classvar[2])"]
            percclass["Pos"][date[1]] = percentile(date[2], [20,40,60,80])
        end
        for date in ClassregResults["$(classvar[1])Neg$(classvar[2])"]
            percclass["Neg"][date[1]] = percentile(date[2], [20,40,60,80])
        end
    else
        percclass = Dict("sent"=>Dict())
        for date in ClassregResults["$(classvar[1])$(classvar[2])"]
            percclass["sent"][date[1]] = percentile(date[2], [20,40,60,80])
        end
    end

    # Dictionary where I store for each date all the stock permIDs
    if βAsym
        classification = Dict("Pos"=>Dict(), "Neg"=>Dict())
    else
        classification = Dict("sent"=>Dict())
    end
    # Dictionary where I store the post-classification results
    regRes = Dict("α" => Dict(), "β" => Dict(), "ϵ²" => Dict(), "resError" => Dict(),
                  "β_tstat" => Dict(), "α_tstat" => Dict(), "βPos" => Dict(),
                  "βPos_tstat" => Dict(), "βNeg" => Dict(), "βNeg_tstat" => Dict())
    if βAsym
        postregRes = Dict("Pos" => deepcopy(regRes), "Neg" => deepcopy(regRes))
    else
        postregRes = Dict("sent" => deepcopy(regRes))
    end
    cc = [0,0,0,0]
    phase = "ranking"
    #===========================================
    Classify on each date each stock in the quintiles + get the regression results (α, β, etc...)
    - classification : Dictionary listing all stocks in the quintiles at each date
    - postregRes : Results of the regressions
    ===========================================#
    for crtPeriodFormation in FormationPeriods
        #### Gather all sentiments and returns at the date ####
        print(crtPeriodFormation)
        print(cc)
        perDict = Dict()
        cursor = matchingDay(MERGEconnect, crtPeriodFormation, formationspan)
        for entry in cursor
            perDict = matchesToDic(entry, perDict)
        end
        if βAsym
            for stock in perDict
                cc, classification["Pos"], postregRes["Pos"] = mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, postregRes["Pos"], percclass["Pos"], classification["Pos"], "$(classvar[1])Pos$(classvar[2])")
                cc, classification["Neg"], postregRes["Neg"] = mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, postregRes["Neg"], percclass["Neg"], classification["Neg"], "$(classvar[1])Neg$(classvar[2])")
            end
        else
            for stock in perDict
                cc, classification["sent"], postregRes["sent"] = mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, postregRes["sent"], percclass["sent"], classification, "$(classvar[1])$(classvar[2])")
            end
        end
    end

####!!!!!!!!!!!!!!!!#########
#Add the possibility to regress
#for β loadings on N.A. but also
#do the regressions without N.A.
#to compute a clean α against
#traditional risk factors.
####!!!!!!!!!!!!!!!!#########

    rdates = []
    for a in classification
        for b in a[2]
            push!(rdates, b[1])
        end
        break
    end
    sort!(rdates)
    Dates.month(rdates[1])
    FFfactorsmonthly = FF_factors_download(["$(Dates.month(rdates[1]))/$(Dates.day(rdates[1]))/$(Dates.year(rdates[1]))", "$(Dates.month(rdates[end])+1)/$(Dates.day(rdates[end]))/$(Dates.year(rdates[end]))"], "FACTORS_MONTHLY")
    Seriesmonthly = Dict("dates"=> FFfactorsmonthly[:date], "Mktret"=>FFfactorsmonthly[:mktrf], "hml"=>FFfactorsmonthly[:hml], "smb"=>FFfactorsmonthly[:smb], "umd"=>FFfactorsmonthly[:umd])


    for lagspec in lagspecs
        nextperlag = lagspec[2]
        prevperlag = lagspec[1]
        per = []
        postres = Dict("α" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []),
                       "α_tstat" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []),
                       "β" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []),
                       "ϵ²" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []),
                       "β_tstat" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []),
                       "resError" => Dict(1 => [], 2 => [], 3 => [], 4 => [], 5 => []))
        if βAsym
            allpostres = Dict("Pos"=>deepcopy(postres), "Neg"=>deepcopy(postres))
        else
            allpostres = Dict("sent"=>deepcopy(postres))
        end
        ttests = []
        cc = [0,0,0,0]
        for class in 1:5
            print(class)
            #### Gather all sentiments and returns at the date ####
            mycc = 0
            for βtype in classification
                mycc+=1
                if mycc == 1
                    phase = [class, "Pos"]
                    wdic = classification["Pos"]
                    sentType = "Pos"
                else
                    phase = [class, "Neg"]
                    wdic = classification["Neg"]
                    sentType = "Neg"
                end
                phase = [class, βtype[1]]
                if βtype[1]=="sent"
                    phase[2] = ""
                    sentType = "sent"
                end
                for date in wdic
                    perDict = Dict()
                    if date[1]+postformationspan < lastdate
                        cursor = postregression(MERGEconnect, date[2][class], date[1]-prevperlag, date[1]+nextperlag)
                        for entry in cursor
                            perDict = matchesToDic(entry, perDict)
                        end
                        for stock in perDict
                            cparams = deepcopy(params)
                            cparams["minobs"] = (10,15)
                            # allpostres[sentType] = mainreg(phase, cc, stock, date[1], cparams, Series, alldates, allpostres[sentType])
                        end
                    end
                end
                a = meanresults(class, wdic, MERGEconnect, nextperlag, prevperlag, Seriesmonthly)
                push!(per,a)
            end
        end

        print("Hey")

        # FinalReg = Dict(1 => Dict(), 2 => Dict(), 3 => Dict(), 4 => Dict(), 5 => Dict())
        # for regs in FinalReg
        #     class = regs[1]
        #     if βAsym
        #         regs[2]["Pos"] =[mean(allpostres["Pos"]["α"][class]),
        #                          mean(allpostres["Pos"]["α_tstat"][class]),
        #                          mean(allpostres["Pos"]["β"][class]),
        #                          mean(allpostres["Pos"]["β_tstat"][class]),
        #                          mean(allpostres["Pos"]["ϵ²"][class]),
        #                          mean(allpostres["Pos"]["resError"][class])]
        #         regs[2]["Neg"]=[mean(allpostres["Neg"]["α"][class]),
        #                        mean(allpostres["Neg"]["α_tstat"][class]),
        #                        mean(allpostres["Neg"]["β"][class]),
        #                        mean(allpostres["Neg"]["β_tstat"][class]),
        #                        mean(allpostres["Neg"]["ϵ²"][class]),
        #                        mean(allpostres["Neg"]["resError"][class])]
        #         # push!(ttests, [postres["ϵ²"][class], postres["α"][class], postres["resError"][class]])
        #     else
        #         regs[2]["sent"]=[mean(allpostres["sent"]["α"][class]),
        #                        mean(allpostres["sent"]["α_tstat"][class]),
        #                        mean(allpostres["sent"]["β"][class]),
        #                        mean(allpostres["sent"]["β_tstat"][class]),
        #                        mean(allpostres["sent"]["ϵ²"][class]),
        #                        mean(allpostres["sent"]["resError"][class])]
        #     end
        # end

        # push!(finalresults, [per, FinalReg])
        push!(finalresults, [per])
    end
    rc=0
    for lagspec in finalresults
        for row in lagspec[1]
            rc+=1
            cc=0
            for el in row
                cc+=1
                if cc!=14
                    df[rc,cc] = el
                end
            end
        end
        # rc=0
        # for regrow in ["Pos", "Neg"]
        #     for class = 1:5
        #         rc+=1
        #         cc = 9
        #         for rtype in lagspec[2][class][regrow]
        #             cc+=1
        #             df[rc,cc] = rtype
        #         end
        #     end
        # end
    end
    for lagspec in finalresults
        for row in  lagspec[1]
            push!(allreturnseries, row[14][2])
            # push!(allalphaseries, row[14][])
            # push!(allbetaseries, row[14][])
            push!(allstoriesCountseries, row[14][6])
            push!(allsentimentseries, row[14][7])
        end
    end
    # push!(allresults, finalresults)

    mkpath("/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting")
    output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting/res$(βAsym).csv"
    CSV.write(output, df)

    seriesdf = allreturnseries[1]
    for series in allreturnseries[2:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting/retseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    seriesdf = allstoriesCountseries[1]
    for series in allstoriesCountseries[2:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting/storiescountseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    seriesdf = allsentimentseries[1]
    for series in allsentimentseries[2:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting/sentimentseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    @save "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/Angetal/$setting/classification$(βAsym).csv" classification
end #for setting

output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/angetalvAsymbeta3month.csv"
CSV.write(output, df)

seriesdf = allreturnseries[1]
for series in allreturnseries[2:end]
    seriesdf = hcat(seriesdf, series)
end
seriesdf = DataFrames.DataFrame(seriesdf)
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/angetalseriesdfAsymbeta3month.csv"
CSV.write(output, seriesdf)


#
# finalresults = allresults[23]
# pvalue(OneSampleTTest(vec(Array{Float64}(finalresults[1][1][2][15][3])),
#                       vec(Array{Float64}(finalresults[1][2][2][15][3]))))






























function filterdates(alldates, lastdate, firstdate = Dates.Date(1,1,1))
    filteredarray = Date[]
    for el in alldates
        if firstdate <= el <= lastdate
            push!(filteredarray, el)
        end
    end
    return filteredarray
end

function matchesToDic(entry, monthdic)
    try
        push!(monthdic[entry["permno"]]["date"], entry["date"])
        push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
        push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
    catch
        monthdic[entry["permno"]] = Dict()
        monthdic[entry["permno"]]["date"] = Dates.Date[]
        monthdic[entry["permno"]]["adjret"] = Float64[]
        monthdic[entry["permno"]]["sentClasRel"] = Float64[]
        push!(monthdic[entry["permno"]]["date"], entry["date"])
        push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
        push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
    end
    return monthdic
end


function adjlagidx(sentidx, retlag, stock)
    lagidx = sentidx-retlag
    if lagidx[1]==0
        sentidx = sentidx[2:end]
        lagidx = lagidx[2:end]
    end
    if lagidx[end]>length(stock[2]["adjret"])
        sentidx = sentidx[1:end-1]
        lagidx = lagidx[1:end-1]
    end
    return sentidx, lagidx
end

function findMatchDates(stock, alldates)
    cc=0
    IDX = Int[]
    for i in alldates
        cc+=1
        if i in Set(stock[2]["date"])
            push!(IDX, cc)
        end
    end
    return IDX
end


function Rregressions(X, Y, MR, MS, HML, SMB, UMD, controlmarketret, controlmarketsent, FFcontrol)
    @rput X
    @rput Y
    @rput MR
    @rput MS
    @rput HML
    @rput SMB
    @rput UMD
    if controlmarketret && !controlmarketsent
        R"fit <- lm(Y ~ X + MR)"
        R"gamma = summary(fit)[['coefficients']]['MR',]"
    elseif !controlmarketret && !controlmarketsent
        R"fit <- lm(Y ~ X)"
    elseif controlmarketret && controlmarketsent
        if MS == X
            error("You should not control for the market sentiment if you are taking the market sentiment as explanatory variable")
        end
        R"fit <- lm(Y ~ X + MR + MS)"
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"zeta = summary(fit)[['coefficients']]['MS',]"
    elseif !controlmarketret && controlmarketsent
        if MS == X
            error("You should not control for the market sentiment if you are taking the market sentiment as explanatory variable")
        end
        R"fit <- lm(Y ~ X + MS)"
        R"zeta = summary(fit)[['coefficients']]['MS',]"
    elseif controlmarketret && !controlmarketsent && FFcontrol
        R"fit <- lm(Y ~ X + MR + SMB + HML + UMD)"
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"s = summary(fit)[['coefficients']]['SMB',]"
        R"h = summary(fit)[['coefficients']]['HML',]"
        R"u = summary(fit)[['coefficients']]['UMD',]"
    elseif controlmarketret && controlmarketsent && FFcontrol
        R"fit <- lm(Y ~ X + MS + MR + SMB + HML + UMD)"
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"zeta = summary(fit)[['coefficients']]['MS',]"
        R"s = summary(fit)[['coefficients']]['SMB',]"
        R"h = summary(fit)[['coefficients']]['HML',]"
        R"u = summary(fit)[['coefficients']]['UMD',]"
    else
        error("Wrong specification with controls given")
    end
    try
        R"alpha = summary(fit)[['coefficients']]['(Intercept)',]"
        R"beta = summary(fit)[['coefficients']]['X',]"
    catch
        R"X"
    end
    R"adjrsquared = summary(fit)[['adj.r.squared']]"
    R"residstderr = summary(fit)[['sigma']]"
    R"squarederror = sum(summary(fit)[['residuals']]^2)"
    R" p_fstat = 1-pf(summary(fit)[['fstatistic']][1], summary(fit)[['fstatistic']][2], summary(fit)[['fstatistic']][3])"
    @rget alpha
    @rget beta
    if controlmarketret
        @rget gamma
    else
        gamma = [NaN, NaN, NaN, NaN]
    end
    if controlmarketsent
        @rget zeta
    else
        zeta = [NaN, NaN, NaN, NaN]
    end
    if FFcontrol
        @rget s
        @rget h
        @rget u
    else
        s = [NaN, NaN, NaN, NaN]
        h = [NaN, NaN, NaN, NaN]
        u = [NaN, NaN, NaN, NaN]
    end
    # From R, the statistics for the coefficients are reported in the following order:
    # Estimate - Std. Error - t value - p value
    coeffs = Dict("α_coeff" => alpha[1], "α_tstat" => alpha[3],
                  "β_coeff" => beta[1], "β_tstat" => beta[3],
                  "γ_coeff" => gamma[1], "γ_tstat" => gamma[3],
                  "ζ_coeff" => zeta[1], "ζ_tstat" => zeta[3],
                  "𝐬_coeff" => s[1], "𝐬_tstat" => s[3],
                  "𝐡_coeff" => h[1], "𝐡_tstat" => h[3],
                  "𝐮_coeff" => u[1], "𝐮_tstat" => u[3])
    @rget adjrsquared
    @rget residstderr
    @rget p_fstat
    @rget squarederror
    regsummary = Dict("adjR²" => adjrsquared,
                      "ϵ²" => squarederror,
                      "P(F-stat)" => p_fstat,
                      "residualStdError" => residstderr)
    return coeffs, regsummary
end


function storeRegResults(regResults, coeffs, regsummary, crtPeriodFormation)
    try
        push!(regResults["α_coeff"][crtPeriodFormation],coeffs["α_coeff"])
        push!(regResults["β_coeff"][crtPeriodFormation],coeffs["β_coeff"])
        push!(regResults["γ_coeff"][crtPeriodFormation],coeffs["γ_coeff"])
        push!(regResults["ζ_coeff"][crtPeriodFormation],coeffs["ζ_coeff"])
        push!(regResults["𝐬_coeff"][crtPeriodFormation],coeffs["𝐬_coeff"])
        push!(regResults["𝐡_coeff"][crtPeriodFormation],coeffs["𝐡_coeff"])
        push!(regResults["𝐮_coeff"][crtPeriodFormation],coeffs["𝐮_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation],coeffs["α_tstat"])
        push!(regResults["β_tstat"][crtPeriodFormation],coeffs["β_tstat"])
        push!(regResults["γ_tstat"][crtPeriodFormation],coeffs["γ_tstat"])
        push!(regResults["ζ_tstat"][crtPeriodFormation],coeffs["ζ_tstat"])
        push!(regResults["𝐬_tstat"][crtPeriodFormation],coeffs["𝐬_tstat"])
        push!(regResults["𝐡_tstat"][crtPeriodFormation],coeffs["𝐡_tstat"])
        push!(regResults["𝐮_tstat"][crtPeriodFormation],coeffs["𝐮_tstat"])
        push!(regResults["adjR²"][crtPeriodFormation],regsummary["adjR²"])
        push!(regResults["ϵ²"][crtPeriodFormation],regsummary["ϵ²"])
        push!(regResults["P(F-stat)"][crtPeriodFormation],regsummary["P(F-stat)"])
        push!(regResults["residualStdError"][crtPeriodFormation],regsummary["residualStdError"])
    catch
        regResults["α_coeff"][crtPeriodFormation] = Float64[]
        regResults["β_coeff"][crtPeriodFormation] = Float64[]
        regResults["γ_coeff"][crtPeriodFormation] = Float64[]
        regResults["ζ_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐬_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐡_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐮_coeff"][crtPeriodFormation] = Float64[]
        regResults["α_tstat"][crtPeriodFormation] = Float64[]
        regResults["β_tstat"][crtPeriodFormation] = Float64[]
        regResults["γ_tstat"][crtPeriodFormation] = Float64[]
        regResults["ζ_tstat"][crtPeriodFormation] = Float64[]
        regResults["𝐬_tstat"][crtPeriodFormation] = Float64[]
        regResults["𝐡_tstat"][crtPeriodFormation] = Float64[]
        regResults["𝐮_tstat"][crtPeriodFormation] = Float64[]
        regResults["adjR²"][crtPeriodFormation] = Float64[]
        regResults["ϵ²"][crtPeriodFormation] = Float64[]
        regResults["P(F-stat)"][crtPeriodFormation] = Float64[]
        regResults["residualStdError"][crtPeriodFormation] = Float64[]
        push!(regResults["α_coeff"][crtPeriodFormation],coeffs["α_coeff"])
        push!(regResults["β_coeff"][crtPeriodFormation],coeffs["β_coeff"])
        push!(regResults["γ_coeff"][crtPeriodFormation],coeffs["γ_coeff"])
        push!(regResults["ζ_coeff"][crtPeriodFormation],coeffs["ζ_coeff"])
        push!(regResults["𝐬_coeff"][crtPeriodFormation],coeffs["𝐬_coeff"])
        push!(regResults["𝐡_coeff"][crtPeriodFormation],coeffs["𝐡_coeff"])
        push!(regResults["𝐮_coeff"][crtPeriodFormation],coeffs["𝐮_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation],coeffs["α_tstat"])
        push!(regResults["β_tstat"][crtPeriodFormation],coeffs["β_tstat"])
        push!(regResults["γ_tstat"][crtPeriodFormation],coeffs["γ_tstat"])
        push!(regResults["ζ_tstat"][crtPeriodFormation],coeffs["ζ_tstat"])
        push!(regResults["𝐬_tstat"][crtPeriodFormation],coeffs["𝐬_tstat"])
        push!(regResults["𝐡_tstat"][crtPeriodFormation],coeffs["𝐡_tstat"])
        push!(regResults["𝐮_tstat"][crtPeriodFormation],coeffs["𝐮_tstat"])
        push!(regResults["adjR²"][crtPeriodFormation],regsummary["adjR²"])
        push!(regResults["ϵ²"][crtPeriodFormation],regsummary["ϵ²"])
        push!(regResults["P(F-stat)"][crtPeriodFormation],regsummary["P(F-stat)"])
        push!(regResults["residualStdError"][crtPeriodFormation],regsummary["residualStdError"])
    end
    return regResults
end



function mainreg(regResults, cc, alldates, stock, retlag,  crtPeriodFormation, minobs, controlmarketret, controlmarketsent, FFcontrol, phase, marketSent, marketRet, hml, smb, umd, idionews, postres=0, class=0, postClassification = 0, classvar = 0, classification = 0, percclass = 0, sentType = "sentClasRel")
    cc[2]+=1
    if NaNMath.mean_count(stock[2][sentType])[2]>=minobs
        cc[1]+=1
        a = stock[2][sentType]
        d = length(Set(stock[2]["adjret"]))
        e = length(stock[2]["adjret"])
        if length(Set(stock[2]["date"])) < length(stock[2]["date"])
            cc[3]+=1
            stock[2][sentType], stock[2]["adjret"], stock[2]["date"] = correctDuplicateDates(stock, sentType)
            if length(stock[2][sentType]) != length(stock[2]["adjret"])
                stock[2][sentType] = stock[2][sentType][1:length(stock[2]["adjret"])]
                cc[4]+=1
            end
        end
        b = stock[2]["adjret"]
        f = stock[2][sentType]
        c = nonnanidx(stock[2][sentType])
        if idionews
            sentidx = nonnanidx(stock[2][sentType])
        else
            sentidx = nonnanidx(stock[2]["adjret"])
        end
        if NaNMath.mean_count(stock[2][sentType])[2]<minobs
            print("HELLO")
            print(a)
            print(b)
            print(c)
            print(d)
            print(e)
            print(stock[2][sentType])
        end
        try
            adjlagidx(sentidx, retlag, stock)
        catch
            print(stock[2])
            print("================================")
            print(sentidx)
        end
        sentidx, lagidx = adjlagidx(sentidx, retlag, stock)
        marketMatchinDates = findMatchDates(stock, alldates)
        try
            datestokeep = stock[2]["date"][sentidx]
        catch
            print(length(stock[2]["date"]))
            print(length(stock[2]["adjret"]))
            print(length(stock[2][sentType]))
            print(sentidx)
        end
        Y=0
        try
            Y = stock[2]["adjret"][lagidx]
        catch
            print(stock[2]["adjret"])
            print(sentidx)
            print(lagidx)
            print("$d - $e - $b - $c - $f")
            Y = stock[2]["adjret"][sentidx]
            cc[4]+=1
        end
        if idionews
            X = stock[2][sentType][sentidx]
        else
            try
                X = marketSent[marketMatchinDates[sentidx]]
            catch
                print(marketMatchinDates)
                print(sentidx)
                print(stock[2]["date"])
                marketMatchinDates = findMatchDates(stock[2], alldates)
                print(marketMatchinDates)
                print(marketMatchinDates[sentidx])
                print(length(stock[2]["date"]))
                print(marketMatchinDates[sentidx])
            end
        end
        MS = marketSent[marketMatchinDates[sentidx]]
        MR = marketRet[marketMatchinDates[sentidx]]
        HML = hml[marketMatchinDates[sentidx]]
        SMB = smb[marketMatchinDates[sentidx]]
        UMD = umd[marketMatchinDates[sentidx]]
        coeffs, regsummary = Rregressions(X, Y, MR, MS, HML, SMB, UMD, controlmarketret, controlmarketsent, FFcontrol)
        if phase == "classification"
            regResults = storeRegResults(regResults, coeffs, regsummary, crtPeriodFormation)
        elseif phase == "post"
            push!(postres["α"][class], coeffs["α_coeff"])
            push!(postres["β"][class], coeffs["β_coeff"])
            push!(postres["ϵ²"][class], regsummary["ϵ²"])
            push!(postres["resError"][class], regsummary["residualStdError"])
            push!(postres["β_tstat"][class], coeffs["β_tstat"])
        elseif phase == "ranking"
            if coeffs[classvar] < percclass[crtPeriodFormation][1]
                class = 1
            elseif percclass[crtPeriodFormation][1] <= coeffs[classvar] < percclass[crtPeriodFormation][2]
                class = 2
            elseif percclass[crtPeriodFormation][2] <= coeffs[classvar] < percclass[crtPeriodFormation][3]
                class = 3
            elseif percclass[crtPeriodFormation][3] <= coeffs[classvar] < percclass[crtPeriodFormation][4]
                class = 4
            elseif percclass[crtPeriodFormation][4] <= coeffs[classvar]
                class = 5
            end
            try
                push!(classification[crtPeriodFormation][class], stock[1])
            catch
                classification[crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(classification[crtPeriodFormation][class], stock[1])
            end
            try
                push!(postClassification["α"][crtPeriodFormation][class], coeffs["α_coeff"])
                push!(postClassification["β"][crtPeriodFormation][class], coeffs["β_coeff"])
                push!(postClassification["β_tstat"][crtPeriodFormation][class], coeffs["β_tstat"])
                push!(postClassification["ϵ²"][crtPeriodFormation][class], regsummary["ϵ²"])
                push!(postClassification["resError"][crtPeriodFormation][class], regsummary["residualStdError"])
            catch
                postClassification["α"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                postClassification["β"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                postClassification["β_tstat"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                postClassification["ϵ²"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                postClassification["resError"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(postClassification["α"][crtPeriodFormation][class], coeffs["α_coeff"])
                push!(postClassification["β"][crtPeriodFormation][class], coeffs["β_coeff"])
                push!(postClassification["β_tstat"][crtPeriodFormation][class], coeffs["β_tstat"])
                push!(postClassification["ϵ²"][crtPeriodFormation][class], regsummary["ϵ²"])
                push!(postClassification["resError"][crtPeriodFormation][class], regsummary["residualStdError"])
            end
        end #if phase
    end #if enough observation
    if phase == "classification"
        return cc, regResults
    elseif phase == "post"
        return postres
    elseif phase == "ranking"
        return cc, classification, postClassification
    end
end


function correctDuplicateDates(stock, sentType)
    crtdates = sort(collect(Set(stock[2]["date"])))
    looprets = copy(stock[2]["adjret"])
    loopsents = copy(stock[2][sentType])
    crtrets = Float64[]
    crtsents = Float64[]
    ccloc=0
    past = 0
    for i in looprets
        ccloc+=1
        if !isnan(loopsents[ccloc])
            push!(crtsents, loopsents[ccloc])
            past = 1
        end
        if ccloc%2 == 0
            push!(crtrets, i)
            if past == 0
                push!(crtsents, loopsents[ccloc])
            end
            past = 0
        end
    end
    return crtsents, crtrets, crtdates
end


function meanresults(crtquint, regRes, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    ret, VWret, wport, BMclass, Sizeclass, StoriesCount, SentClasRel = quintileret(crtquint, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    a = Float64[]
    ttests = []
    for row in ret
        push!(a, mean(row))
    end
    m = (mean(a)+1)^252-1
    sd = std(a)*(252^0.5)
    mVW = (mean(VWret)+1)^252-1
    sdVW = std(VWret)*(252^0.5)
    a = Float64[]
    for row in wport
        push!(a, mean(row))
    end
    push!(ttests, a)
    w = mean(a)
    a = Float64[]
    for row in BMclass
        push!(a, mean(row))
    end
    push!(ttests, a)
    BM = mean(a)
    a = Float64[]
    for row in Sizeclass
        push!(a, mean(row))
    end
    push!(ttests, a)
    Size = mean(a)
    a = Float64[]
    for row in StoriesCount
        push!(a, NaNMath.mean(row))
    end
    push!(ttests, a)
    Count =  NaNMath.mean(a)
    a = Float64[]
    for row in SentClasRel
        push!(a, NaNMath.mean(row))
    end
    push!(ttests, a)
    Sent =  NaNMath.mean(a)
    push!(ttests, regRes["α"][crtquint])
    malpha = mean(regRes["α"][crtquint])
    push!(ttests, regRes["β"][crtquint])
    mbeta = mean(regRes["β"][crtquint])
    push!(ttests, regRes["ϵ²"][crtquint])
    mepsilon = mean(regRes["ϵ²"][crtquint])
    # print(regRes)
    # print("hey")
    # push!(ttests, regRes["resError"][crtquint])
    mreserror = mean(regRes["resError"][crtquint])
    push!(ttests, regRes["β_tstat"][crtquint])
    mbetatstat = mean(regRes["β_tstat"][crtquint])
    return m, sd, mVW, sdVW, w, BM, malpha, Size, Count, Sent, mbeta, mepsilon, mreserror, mbetatstat, ttests
end

function quintileret(quint, classification, MERGEconnect, nextperlag, prevperlag, periodspan)
    resret = []
    resVWret = Float64[]
    reswport = []
    resBMclass = []
    resSizeclass = []
    resStoriesCount = []
    resSentClasRel = []
    for date in classification
        dateret = Float64[]
        datewport = Float64[]
        dateBMclass = Float64[]
        dateSizeclass = Float64[]
        dateStoriesCount = Float64[]
        dateSentClasRel = Float64[]
        for permno in date[2][quint]
            cursor = find(MERGEconnect,
                            Mongo.query("date" => Dict("\$gt"=>date[1]-prevperlag,
                                 "\$lte"=>date[1]+nextperlag),
                                        "permno" =>permno))
            rets = Float64[]
            wports = Float64[]
            BMclasss = Float64[]
            Sizeclasss = Float64[]
            StoriesCount = Float64[]
            SentClasRel = Float64[]
            for entry in cursor
                push!(rets, entry["adjret"])
                push!(wports, entry["wport"])
                ptf10x10 = entry["ptf_10by10_size_value"]
                crtBMclass = round((ceil(ptf10x10)-ptf10x10)*10)
                push!(BMclasss, crtBMclass)
                crtSizeclass = ceil(ptf10x10)
                push!(Sizeclasss, crtSizeclass)
                push!(StoriesCount, entry["storiesCount"])
                push!(SentClasRel, entry["sentClasRel"])
            end
            if length(rets)>0
                push!(dateret, geomean(rets+1)-1)
                push!(datewport, mean(wports))
                push!(dateBMclass, mean(BMclasss))
                push!(dateSizeclass, mean(Sizeclasss))
                push!(dateStoriesCount, mean(StoriesCount))
                push!(dateSentClasRel, mean(SentClasRel))
            end
        end
        push!(resret, dateret)
        push!(resVWret, NaNMath.sum(dateret.*(datewport./NaNMath.sum(datewport))))
        push!(reswport, datewport)
        push!(resBMclass, dateBMclass)
        push!(resSizeclass, dateSizeclass)
        push!(resStoriesCount, dateStoriesCount)
        push!(resSentClasRel, dateSentClasRel)
    end
    return resret, resVWret, reswport, resBMclass, resSizeclass, resStoriesCount, resSentClasRel
end
