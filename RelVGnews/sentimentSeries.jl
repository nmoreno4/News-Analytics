args = ["local", "all", "_"]
args = map(x->x, ARGS)
if args[1]=="CECI"
  push!(LOAD_PATH, "/CECI/home/ulg/affe/nmoreno/CodeGood/RelVGnews/myModules")
end
using helperFunctions
rootpath, datarootpath, logpath = loadPaths(args[1])
rootpath = "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/Data Inputs"
datarootpath = "/run/media/nicolas/OtherData/home/home/nicolas/Data"
logpath = "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/log"

using databaseQuerer, TSfunctions, Mongo, JLD2, JLD, FileIO, nanHandling, functionsTRNA, helperFunctions

Specification = defineSpec(args[2], args[3])

decayParam = 1
printcol = 100
excludeDays = Dates.Day(0)
offsetexcludeDays = Dates.Month(0)
tFrequence = Dates.Day(1)
pastRollWindow = Dates.Month(0)
minPeriodInterval = Dates.Day(0)
repetFilter = (true, 2)
storyAVG = true

permNO_to_permID = FileIO.load("$rootpath/permnoToPermId.jld2")["mappingDict"]
retmat = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["mat"][:,:,1]
dates = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["dates"]
keptrows = FileIO.load("$datarootpath/CRSP/$tFrequence/AllStocks.jld2")["keptrows"]
dates = dates[keptrows]

#Each date for which a new data point will be computed

selectedDates = newPeriodsDatesIdx(dates, minPeriodInterval)
#Past added Rolling window


client = MongoClient()
CRSPconnect = MongoCollection(client, "NewsDB", "CRSPmonthly")
newsConnect = MongoCollection(client, "NewsDB", "News")

