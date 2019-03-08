using MongoDF, Dates, DataFrames, PyCall, Plots, Statistics, StatsBase, DataStructures, CSV

A_Vars = ["CompetitorsGlassdoor", "Industry", "nbReviews", "OrigName", "Size", "State", "TransVal", "CompetitorsCiq", "SectorCiq"]
B_Vars = ["Description", "Founded", "Headquarters", "Ownership_Type", "Revenue"]
retvalues = ["Company", "Closed", "Announced", A_Vars...]
Companies = @time glassdoorMongoDF(retvalues, "Companies_3")
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Companies_raw.csv", Companies)

scoreVars = ["Score", "CB", "CO", "Cult", "SM", "WLB", "outlook", "recommended", "CEO"]
textVars = ["Pros", "Cons", "Summary", "Position", "Main", "MgtAdv"]
miscVars = ["Poprank", "LBO"]
retvalues = ["Company", "Date", scoreVars..., miscVars..., textVars...]
Reviews = @time glassdoorMongoDF(retvalues, "Glassdoors_3")
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Reviews_raw.csv", Reviews)

X = join(Reviews, Companies, on=:Company, kind=:left)
X[:CEO] = replace(X[:CEO], "No opinion of"=>0, "Disapproves of"=>-1, "Approves of"=>1)

### Cumulative distribution of number of reviews per firms ###
plotlyjs()
plot(cumsum(sort(Companies[:nbReviews])), label="", xlabel = "Cumulated # of firms", xticks = 0:500:4500,
        ylabel="Cumulated # of reviews", title = "Contribution to total number of reviews by firm")
#Add vertical line when contribution in nb of reviews surpasses 10, 20, 50 and 100
vline!([2806, 3337, 3885, 4205], label="")
4612-2806

### Distribution of firm Size ###
orderedSizeLabels = ["10000+ employees", "5001 to 10000 employees", "1001 to 5000 employees",
    "501 to 1000 employees", "201 to 500 employees", "51 to 200 employees", "1 to 50 employees", "Unknown"]
sizeDistrib = DataFrame(countmap(Companies[:Size]))
sizeDistrib = sizeDistrib[Symbol.(orderedSizeLabels)] #Re-order from biggest to smallest

means, medians, total = [[] for i in 1:3]
for i in 1:8
    crtSize = orderedSizeLabels[i]
    crtSizeComps = Companies[(.!ismissing.(Companies[:Size])) .& (Companies[:Size].==crtSize), :nbReviews]
    push!(means, mean(crtSizeComps))
    push!(medians, median(crtSizeComps))
    push!(total, length(crtSizeComps))
end
szDist = DataFrame(OrderedDict("Size"=>orderedSizeLabels, "# of firms"=>total, "mean_NB_reviews"=>means, "med_NB_reviews"=>medians))
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/sizeDistrib.csv", szDist)

# X[array_in_broadcast(X[:Company], crtSizeComps), :]
#
# function array_in_broadcast(X, Y)
#     res = Bool[]
#     for x in X
#         if x in Y
#             push!(res, 1)
#         else
#             push!(res, 0)
#         end
#     end
#     return res
# end

### Geographic distribution of firms ###
countries = collect(Set(Companies[:State]))
nb_firms, totrevs, meanrevs, medrevs, maxrevs, meansize, mediansize = [[] for i in 1:7]
function sizeLabels_to_intrank(szLabels, rawRanks)
    # Assume szLabels is properly ordered!!
    szDict = Dict()
    for i in collect(1:length(szLabels))[end:-1:1]
        szDict[szLabels[i]] = i
    end
    res = []
    for i in rawRanks
        push!(res, szDict[i])
    end
    return res
end
for cou in countries
    coudf = Companies[(.!ismissing.(Companies[:State])) .& (Companies[:State].==cou), :]
    push!(nb_firms, size(coudf, 1))
    push!(totrevs, sum(coudf[:nbReviews]))
    push!(meanrevs, mean(coudf[:nbReviews]))
    push!(medrevs, median(coudf[:nbReviews]))
    push!(maxrevs, maximum(coudf[:nbReviews]))
    szRank = sizeLabels_to_intrank(orderedSizeLabels, coudf[:Size])
    push!(meansize, mean(szRank))
    push!(mediansize, median(szRank))
