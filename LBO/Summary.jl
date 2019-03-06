using MongoDF, Dates, DataFrames, PyCall, Plots, Statistics, StatsBase

A_Vars = ["Competitors", "Industry", "nbReviews", "OrigName", "Size", "State", "TransVal"]
B_Vars = ["Description", "Founded", "Headquarters", "Ownership_Type", "Revenue"]
retvalues = ["Company", "Closed", "Announced", A_Vars...]
Companies = @time glassdoorMongoDF(retvalues, "Companies_1")

scoreVars = ["Score", "CB", "CO", "Cult", "SM", "WLB", "outlook", "recommended", "CEO"]
textVars = ["Pros", "Cons", "Summary", "Position", "Main", "MgtAdv"]
miscVars = ["Poprank", "LBO"]
retvalues = ["Company", "Date", scoreVars..., miscVars...]
Reviews = @time glassdoorMongoDF(retvalues, "Glassdoors_1")

X = join(Reviews, Companies, on=:Company, kind=:left)


### Cumulative distribution of number of reviews per firms ###
plot(cumsum(sort(Companies[:nbReviews])), label="")
#Add vertical line when contribution in nb of reviews surpasses 10, 20, 50 and 100
vline!([497, 613, 757, 868], label="")


### Distribution of firm Size ###


### Geographic distribution of firms ###
