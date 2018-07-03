module otherAng
using RCall, NaNMath, TimeSeriesFcts, Mongo, StatsBase, HypothesisTests
export filterdates, matchesToDic, mainreg, meanresults

function filterdates(alldates, lastdate, firstdate = Dates.Date(1,1,1))
    filteredarray = Date[]
    for el in alldates
        if firstdate <= el <= lastdate
            push!(filteredarray, el)
        end
    end
    return filteredarray
end


"""
Order all those matching entries and regroup them by permID in the form:
permID => (date=>Date[])
       => (adjret=>Float64[])
       => (sentClasRel=>Float64[])
       => (Pos=>Float64[])
       => (Neg=>Float64[])
"""
function matchesToDic(entry, monthdic)
    try
        push!(monthdic[entry["permno"]]["date"], entry["date"])
        push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
        push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        push!(monthdic[entry["permno"]]["Pos"], entry["Pos"])
        push!(monthdic[entry["permno"]]["Neg"], entry["Neg"])
    catch
        monthdic[entry["permno"]] = Dict()
        monthdic[entry["permno"]]["date"] = Dates.Date[]
        monthdic[entry["permno"]]["adjret"] = Float64[]
        monthdic[entry["permno"]]["sentClasRel"] = Float64[]
        monthdic[entry["permno"]]["Pos"] = Float64[]
        monthdic[entry["permno"]]["Neg"] = Float64[]
        push!(monthdic[entry["permno"]]["date"], entry["date"])
        push!(monthdic[entry["permno"]]["adjret"], entry["adjret"])
        push!(monthdic[entry["permno"]]["sentClasRel"], entry["sentClasRel"])
        push!(monthdic[entry["permno"]]["Pos"], entry["Pos"])
        push!(monthdic[entry["permno"]]["Neg"], entry["Neg"])
    end
    return monthdic
end


"""
Returns the lagged (forward or backwards depending on retlag) idx
taking into consideration the possibility of falling at the very
first of last period, in which case those periods are discarded from the
lagged and the regular sent idx.
"""
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


function dummyAsymSent(X, polarity=1)
    res = Float64[]
    for x in X
        if (x>=0 && polarity==1) || (x<=0 && polarity==-1)
            push!(res, x-(rand()/100000))
        else
            push!(res, rand()/1000000)
        end
    end
    return res
end