end
Geo = DataFrame(OrderedDict("Country"=>countries, "# of firms"=>nb_firms, "total # reviews"=>totrevs,
                            "mean_NB_reviews"=>meanrevs, "median_NB_reviews"=>medrevs, "max_NB_reviews"=>maxrevs,
                            "mean_size_rank"=>meansize, "median_size_rank"=>mediansize))
sort!(Geo, Symbol("# of firms"), rev=true)
szRank = sizeLabels_to_intrank(orderedSizeLabels, Companies[:Size])
insert!.(eachcol(Geo, false), 1,["World", size(Companies, 1), sum(Companies[:nbReviews]), mean(Companies[:nbReviews]),
            median(Companies[:nbReviews]), maximum(Companies[:nbReviews]), mean(szRank), median(szRank)])
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/GeoDistrib.csv", Geo)


### Score before and after LBO ###
# "Score", "CB", "CO", "Cult", "SM", "WLB", "outlook", "recommended", "CEO"
scoreVar = :recommended
avg(x) = length(collect(skipmissing(x)))>0 ? mean(skipmissing(x)) : missing
med(x) = length(collect(skipmissing(x)))>0 ? median(skipmissing(x)) : missing
sdev(x) = std(skipmissing(x))
tot(x) = sum(skipmissing(x))
len(x) = length(collect(skipmissing(x)))
mylength(x) = !ismissing(x) ? length(x) : missing
companies = collect(Set(X[:Company]))
ind, sz, count, comps  = [[] for i in 1:4]
medScore0, meanScore0, stdScore0 = [[] for i in 1:3]
medScore10, meanScore10, stdScore10 = [[] for i in 1:3]
medScore50, meanScore50, stdScore50 = [[] for i in 1:3]
medScore100, meanScore100, stdScore100 = [[] for i in 1:3]
medScorePre0, medScorePost0, meanScorePre0, meanScorePost0, stdScorePre0, stdScorePost0 = [[] for i in 1:6]
medScorePre10, medScorePost10, meanScorePre10, meanScorePost10, stdScorePre10, stdScorePost10 = [[] for i in 1:6]
medScorePre20, medScorePost20, meanScorePre20, meanScorePost20, stdScorePre20, stdScorePost20 = [[] for i in 1:6]
has3prepost, has5prepost, has10prepost, has20prepost, has50prepost = [[] for i in 1:5]
pre_length, post_length, mgtAdvLength, mgtAdvLength_pre, mgtAdvLength_post = [[] for i in 1:5]
mgtAdvLength_pre10, mgtAdvLength_post10, mgtAdvLength_pre20, mgtAdvLength_post20 = [[] for i in 1:4]
function push_scoreStats!(score, thresh, X, Y, Z)
    if length(score)>thresh
        push!(X, median(score))
        push!(Y, mean(score))
        if isnan(std(score))
            push!(Z, missing)
        else
            push!(Z, std(score))
        end
    else
        push!(X, missing)
        push!(Y, missing)
        push!(Z, missing)
    end
