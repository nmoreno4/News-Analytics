push!(LOAD_PATH, "$(pwd())/Custom functions")
push!(LOAD_PATH, "$(pwd())/Ang et al")
push!(LOAD_PATH, "$(pwd())/CF_DR_News/Data Treatment/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/RelVGnews/myModules")
import WRDSdownload.FF_factors_download, TimeSeriesFcts.nonnanidx,
       databaseQuerer.fieldDistinct, otherAng.mainreg, otherAng.meanresults,
       aggregateQueries.aggregSentiment, otherAng.filterdates, aggregateQueries.matchingDay,
       otherAng.matchesToDic, aggregateQueries.postregression

using Mongo, TimeSeries, Plots, DataFrames, NaNMath, RCall,
      StatsBase, HypothesisTests, CSV, JLD2
# plotlyjs()

datarootpath = "/home/nicolas/Data/Results/Ang et al"
ystart, mstart, dstart = 2003, 1, 1
yend, mend, dend = 2016, 6, 30

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


FFfactors = FF_factors_download(["$(mstart)/$(dstart)/$(ystart)", "$(mend)/$(dend)/$(yend)"], "FACTORS_DAILY")
if FFfactors[:date]!=alldates
    error("FF factors do not span over the same period as my dates")
end
Series = Dict("Mktsent"=>VWsent, "MktPos"=>VWsentPos, "MktNeg"=>VWsentNeg,
              "Mktret"=>FFfactors[:mktrf], "hml"=>FFfactors[:hml],
              "smb"=>FFfactors[:smb], "umd"=>FFfactors[:umd], "date"=>FFfactors[:date])

df = DataFrame(EW_return = Array{Float64, 1}(40)*NaN, EW_stdev = Array{Float64, 1}(40)*NaN,
               VW_return = Array{Float64, 1}(40)*NaN, VW_stdev = Array{Float64, 1}(40)*NaN,
               weight_port = Array{Float64, 1}(40)*NaN, BM_rank = Array{Float64, 1}(40)*NaN,
               Size_rank = Array{Float64, 1}(40)*NaN, Stories_count = Array{Float64, 1}(40)*NaN,
               EW_Sent = Array{Float64, 1}(40)*NaN, alpha4factors = Array{Float64, 1}(40)*NaN,
               alpha3factors = Array{Float64, 1}(40)*NaN, alpha1factors = Array{Float64, 1}(40)*NaN,
               betaexpost = Array{Float64, 1}(40)*NaN, Avg_α_coeff = Array{Float64, 1}(40)*NaN,
               Avg_α_tstat = Array{Float64, 1}(40)*NaN, Avg_β_coeff = Array{Float64, 1}(40)*NaN,
               Avg_β_tstat = Array{Float64, 1}(40)*NaN, Avg_ϵ² = Array{Float64, 1}(40)*NaN,
               Avg_resError = Array{Float64, 1}(40)*NaN)
setting=6
for setting in [24]
    allresults, allreturnseries, allalphaseries = [], [], []
    allbetaseries, allstoriesCountseries, allsentimentseries = [], [], []
    df = DataFrame(EW_return = Array{Float64, 1}(40)*NaN, EW_stdev = Array{Float64, 1}(40)*NaN,
                   VW_return = Array{Float64, 1}(40)*NaN, VW_stdev = Array{Float64, 1}(40)*NaN,
                   weight_port = Array{Float64, 1}(40)*NaN, BM_rank = Array{Float64, 1}(40)*NaN,
                   Size_rank = Array{Float64, 1}(40)*NaN, Stories_count = Array{Float64, 1}(40)*NaN,
                   EW_Sent = Array{Float64, 1}(40)*NaN, alpha4factors = Array{Float64, 1}(40)*NaN,
                   alpha3factors = Array{Float64, 1}(40)*NaN, alpha1factors = Array{Float64, 1}(40)*NaN,
                   betaexpost = Array{Float64, 1}(40)*NaN, Avg_α_coeff = Array{Float64, 1}(40)*NaN,
                   Avg_α_tstat = Array{Float64, 1}(40)*NaN, Avg_β_coeff = Array{Float64, 1}(40)*NaN,
                   Avg_β_tstat = Array{Float64, 1}(40)*NaN, Avg_ϵ² = Array{Float64, 1}(40)*NaN,
                   Avg_resError = Array{Float64, 1}(40)*NaN)
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
        print("$crtspec - $crtPeriodFormation")
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
    print("ranking phase")
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
                cc, classification["sent"], postregRes["sent"] = mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, postregRes["sent"], percclass["sent"], classification["sent"], "$(classvar[1])$(classvar[2])")
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
        nextperlag = lagspec[1]
        prevperlag = lagspec[2]
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
                if βtype[1]=="sent"
                    phase = [class, "sent"]
                    wdic = classification["sent"]
                else
                    if mycc == 1
                        phase = [class, "Pos"]
                        wdic = classification["Pos"]
                        sentType = "Pos"
                    else
                        phase = [class, "Neg"]
                        wdic = classification["Neg"]
                        sentType = "Neg"
                    end
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

    mkpath("$(datarootpath)/$setting")
    output = "$(datarootpath)/$setting/res$(βAsym).csv"
    CSV.write(output, df)

    seriesdf = rdates
    for series in allreturnseries[1:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "$(datarootpath)/$setting/retseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    seriesdf = rdates
    for series in allstoriesCountseries[1:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "$(datarootpath)/$setting/storiescountseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    seriesdf = rdates
    for series in allsentimentseries[1:end]
        seriesdf = hcat(seriesdf, series)
    end
    seriesdf = DataFrames.DataFrame(seriesdf)
    output = "$(datarootpath)/$setting/sentimentseries$(βAsym).csv"
    CSV.write(output, seriesdf)

    @save "$(datarootpath)/$setting/classification$(βAsym).jld2" classification
end #for setting


input = "$(datarootpath)/15/retseriesfalse.csv"
a = CSV.read(input)
sameper = Array{Float64}(a[1:end, 2:6])
nextper = Array{Float64}(a[1:end, 7:11])
@rput sameper
@rput nextper
R"monotonicity::monoRelation(sameper,1000,TRUE,FALSE,6)"
R"monotonicity::monoSummary(sameper,1000,100,TRUE,FALSE,FALSE,6)"
R"(colMeans(sameper)+1)^12-1"
# seriesmat = zeros(length(allreturnseries[1]), 5,length(allreturnseries)/5)*NaN
# cc = 0
# for col in allreturnseries
#     cc+=1
#     seriesmat[:,Int(((cc-1)%5)+1), Int(ceil(cc/5))] = col
# end
#
# for i in 1:size(seriesmat, 3)
# end
#
# a = seriesmat[:,:,2]
# @rput a
# R"monotonicity::monoRelation(a,1000,TRUE,FALSE,6)"
# (mean(a[:,1])+1)^12-1
# (mean(a[:,2])+1)^12-1
# (mean(a[:,3])+1)^12-1
# (mean(a[:,4])+1)^12-1
# (mean(a[:,5])+1)^12-1
# std(a[:,5])*(12^0.5)