function Rregressions(X, Y, MR, MS, HML, SMB, UMD, controlmarketret, controlmarketsent, FFcontrol, βAsym, sentType="sentClasRel")
    if βAsym
        X1 = X["Pos"]
        X2 = X["Neg"]
        X3 = X["sentClasRel"]
        X1 = dummyAsymSent(X3, 1)
        X2 = dummyAsymSent(X3, -1)
        @rput X1
        @rput X2
        @rput X3
    else
        X1 = X
        @rput X1
    end
    @rput Y
    @rput MR
    @rput MS
    @rput HML
    @rput SMB
    @rput UMD
    if controlmarketret && !controlmarketsent
        if βAsym
            R"fit <- lm(Y ~ X1 + X2 + MR)"
        else
            R"fit <- lm(Y ~ X1 + MR)"
        end
        R"gamma = summary(fit)[['coefficients']]['MR',]"
    elseif !controlmarketret && !controlmarketsent
        if βAsym
            R"fit <- lm(Y ~ X1 + X2)"
        else
            R"fit <- lm(Y ~ X1)"
        end
    elseif controlmarketret && controlmarketsent
        if MS == X
            error("You should not control for the market sentiment if you are taking the market sentiment as explanatory variable")
        end
        if βAsym
            R"fit <- lm(Y ~ X1 + X2 + MR + MS)"
        else
            R"fit <- lm(Y ~ X1 + MR + MS)"
        end
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"zeta = summary(fit)[['coefficients']]['MS',]"
    elseif !controlmarketret && controlmarketsent
        if MS == X
            error("You should not control for the market sentiment if you are taking the market sentiment as explanatory variable")
        end
        if βAsym
            R"fit <- lm(Y ~ X1 + X2 + MS)"
        else
            R"fit <- lm(Y ~ X1 + MS)"
        end
        R"zeta = summary(fit)[['coefficients']]['MS',]"
    elseif controlmarketret && !controlmarketsent && FFcontrol
        if βAsym
            R"fit <- lm(Y ~ X1 + X2 + MR + SMB + HML + UMD)"
        else
            R"fit <- lm(Y ~ X1 + MR + SMB + HML + UMD)"
        end
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"s = summary(fit)[['coefficients']]['SMB',]"
        R"h = summary(fit)[['coefficients']]['HML',]"
        R"u = summary(fit)[['coefficients']]['UMD',]"
    elseif controlmarketret && controlmarketsent && FFcontrol
        if βAsym
            R"fit <- lm(Y ~ X1 + X2 + MS + MR + SMB + HML + UMD)"
        else
            R"fit <- lm(Y ~ X1 + MS + MR + SMB + HML + UMD)"
        end
        R"gamma = summary(fit)[['coefficients']]['MR',]"
        R"zeta = summary(fit)[['coefficients']]['MS',]"
        R"s = summary(fit)[['coefficients']]['SMB',]"
        R"h = summary(fit)[['coefficients']]['HML',]"
        R"u = summary(fit)[['coefficients']]['UMD',]"
    else
        error("Wrong specification with controls given")
    end
    alpha, beta, betaPos, betaNeg = 0,0,0,0
    try
        R"alpha = summary(fit)[['coefficients']]['(Intercept)',]"
        if βAsym
            R"betaPos = summary(fit)[['coefficients']]['X1',]"
            R"betaNeg = summary(fit)[['coefficients']]['X2',]"
            @rget betaPos
            @rget betaNeg
            beta = [NaN, NaN, NaN, NaN]
        else
            R"print(summary(fit)[['coefficients']]['X1',])"
            R"beta = summary(fit)[['coefficients']]['X1',]"
            @rget beta
            print(beta)
            betaPos = [NaN, NaN, NaN, NaN]
            betaNeg = [NaN, NaN, NaN, NaN]
        end
    catch
        # R"print(X)"
        # R"print(Y)"
        R"print(X1)"
        # R"print('')"
        R"print(summary(fit))"
    end
    R"adjrsquared = summary(fit)[['adj.r.squared']]"
    R"residstderr = summary(fit)[['sigma']]"
    R"squarederror = sum(summary(fit)[['residuals']]^2)"
    R"p_fstat = 1-pf(summary(fit)[['fstatistic']][1], summary(fit)[['fstatistic']][2], summary(fit)[['fstatistic']][3])"
    @rget alpha
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
    print("hey")
    coeffs = Dict("α_coeff" => alpha[1], "α_tstat" => alpha[3],
                  "β_coeff" => beta[1], "β_tstat" => beta[3],
                  "βPos_coeff" => betaPos[1], "βPos_tstat" => betaPos[3],
                  "βNeg_coeff" => betaNeg[1], "βNeg_tstat" => betaNeg[3],
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
        push!(regResults["βPos_coeff"][crtPeriodFormation],coeffs["βPos_coeff"])
        push!(regResults["βNeg_coeff"][crtPeriodFormation],coeffs["βNeg_coeff"])
        push!(regResults["γ_coeff"][crtPeriodFormation],coeffs["γ_coeff"])
        push!(regResults["ζ_coeff"][crtPeriodFormation],coeffs["ζ_coeff"])
        push!(regResults["𝐬_coeff"][crtPeriodFormation],coeffs["𝐬_coeff"])
        push!(regResults["𝐡_coeff"][crtPeriodFormation],coeffs["𝐡_coeff"])
        push!(regResults["𝐮_coeff"][crtPeriodFormation],coeffs["𝐮_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation],coeffs["α_tstat"])
        push!(regResults["β_tstat"][crtPeriodFormation],coeffs["β_tstat"])
        push!(regResults["βPos_tstat"][crtPeriodFormation],coeffs["βPos_tstat"])
        push!(regResults["βNeg_tstat"][crtPeriodFormation],coeffs["βNeg_tstat"])
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
        regResults["βPos_coeff"][crtPeriodFormation] = Float64[]
        regResults["βNeg_coeff"][crtPeriodFormation] = Float64[]
        regResults["γ_coeff"][crtPeriodFormation] = Float64[]
        regResults["ζ_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐬_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐡_coeff"][crtPeriodFormation] = Float64[]
        regResults["𝐮_coeff"][crtPeriodFormation] = Float64[]
        regResults["α_tstat"][crtPeriodFormation] = Float64[]
        regResults["β_tstat"][crtPeriodFormation] = Float64[]
        regResults["βPos_tstat"][crtPeriodFormation] = Float64[]
        regResults["βNeg_tstat"][crtPeriodFormation] = Float64[]
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
        push!(regResults["βPos_coeff"][crtPeriodFormation],coeffs["βPos_coeff"])
        push!(regResults["βNeg_coeff"][crtPeriodFormation],coeffs["βNeg_coeff"])
        push!(regResults["γ_coeff"][crtPeriodFormation],coeffs["γ_coeff"])
        push!(regResults["ζ_coeff"][crtPeriodFormation],coeffs["ζ_coeff"])
        push!(regResults["𝐬_coeff"][crtPeriodFormation],coeffs["𝐬_coeff"])
        push!(regResults["𝐡_coeff"][crtPeriodFormation],coeffs["𝐡_coeff"])
        push!(regResults["𝐮_coeff"][crtPeriodFormation],coeffs["𝐮_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation],coeffs["α_tstat"])
        push!(regResults["β_tstat"][crtPeriodFormation],coeffs["β_tstat"])
        push!(regResults["βPos_tstat"][crtPeriodFormation],coeffs["βPos_tstat"])
        push!(regResults["βNeg_tstat"][crtPeriodFormation],coeffs["βNeg_tstat"])
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


"""
Stock is a dictionary of the sort:
stock  => (date=>Date[])
       => (adjret=>Float64[])
       => (sentClasRel=>Float64[])
       => (Pos=>Float64[])
       => (Neg=>Float64[])
cc[1] : nb of monthly stocks observations where I has enough observations
cc[2] : Total number of monthly stock observations
cc[3] : Total number of duplicate entries in the DB
cc[4] : Total number of duplicate where adjustment failed
"""
function mainreg(phase, cc, stock, crtPeriodFormation, params, Series, alldates, regResults, percclass = 0, classification = 0, classvar = "β_coeff")
    cc[2]+=1
    idionews=params["idionews"]
    retlag=params["retlag"]
    minobs=params["minobs"]
    controlmarketret=params["controlmarketret"]
    controlmarketsent=params["controlmarketsent"]
    FFcontrol=params["FFcontrol"]
    βAsym=params["βAsym"]
    # Only go further if I have the required minimum number of observations.
    # Return values are untouched and same as input if false.
    if NaNMath.mean_count(stock[2]["sentClasRel"])[2]>=minobs[1] && NaNMath.mean_count(stock[2]["adjret"])[2]>=minobs[2]
        cc[1]+=1
        # Check and correct if I have duplicate entries in the database
        if length(Set(stock[2]["date"])) < length(stock[2]["date"])
            cc[3]+=1
            # Adjust returns and sentiments to have a matching number at matching
            # dates
            stock[2]["Pos"], foo, bar = correctDuplicateDates(stock, "Pos")
            stock[2]["Neg"], foo, bar = correctDuplicateDates(stock, "Neg")
            stock[2]["sentClasRel"], stock[2]["adjret"], stock[2]["date"] = correctDuplicateDates(stock, "sentClasRel")
            # If correctDuplicateDates still fails, adjust length
            if length(stock[2]["sentClasRel"]) != length(stock[2]["adjret"])
                stock[2]["sentClasRel"] = stock[2]["sentClasRel"][1:length(stock[2]["adjret"])]
                cc[4]+=1
            end
        end

        marketMatchinDates = findMatchDates(stock, alldates)
        # Get the indices with values for right sentiment series:
        # Firm-specific NA if true, Market NA if wrong
        if idionews
            sentidx = nonnanidx(stock[2]["sentClasRel"])
        else
            sentidx = nonnanidx(Series["Mktsent"][marketMatchinDates])
        end
        retidx = nonnanidx(stock[2]["adjret"])
        dateidx = intersect(sentidx, retidx)
        # Returns the correct (adjusted) lagged idx
        dateidx, lagidx = adjlagidx(dateidx, retlag, stock)
        try
            datestokeep = stock[2]["date"][dateidx]
        catch
            print("ERROR: Unable to get datestokeep")
        end
        Y = stock[2]["adjret"][lagidx]
        if idionews
            if βAsym
                X = Dict("Pos" => stock[2]["Pos"][dateidx],
                         "Neg" => stock[2]["Neg"][dateidx],
                         "sentClasRel" => stock[2]["sentClasRel"][dateidx])
            else
                X = stock[2]["sentClasRel"][dateidx]
            end
        else
            try
                if βAsym
                    X = Dict("Pos" => Series["MktPos"][marketMatchinDates[dateidx]],
                             "Neg" => Series["MktNeg"][marketMatchinDates[dateidx]],
                             "sentClasRel" => Series["Mktsent"][marketMatchinDates[dateidx]])
                else
                    X = Series["Mktsent"][marketMatchinDates[dateidx]]
                end
            catch
                print("ERROR: Unable to get right dates idx for sentiment")
            end
        end
        MS = Series["Mktsent"][marketMatchinDates[dateidx]]
        MR = Series["Mktret"][marketMatchinDates[dateidx]]
        HML = Series["hml"][marketMatchinDates[dateidx]]
        SMB = Series["smb"][marketMatchinDates[dateidx]]
        UMD = Series["umd"][marketMatchinDates[dateidx]]
        coeffs, regsummary = Rregressions(X, Y, MR, MS, HML, SMB, UMD, controlmarketret, controlmarketsent, FFcontrol, βAsym)
        if phase == "classification"
            regResults = storeRegResults(regResults, coeffs, regsummary, crtPeriodFormation)
        elseif length(phase) == 2
            push!(regResults["α"][phase[1]], coeffs["α_coeff"])
            push!(regResults["α_tstat"][phase[1]], coeffs["α_tstat"])
            push!(regResults["β"][phase[1]], coeffs["β$(phase[2])_coeff"])
            push!(regResults["ϵ²"][phase[1]], regsummary["ϵ²"])
            push!(regResults["resError"][phase[1]], regsummary["residualStdError"])
            push!(regResults["β_tstat"][phase[1]], coeffs["β$(phase[2])_tstat"])
        elseif phase == "ranking"
            class = classify(coeffs, classvar, percclass, crtPeriodFormation)
            try
                push!(classification[crtPeriodFormation][class], stock[1])
            catch
                classification[crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
                push!(classification[crtPeriodFormation][class], stock[1])
            end
            regResults = fillResults(regResults, crtPeriodFormation, class, coeffs, regsummary)
        end #if phase
    end #if enough observation
    if phase == "classification"
        return cc, regResults
    elseif length(phase) == 2
        return regResults
    elseif phase == "ranking"
        return cc, classification, regResults
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

function classify(coeffs, classvar, percclass, crtPeriodFormation)
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
    return class
end

function fillResults(regResults, crtPeriodFormation, class, coeffs, regsummary)
    try
        push!(regResults["α"][crtPeriodFormation][class], coeffs["α_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation][class], coeffs["α_tstat"])
        push!(regResults["β"][crtPeriodFormation][class], coeffs["β_coeff"])
        push!(regResults["β_tstat"][crtPeriodFormation][class], coeffs["β_tstat"])
        push!(regResults["βPos"][crtPeriodFormation][class], coeffs["βPos_coeff"])
        push!(regResults["βPos_tstat"][crtPeriodFormation][class], coeffs["βPos_tstat"])
        push!(regResults["βNeg"][crtPeriodFormation][class], coeffs["βNeg_coeff"])
        push!(regResults["βNeg_tstat"][crtPeriodFormation][class], coeffs["βNeg_tstat"])
        push!(regResults["ϵ²"][crtPeriodFormation][class], regsummary["ϵ²"])
        push!(regResults["resError"][crtPeriodFormation][class], regsummary["residualStdError"])
    catch
        regResults["α"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["α_tstat"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["β"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["β_tstat"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["βPos"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["βPos_tstat"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["βNeg"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["βNeg_tstat"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["ϵ²"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        regResults["resError"][crtPeriodFormation] = Dict(1=>[], 2=>[], 3=>[], 4=>[], 5=>[], 0=>[])
        push!(regResults["α"][crtPeriodFormation][class], coeffs["α_coeff"])
        push!(regResults["α_tstat"][crtPeriodFormation][class], coeffs["α_tstat"])
        push!(regResults["β"][crtPeriodFormation][class], coeffs["β_coeff"])
        push!(regResults["β_tstat"][crtPeriodFormation][class], coeffs["β_tstat"])
        push!(regResults["βPos"][crtPeriodFormation][class], coeffs["βPos_coeff"])
        push!(regResults["βPos_tstat"][crtPeriodFormation][class], coeffs["βPos_tstat"])
        push!(regResults["βNeg"][crtPeriodFormation][class], coeffs["βNeg_coeff"])
        push!(regResults["βNeg_tstat"][crtPeriodFormation][class], coeffs["βNeg_tstat"])
        push!(regResults["ϵ²"][crtPeriodFormation][class], regsummary["ϵ²"])
        push!(regResults["resError"][crtPeriodFormation][class], regsummary["residualStdError"])
    end
    return regResults
end


function meanresults(crtquint, classification, MERGEconnect, nextperlag, prevperlag, Series)
    ret, VWret, wport, BMclass, Sizeclass, StoriesCount, SentClasRel = quintileret(crtquint, classification, MERGEconnect, nextperlag, prevperlag)

    @rput VWret
    MR = Series["Mktret"]
    HML = Series["hml"]
    SMB = Series["smb"]
    UMD = Series["umd"]
    @rput UMD
    @rput HML
    @rput MR
    @rput SMB

    a = Float64[]
    ttests = []
    for row in ret
        push!(a, mean(row))
    end
    push!(ttests, a)
    m = (mean(a)+1)^252-1
    sd = std(a)*(252^0.5)
    mVW = (mean(VWret)+1)^252-1
    push!(ttests, VWret)
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
    sentSeries = Float64[]
    for row in SentClasRel
        push!(sentSeries, NaNMath.mean(row))
    end
    push!(ttests, sentSeries)
    Sent =  NaNMath.mean(sentSeries)
    @rput sentSeries

    print("$VWret \n $MR")
    R"fit <- lm(VWret ~ MR + SMB + HML + UMD)"
    R"alpha_4F_ptf_wholeperiod = summary(fit)[['coefficients']]['(Intercept)',1]"
    R"fit <- lm(VWret ~ MR + SMB + HML)"
    R"alpha_3F_ptf_wholeperiod = summary(fit)[['coefficients']]['(Intercept)',1]"
    R"fit <- lm(VWret ~ MR)"
    R"alpha_1F_ptf_wholeperiod = summary(fit)[['coefficients']]['(Intercept)',1]"
    R"fit <- lm(VWret ~ MR + sentSeries)"
    R"betaSentiment_ptf_expost = summary(fit)[['coefficients']]['sentSeries',1]"

    @rget alpha_4F_ptf_wholeperiod
    @rget alpha_3F_ptf_wholeperiod
    @rget alpha_1F_ptf_wholeperiod
    @rget betaSentiment_ptf_expost
    # push!(ttests, regRes["α"][crtquint])
    # malpha = mean(regRes["α"][crtquint])
    # push!(ttests, regRes["β"][crtquint])
    # mbeta = mean(regRes["β"][crtquint])
    # push!(ttests, regRes["ϵ²"][crtquint])
    # mepsilon = mean(regRes["ϵ²"][crtquint])
    # push!(ttests, regRes["resError"][crtquint])
    # mreserror = mean(regRes["resError"][crtquint])
    # push!(ttests, regRes["β_tstat"][crtquint])
    # mbetatstat = mean(regRes["β_tstat"][crtquint])
    return m, sd, mVW, sdVW, w, BM, Size, Count, Sent, alpha_4F_ptf_wholeperiod, alpha_3F_ptf_wholeperiod, alpha_1F_ptf_wholeperiod, betaSentiment_ptf_expost, ttests#, mbeta, mepsilon, mreserror, mbetatsta, malpha
end

function quintileret(quint, classification, MERGEconnect, nextperlag, prevperlag)
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
                push!(dateSentClasRel, NaNMath.mean(SentClasRel))
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




end #module