end
for comp in companies
    crtComp = X[X[:Company].==comp, :]
    push!(ind, crtComp[:Industry][1])
    push!(comps, crtComp[:Company][1])
    push!(sz, crtComp[:Size][1])
    push!(count, crtComp[:State][1])
    push!(mgtAdvLength, med(mylength.(crtComp[:MgtAdv])))
    score = collect(skipmissing(crtComp[scoreVar]))
    push_scoreStats!(score, 0, medScore0, meanScore0, stdScore0)
    push_scoreStats!(score, 10, medScore10, meanScore10, stdScore10)
    push_scoreStats!(score, 50, medScore50, meanScore50, stdScore50)
    push_scoreStats!(score, 100, medScore100, meanScore100, stdScore100)
    pre_df = crtComp[crtComp[:Date].<crtComp[:Closed][1], :]
    post_df = crtComp[crtComp[:Date].>=crtComp[:Closed][1], :]
    push!(pre_length, size(pre_df,1))
    push!(post_length, size(post_df,1))
    push!(mgtAdvLength_pre, med(mylength.(pre_df[:MgtAdv])))
    push!(mgtAdvLength_post, med(mylength.(post_df[:MgtAdv])))
    preScore = collect(skipmissing(pre_df[scoreVar]))
    postScore = collect(skipmissing(post_df[scoreVar]))
    push_scoreStats!(preScore, 0, medScorePre0, meanScorePre0, stdScorePre0)
    push_scoreStats!(postScore, 0, medScorePost0, meanScorePost0, stdScorePost0)
    push_scoreStats!(preScore, 10, medScorePre10, meanScorePre10, stdScorePre10)
    push_scoreStats!(postScore, 10, medScorePost10, meanScorePost10, stdScorePost10)
    push_scoreStats!(preScore, 20, medScorePre20, meanScorePre20, stdScorePre20)
    push_scoreStats!(postScore, 20, medScorePost20, meanScorePost20, stdScorePost20)
    if length(preScore)>=3 && length(postScore)>=3
        push!(has3prepost, 1)
    else
        push!(has3prepost, 0)
    end
    if length(preScore)>=5 && length(postScore)>=5
        push!(has5prepost, 1)
    else
        push!(has5prepost, 0)
    end
    if length(preScore)>=10 && length(postScore)>=10
        push!(has10prepost, 1)
    else
        push!(has10prepost, 0)
    end
    if length(preScore)>=20 && length(postScore)>=20
        push!(has20prepost, 1)
    else
        push!(has20prepost, 0)
    end
    if length(preScore)>=50 && length(postScore)>=50
        push!(has50prepost, 1)
    else
        push!(has50prepost, 0)
    end
end

LBOdf = DataFrame(OrderedDict("Company"=>comps, "Industry"=>ind, "Size"=>sz, "Country"=>count,
        "med$(scoreVar)_0"=>medScore0, "mean$(scoreVar)_0"=>meanScore0, "std$(scoreVar)_0"=>stdScore0,
        "med$(scoreVar)_10"=>medScore10, "mean$(scoreVar)_10"=>meanScore10, "std$(scoreVar)_10"=>stdScore10,
        "med$(scoreVar)_50"=>medScore50, "mean$(scoreVar)_50"=>meanScore50, "std$(scoreVar)_50"=>stdScore50,
        "med$(scoreVar)_100"=>medScore100, "mean$(scoreVar)_100"=>meanScore100, "std$(scoreVar)_100"=>stdScore100,
        "med$(scoreVar)_0_pre_LBO"=>medScorePre0, "mean$(scoreVar)_0_pre_LBO"=>meanScorePre0, "std$(scoreVar)_0_pre_LBO"=>stdScorePre0,
        "med$(scoreVar)_10_pre_LBO"=>medScorePre10, "mean$(scoreVar)_10_pre_LBO"=>meanScorePre10, "std$(scoreVar)_10_pre_LBO"=>stdScorePre10,
        "med$(scoreVar)_20_pre_LBO"=>medScorePre20, "mean$(scoreVar)_20_pre_LBO"=>meanScorePre20, "std$(scoreVar)_20_pre_LBO"=>stdScorePre20,
        "med$(scoreVar)_0_post_LBO"=>medScorePost0, "mean$(scoreVar)_0_post_LBO"=>meanScorePost0, "std$(scoreVar)_0_post_LBO"=>stdScorePost0,
        "med$(scoreVar)_10_post_LBO"=>medScorePost10, "mean$(scoreVar)_10_post_LBO"=>meanScorePost10, "std$(scoreVar)_10_post_LBO"=>stdScorePost10,
        "med$(scoreVar)_20_post_LBO"=>medScorePost20, "mean$(scoreVar)_20_post_LBO"=>meanScorePost20, "std$(scoreVar)_20_post_LBO"=>stdScorePost20,
        "NB_revs_pre_LBO"=>pre_length, "NB_revs_post_LBO"=>post_length, "MgtAdvLength"=>mgtAdvLength, "MgtAdvLength_pre"=>mgtAdvLength_pre, "MgtAdvLength_post"=>mgtAdvLength_post,
        "$(scoreVar)has3pre_post"=>has3prepost, "$(scoreVar)has5pre_post"=>has5prepost, "$(scoreVar)has10pre_post"=>has10prepost, "$(scoreVar)has20pre_post"=>has20prepost, "$(scoreVar)has50pre_post"=>has50prepost))
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/rawStats_$(scoreVar).csv", LBOdf)