spec=Specification[1]
#test de shuttlesworth, neway-west, bonferrini - false discoveries (average of multiple regressions in portfolio)
for spec in Specification
    print("\n \n This is a new spec: \n $spec \n\n")
    factor = spec[1]
    quintile = spec[2]
    if quintile == ["H", "M", "L"]
        portfolioIdxs = FileIO.load("$rootpath/CRSP/$tFrequence/AllStocks.jld2")["chosenIdx"]
    else
        portfolioIdxs = FileIO.load("$datarootpath/CRSP/$tFrequence/$(factor)_$(quintile).jld2")["chosenIdx"]
    end
    prolongedDates = unshift!(deepcopy(dates), dates[1]-Dates.Month(1))

    PERMNOs = collect(fieldDistinct(CRSPconnect, ["PERMNO"])[1])
    open("$logpath/$(spec)_$(pastRollWindow).txt", "a") do f
        write(f, "The length of PERMNOs is : $(length(PERMNOs)) \n")
    end
    print("The length of PERMNOs is : $(length(PERMNOs))")

    Result = Array{Any}(size(retmat))

    #past search limit + first date
    selectedProlongedDates = [selectedDates[1][1] - (selectedDates[1][2]-selectedDates[1][1]), selectedDates[1][1]]
    for d in selectedDates
        push!(selectedProlongedDates, d[2])
    end
    datesTrunkResult = Array{Any}(length(dates), size(retmat)[2])

    # I want to know how many news I have on each period for each stock --> matrix
    # I want to know for what amount of stocks I have no matching permId in a date/stock matrix
    #{firstCreated:{$gte:ISODate("2012-06-29T20:00:00")}, "takes.analytics.assetId":4295906878}
    noStoriesFound, StoriesFound, nbStoriesFound, nbAnalyticsFound, idxData = [], [], [], [], []
    tic()
    col = 0
    for chosenRows in portfolioIdxs[1]
        col+=1
        dataCollector = []
        selectedDateRow = 1
        for row in 1:size(retmat, 1)
            if row in chosenRows
                # print(t)
                if get(permNO_to_permID, PERMNOs[col], 0) != 0
                    # print("\n row: $row, col: $col , ")
                    permId = permNO_to_permID[PERMNOs[col]]
                    startdate = DateTime(prolongedDates[row]) + Dates.Hour(20) - pastRollWindow - offsetexcludeDays
                    enddate = DateTime(prolongedDates[row+1]) + Dates.Hour(20) - excludeDays
                    cursor = getAnalyticsCursor(newsConnect, startdate, enddate, permId)
                    Result[row, col] = gatherSentiment(cursor, permId, enddate, startdate, decayParam, Dates.Day)
                    push!(dataCollector, Result[row, col])
                    if length(Result[row, col]) == 0
                        push!(noStoriesFound, (row, col))
                    else
                        # print(Result[row, col])
                        push!(StoriesFound, (row, col))
                    end
                    push!(nbStoriesFound, length(Result[row, col]))
                    takeCount = 0
                    for take in Result[row, col]
                        takeCount+=length(take)
                    end
                    push!(nbAnalyticsFound, [(row,col), takeCount])
                end # if I have a matching permId
            end #if I have a return on this period for this stock
            if selectedDateRow>1 #if not the first date
              if !((row+1) in selectedDates[selectedDateRow-1][3])
                  datesTrunkResult[selectedDateRow, col] = dataCollector
                  if length(dataCollector)>0
                    push!(idxData, [(selectedDateRow, col), StoriesFound, nbAnalyticsFound, nbStoriesFound, noStoriesFound])
                  end
                  dataCollector = []
                  selectedDateRow+=1
                  noStoriesFound, StoriesFound, nbStoriesFound, nbAnalyticsFound = [], [], [], []
              end #if the next row starts a new period
            else #check for first date == true
              if dates[row]==selectedDates[1][1]
                datesTrunkResult[selectedDateRow, col] = dataCollector
                if length(dataCollector)>0
                  push!(idxData, [(selectedDateRow, col), StoriesFound, nbAnalyticsFound, nbStoriesFound, noStoriesFound])
                end
                dataCollector = []
                selectedDateRow+=1
                noStoriesFound, StoriesFound, nbStoriesFound, nbAnalyticsFound = [], [], [], []
              end #if the next row starts a new period
            end
        end #for row
        if col%printcol == 0
            toc()
            print("Advancement : $(round(100*col/size(retmat, 2),2))% ; ")
            open("$logpath/$(spec)_$(pastRollWindow).txt", "a") do f
                write(f, "Advancement : $(round(100*col/size(retmat, 2),2))% ; \n")
            end
            tic()
        end
    end #for col
    toc()

    sentClasMat = computeAnalytics(datesTrunkResult, 7, 1, storyAVG, repetFilter[1], repetFilter[2])
    sentClasMatRel = computeAnalytics(datesTrunkResult, [7,4], 4, storyAVG, repetFilter[1], repetFilter[2])
    diffPosNeg = computeAnalytics(datesTrunkResult, [1,2], 2, storyAVG, repetFilter[1], repetFilter[2])
    diffPosNegRel = computeAnalytics(datesTrunkResult, [1,2,4], 3, storyAVG, repetFilter[1], repetFilter[2])
    noveltyMat = computeAnalytics(datesTrunkResult, [5,6], 5, storyAVG, repetFilter[1], 5)
    # volumeMat = computeAnalytics(datesTrunkResult, 6, 1, storyAVG, repetFilter[1], repetFilter[2])
    decayMat = computeAnalytics(datesTrunkResult, 10, 6, storyAVG)
    storiesCountMat = computeAnalytics(datesTrunkResult, 10, 7, storyAVG)
	posMat = computeAnalytics(datesTrunkResult, 1, 1, storyAVG, repetFilter[1], repetFilter[2])
	negMat = computeAnalytics(datesTrunkResult, 2, 1, storyAVG, repetFilter[1], repetFilter[2])
	neutMat = computeAnalytics(datesTrunkResult, 3, 1, storyAVG, repetFilter[1], repetFilter[2])

    open("$logpath/$(spec)_$(pastRollWindow).txt", "a") do f
        write(f, "Size: $(size(sentClasMat)), nonnan: $(nonnancount(sentClasMat)) \n")
    end

    mkpath("$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)")

    if quintile == ["H", "M", "L"]
        JLD2.@save "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/AllStocks.jld2" idxData sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat posMat negMat neutMat #volumeMat
        # JLD.save(File(format"JLD","$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/AllStocks"), "idxData", idxData, "sentClasMat", sentClasMat, "sentClasMatRel", sentClasMatRel, "diffPosNeg", diffPosNeg, "diffPosNegRel", diffPosNegRel, "noveltyMat", noveltyMat, "volumeMat", volumeMat, "decayMat", decayMat, "storiesCountMat", storiesCountMat)
    else
        JLD2.@save "$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(repetFilter)_$(storyAVG)/$(factor)_$(quintile).jld2" idxData sentClasMat sentClasMatRel diffPosNeg diffPosNegRel noveltyMat decayMat storiesCountMat posMat negMat neutMat #volumeMat
        # JLD.save(File(format"JLD","$datarootpath/TRNA/$tFrequence/$excludeDays/$pastRollWindow/$decayParam/$(factor)_$(quintile).jld"), "idxData", idxData, "sentClasMat", sentClasMat, "sentClasMatRel", sentClasMatRel, "diffPosNeg", diffPosNeg, "diffPosNegRel", diffPosNegRel, "noveltyMat", noveltyMat, "volumeMat", volumeMat, "decayMat", decayMat, "storiesCountMat", storiesCountMat)
    end

    open("$logpath/$(spec)_$(pastRollWindow).txt", "a") do f
        write(f, "Advancement : 100% ; \n")
    end

end #for spec

# using Plots
# plotlyjs()
# Plots.plot([totalAnalyticsPeriod])
#
# Plots.histogram(filter(x -> x < 40, nbStoriesFound),
#             title="hey",
#             legend=:none,
#             titlefont=Plots.font(9),
#             bins=40)
#
# a = []
# for row in 1:size(sentClasMat,1)
#     push!(a, nanmean(sentClasMat[row,:]))
# end