## Group by country ##
geoGroup = by(LBOdf, :Country, Symbol("mean$(scoreVar)_0") => avg, Symbol("mean$(scoreVar)_50") => avg,
                :NB_revs_pre_LBO => avg, :NB_revs_post_LBO => avg,
                Symbol("mean$(scoreVar)_10_pre_LBO") => avg, Symbol("mean$(scoreVar)_10_post_LBO") => avg, :NB_revs_post_LBO => tot)
provDF = LBOdf[[Symbol("mean$(scoreVar)_0"), Symbol("mean$(scoreVar)_50"), :NB_revs_pre_LBO, :NB_revs_post_LBO,
                Symbol("mean$(scoreVar)_10_pre_LBO"), Symbol("mean$(scoreVar)_10_post_LBO")]]
push!(geoGroup, [["World"];[avg(provDF[x]) for x in names(provDF)];[tot(LBOdf[:NB_revs_post_LBO])]])
sort!(geoGroup, :NB_revs_post_LBO_tot, rev=true)
deletecols!(geoGroup, :NB_revs_post_LBO_tot)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/GeoGroupStats_$(scoreVar).csv", geoGroup)


## Group by industry ##
indGroup = by(LBOdf, :Industry, Symbol("mean$(scoreVar)_0") => avg, Symbol("mean$(scoreVar)_50") => avg,
                :NB_revs_pre_LBO => avg, :NB_revs_post_LBO => avg,
                Symbol("mean$(scoreVar)_10_pre_LBO") => avg, Symbol("mean$(scoreVar)_10_post_LBO") => avg, :NB_revs_post_LBO => tot)
provDF = LBOdf[[Symbol("mean$(scoreVar)_0"), Symbol("mean$(scoreVar)_50"), :NB_revs_pre_LBO, :NB_revs_post_LBO,
                Symbol("mean$(scoreVar)_10_pre_LBO"), Symbol("mean$(scoreVar)_10_post_LBO")]]
push!(indGroup, [["Market"];[avg(provDF[x]) for x in names(provDF)];[tot(LBOdf[:NB_revs_post_LBO])]])
sort!(indGroup, :NB_revs_post_LBO_tot, rev=true)
deletecols!(indGroup, :NB_revs_post_LBO_tot)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/IndGroupStats_$(scoreVar).csv", indGroup)

## Mean by size ##
szGroup = by(LBOdf, :Size, Symbol("mean$(scoreVar)_0") => avg, Symbol("mean$(scoreVar)_50") => avg,
                :NB_revs_pre_LBO => avg, :NB_revs_post_LBO => avg,
                Symbol("mean$(scoreVar)_10_pre_LBO") => avg, Symbol("mean$(scoreVar)_10_post_LBO") => avg, :NB_revs_post_LBO => tot)
provDF = LBOdf[[Symbol("mean$(scoreVar)_0"), Symbol("mean$(scoreVar)_50"), :NB_revs_pre_LBO, :NB_revs_post_LBO,
                Symbol("mean$(scoreVar)_10_pre_LBO"), Symbol("mean$(scoreVar)_10_post_LBO")]]
push!(szGroup, [["All"];[avg(provDF[x]) for x in names(provDF)];[tot(LBOdf[:NB_revs_post_LBO])]])
sort!(szGroup, :NB_revs_post_LBO_tot, rev=true)
deletecols!(szGroup, :NB_revs_post_LBO_tot)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/SzGroupStats_$(scoreVar).csv", szGroup)


# Interesting
median(LBOdf[:NB_revs_post_LBO])
avg(LBOdf[:MgtAdvLength_post])
avg(LBOdf[:MgtAdvLength_pre])
avg(LBOdf[:MgtAdvLength])

prepostScore = OrderedDict()
prepostScore[" "] = ["med_$(scoreVar)_pre_LBO", "med_$(scoreVar)_post_LBO",
                       "mean$(scoreVar)_pre_LBO", "mean$(scoreVar)_post_LBO",
                       "std$(scoreVar)_pre_LBO", "std$(scoreVar)_post_LBO",
                       "# of firms pre", "# of firms post", "# firms w pre AND post"]
for i in [0,10,20]
    prov = []
    push!(prov, avg(LBOdf[Symbol("med$(scoreVar)_$(i)_pre_LBO")]))
    push!(prov, avg(LBOdf[Symbol("med$(scoreVar)_$(i)_post_LBO")]))
    push!(prov, avg(LBOdf[Symbol("mean$(scoreVar)_$(i)_pre_LBO")]))
    push!(prov, avg(LBOdf[Symbol("mean$(scoreVar)_$(i)_post_LBO")]))
    push!(prov, avg(LBOdf[Symbol("std$(scoreVar)_$(i)_pre_LBO")]))
    push!(prov, avg(LBOdf[Symbol("std$(scoreVar)_$(i)_post_LBO")]))
    # Report number of reviews pre/post announcement
    push!(prov, sum(LBOdf[:NB_revs_pre_LBO].>=i))
    push!(prov, sum(LBOdf[:NB_revs_post_LBO].>=i))
    if i>0
        push!(prov, sum(LBOdf[Symbol("$(scoreVar)has$(i)pre_post")]))
    else
        push!(prov, length(LBOdf[:NB_revs_pre_LBO]))
    end
    prepostScore["min_$(i)_reviews"] = prov
end
PrePost = DataFrame(prepostScore)
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/PrePostStats_$(scoreVar).csv", PrePost)


### Competitors yes/no ###
function nbCompetitors(Companies)
    anyComp, CiqComp, GDcomp = [[] for i in 1:3]
    L = size(Companies,1)
    for i in 1:L
        if (length(Companies[i, :CompetitorsCiq])>2) || (!ismissing(Companies[i, :CompetitorsGlassdoor]) && length(Companies[i, :CompetitorsGlassdoor])>3 && Companies[i, :CompetitorsGlassdoor]!=" Unknown")
            push!(anyComp,1)
        end
        if !ismissing(Companies[i, :CompetitorsGlassdoor]) && length(Companies[i, :CompetitorsGlassdoor])>3 && Companies[i, :CompetitorsGlassdoor]!=" Unknown"
            push!(GDcomp,1)
        end
        if length(Companies[i, :CompetitorsCiq])>4
            push!(CiqComp,1)
        end
    end
    return [L length(anyComp) length(CiqComp) length(GDcomp);
            1 length(anyComp)/L length(CiqComp)/L length(GDcomp)/L]
end
a = nbCompetitors(Companies)
b = nbCompetitors(Companies[Companies[:nbReviews].>=10, :])
c = nbCompetitors(Companies[Companies[:nbReviews].>=20, :])
d = nbCompetitors(Companies[Companies[:nbReviews].>=50, :])
e = nbCompetitors(Companies[Companies[:nbReviews].>=100, :])
f = nbCompetitors(Companies[Companies[:State].=="unitedstates", :])
Competitors = DataFrame(vcat(a,b,c,d,e,f))
names!(Competitors, [Symbol("Total firms"), :w_compet, :w_Ciq_compet, :w_GD_compet])
CSV.write("/home/nicolas/Documents/Paper L Phalippou/Data/Summary/Competitors.csv", Competitors)

### Reviews over time ###
Y = X[X[:Date].>DateTime(2008,1,1),:]
res = []
dates = []
for date in ceil(minimum(Y[:Date]), Month):Month(1):ceil(maximum(Y[:Date]), Month)
    crt = Y[findall((Y[:Date].<date) .& (Y[:Date].>=date-Month(1))), :]
    push!(res, size(crt,1))
    push!(dates, maximum(crt[:Date]))
end
plot(Date.(dates[1:end-1]), res[1:end-1], xticks = Date(2009,1,1):Year(1): Date(2019,1,1),
     rotation=30, title="Total number of reviews per month", yticks = 0:500:4000)
