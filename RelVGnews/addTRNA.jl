#######################################################################################
# Insert TRNA raw data (in JSON format) inside a well structured MongoDB
# collection with approriate nesting for easy querying and limited
# data redundancy.
# I can't read the whole JSON files into memory but have to stream them.
# NB: Notice that there are currently problems for the 2016 and 2017 files (see bottom)
#######################################################################################

###############################################
#%% Import libraries and define user variables
using Mongo
using LibBSON
using JSON

# Define Mongo instance
client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
News = MongoCollection(client, "NewsDB", "News")
# Beginning and starting dates
y_start = 2003
y_end = 2017
# Path to the raw data. The @ will be replaced below with the approriate year to retrieve the correct file. Check the 40060088 in case it has changed from the source.
datapath = "/home/nicolas/Reuters/TRNA/Archives/TR_News/CMPNY_AMER/EN/JSON/Historical/TRNA.TR.News.CMPNY_AMER.EN.@.40060088.JSON.txt/data"


"""
TRNA_as_dictionary = json_to_dic(TRNA_as_JSON::BSONobject)
==========================================================
## Transform the raw nested JSON format of a single Analytic as provided by Reuters into its Julia dictionary equivalent.
**Notice** : _item_ is a BSON object (single line) that contains **ONE SINGLE** analytic (i.e. one company) of one single take.
### Returns:
  * story(Dict) : The whole piece of information (i.e. take, but from scratch including altId etc.) in julia Dict format.
"""
function json_to_dic(item)
  altId = item["newsItem"]["metadata"]["altId"]
  firstCreated = Dates.DateTime(item["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  guId = item["newsItem"]["sourceId"]
  uId = item["id"]
  assetId =  item["analytics"]["analyticsScores"][1]["assetId"]
  firstMentionSentence =  item["analytics"]["analyticsScores"][1]["firstMentionSentence"]
  ticker =  split(split(item["analytics"]["analyticsScores"][1]["assetCodes"][2], ":")[2], ".")[1]
  assetName =  lowercase(item["analytics"]["analyticsScores"][1]["assetName"])
  linkedIds =  item["analytics"]["analyticsScores"][1]["linkedIds"]
  noveltyCounts =  item["analytics"]["analyticsScores"][1]["noveltyCounts"]
  relevance =  item["analytics"]["analyticsScores"][1]["relevance"]
  sentimentClass =  item["analytics"]["analyticsScores"][1]["sentimentClass"]
  sentimentNegative =  item["analytics"]["analyticsScores"][1]["sentimentNegative"]
  sentimentNeutral =  item["analytics"]["analyticsScores"][1]["sentimentNeutral"]
  sentimentPositive =  item["analytics"]["analyticsScores"][1]["sentimentPositive"]
  sentimentWordCount =  item["analytics"]["analyticsScores"][1]["sentimentWordCount"]
  volumeCounts =  item["analytics"]["analyticsScores"][1]["volumeCounts"]
  bodySize =  item["analytics"]["newsItem"]["bodySize"]
  companyCount =  item["analytics"]["newsItem"]["companyCount"]
  exchangeAction =  item["analytics"]["newsItem"]["exchangeAction"]
  headlineTag =  item["analytics"]["newsItem"]["headlineTag"]
  marketCommentary =  item["analytics"]["newsItem"]["marketCommentary"]
  sentenceCount =  item["analytics"]["newsItem"]["sentenceCount"]
  wordCount =  item["analytics"]["newsItem"]["wordCount"]
  headline = item["newsItem"]["headline"]
  language = item["newsItem"]["language"]
  urgency = item["newsItem"]["urgency"]
  subjects = item["newsItem"]["subjects"]
  provider = item["newsItem"]["provider"]
  sourceTimestamp = Dates.DateTime(item["newsItem"]["sourceTimestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  audiences = item["newsItem"]["metadata"]["audiences"]
  feedTimestamp = Dates.DateTime(item["newsItem"]["metadata"]["feedTimestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  takeSequence = item["newsItem"]["metadata"]["takeSequence"]

  story = Dict("altId" => altId,
                  "firstCreated" => firstCreated,
                  "takes" => [
                    Dict(
                      "audiences" => audiences,
                      "bodySize" => bodySize,
                      "companyCount" => companyCount,
                      "exchangeAction" => exchangeAction,
                      "feedTimestamp" => feedTimestamp,
                      "guId" => guId,
                      "uId" => uId,
                      "headline" => headline,
                      "headlineTag" => headlineTag,
                      "language" => language,
                      "marketCommentary" => marketCommentary,
                      "provider" => provider,
                      "sentenceCount" => sentenceCount,
                      "sourceTimestamp" => sourceTimestamp,
                      "subjects" => subjects,
                      "takeSequence" => takeSequence,
                      "urgency" => urgency,
                      "wordCount" => wordCount,
                      "analytics" => [
                        Dict(
                          "assetId" => assetId,
                          "assetName" => assetName,
                          "firstMentionSentence" => firstMentionSentence,
                          "relevance" => relevance,
                          "sentimentClass" => sentimentClass,
                          "sentimentNegative" => sentimentNegative,
                          "sentimentNeutral" => sentimentNeutral,
                          "sentimentPositive" => sentimentPositive,
                          "sentimentWordCount" => sentimentWordCount,
                          "ticker" => ticker,
                          "linkedIds" => linkedIds,
                          "noveltyCounts" => noveltyCounts,
                          "volumeCounts" => volumeCounts
                        ) # Close this analytics Dict
                      ] # Close analytics array for eventual multiple companies
                    ) # Close this takes Dict
                  ]) # Close takes array for eventual multiple takes as well as global story Dict
  return story
end

"""
updatePos, guIdexists, ntakes = nbTakes(TRNA_as_JSON::BSONobject)
=================================================================
## Finds out how many takes were already added to the MongoDB for a story (defined by its altId and timestamp).
## If the current take already exists returns guIdexists=true, indicating that only a new analytic needs to be added to the take.

### Returns:
  * updatePos(Int) : the index in the array of takes which is concerned, useful to know where to append if only analytics need to be added. It returns 0 if it is the first take of the story to be added.
  * guIdexists(bool) : true if only analytics need to be added. False if it is a new take.
  * ntakes(Int) : Number of takes already added to the story in the MongoDB collection.
"""
function nbTakes(entry)
  # Gather guId, altId and timestamp in variables for ease of use
  crtdate = Dates.DateTime(entry["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  crtaltId = entry["newsItem"]["metadata"]["altId"]
  crtguId = entry["newsItem"]["sourceId"]
  # Find cursor on MongoDB to the right story (only one in fact)
  cursor = find(News, Dict("altId"=>crtaltId, "firstCreated"=>crtdate))
  # Initialize variables
  updatePos, guIdexists, ntakes = 0, false, 0
  # Go through all found stories (here only one, but the loop is mandatory)
  for i in cursor
    # Go through all existing added takes of the story
    if length(i["takes"])>0
      for j in i["takes"]
        ntakes+=1
        if j["guId"]==crtguId
          guIdexists=true
          updatePos = ntakes
        end # if guId
      end #for takes
    end # ntakes>0
  end #for cursor
  return (updatePos, guIdexists, ntakes)
end #fun

"""
addOnlyAnalytics(entry::BSONobject, updatePos::Int)
============================
## Adds only the analytics part of the take (i.e. the entry) to an already existing take in the MongoDb collection.

### Inputs:
  * entry(BSONobject) : A parsed JSON line of a take (which is a "complete story" for a single companie's analytics)
  * updatePos(Int) : The position of the take in the array of takes where the analytic will be added
"""
function addOnlyAnalytics(entry, updatePos)
  # Gather guId, altId and timestamp in variables for ease of use
  crtdate = Dates.DateTime(entry["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  crtaltId = entry["newsItem"]["metadata"]["altId"]
  crtguId = entry["newsItem"]["sourceId"]
  #Do the update operation in the MongoDB collection
  update(News, Dict("altId"=>crtaltId, "firstCreated"=>crtdate), Dict("\$push"=>Dict("takes.$(updatePos-1).analytics"=>json_to_dic(entry)["takes"][1]["analytics"][1])))
end #fun

"""
addOnlyAnalytics(entry::BSONobject, updatePos::Int)
============================
## Adds a whole take to a story in the MongoDb collection.

### Inputs:
  * entry(BSONobject) : A parsed JSON line of a take (which is a "complete story" for a single companie's analytics)
"""
function addCompleteTake(entry)
  # Gather guId, altId and timestamp in variables for ease of use
  crtdate = Dates.DateTime(entry["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
  crtaltId = entry["newsItem"]["metadata"]["altId"]
  crtguId = entry["newsItem"]["sourceId"]
  #Do the update operation in the MongoDB collection
  update(News, Dict("altId"=>crtaltId, "firstCreated"=>crtdate), Dict("\$push"=>Dict("takes"=>json_to_dic(entry)["takes"][1])))
end #fun


#############################################################################%%
# This block is to create all the stories (empty) in the MongoDB collection #
#############################################################################

for y in y_start:y_end
  print(y)
  tic()
  altidstime = [] # Array where I will store all (altId,timestamp) pairs
  ###Open Doc of the year###
  f = open(replace(datapath, "@", y)) #open file
  i = 0
  for l in eachline(f)
    i+=1
    if length(i)%20000==0
      print(i)
    end
    if length(l)>6
      if l[1:6]=="{\"guid" # The two conditions==true if I am on a valid line in the JSON file
        if l[end]==',' #not the last line
          # simply add the altId, firstCreated pair to the list of all of them
          altId = JSON.parse(l[1:end-1])["data"]["newsItem"]["metadata"]["altId"]
          firstCreated = Dates.DateTime(JSON.parse(l[1:end-1])["data"]["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
          if (y>y_start && firstCreated>=DateTime(y,1,1)) || y==y_start
            push!(altidstime, [altId, firstCreated])
          end
        else #last line
          # simply add the altId, firstCreated pair to the list of all of them
          altId = JSON.parse(l[1:end])["data"]["newsItem"]["metadata"]["altId"]
          firstCreated = Dates.DateTime(JSON.parse(l[1:end])["data"]["newsItem"]["metadata"]["firstCreated"], "yyyy-mm-ddTHH:MM:SS.sssZ")
          if (y>y_start && firstCreated>=DateTime(y,1,1)) || y==y_start
            push!(altidstime, [altId, firstCreated])
          end
        end
      end # if a single item
    end #if length>6
  end
  close(f)
  ###Close Doc of the year###
  # Get all unique pairs of the year
  uniquealtIdpairs = Set(altidstime)
  print("Set is set")
  # Structure the pairs + a take field to be ready to be inserted in the MongodDB collection
  wholedic = []
  for elem in uniquealtIdpairs
    push!(wholedic, Dict("altId" => elem[1],"firstCreated" => elem[2],"takes" => []))
  end# for elem
  # Push those pairs to the MongoDB collection
  for news in wholedic
    insert(News, news)
  end
end #for y

# Create compound idexes on altId and timestamp
command_simple(client, "NewsDB", Dict("createIndexes"=>"News",
                                      "indexes"=>[Dict("key"=>Dict("altId"=>1, "firstCreated"=>1),
                                                       "name"=>"idStory",
                                                       "unique"=>1)]))

####################################################################%%
# This block adds the takes and analytics correctly to the stories #
####################################################################
for y in 2017:2017
  f = open(replace(datapath, "@", y)) #open file
  tic()
  i = 0
  tic()
  for l in eachline(f)
    i+=1
    if i%20000==0
      print(i)
      toc()
      tic()
    end
    if i>523312 && !(i in [523312, 523314, 523540, 523596, 523669, 523670, 523715, 523716, 523720, 523724, 523725, 523733, 523737, 523740, 523750, 523801, 523820, 523899, 524097, 524150, 524155, 524178, 524202, 524295, 524296, 524709, 525171, 525175, 525417, 525419, 525420, 525421, 525422, 525452, 526175, 954943, 954944, 954945])
      if length(l)>6
        if l[1:6]=="{\"guid"
          if l[end]==','
            updatePos, guIdexists, ntakes = nbTakes(JSON.parse(l[1:end-1])["data"])
            if ntakes == 0
              addCompleteTake(JSON.parse(l[1:end-1])["data"])
            elseif guIdexists
              addOnlyAnalytics(JSON.parse(l[1:end-1])["data"], updatePos)
            else
              addCompleteTake(JSON.parse(l[1:end-1])["data"])
            end #if no previous take
          else
            updatePos, guIdexists, ntakes = nbTakes(JSON.parse(l[1:end])["data"])
            if ntakes == 0
              addCompleteTake(JSON.parse(l[1:end])["data"])
            elseif guIdexists
              addOnlyAnalytics(JSON.parse(l[1:end])["data"], updatePos)
            else
              addCompleteTake(JSON.parse(l[1:end])["data"])
            end #if no previous take
          end #if last element
        end # if a single item
      end #if length>6
    end # if workaround
  end
  close(f)
  toc()
  toc()
end

# Ca a foiré en ligne ~560000 de 2016


f = open(replace(datapath, "@", 2017)) #open file
i=0
for l in eachline(f)
  i+=1
  try
    ticker =  split(split(JSON.parse(l[1:end-1])["data"]["analytics"]["analyticsScores"][1]["assetCodes"][2], ":")[2], ".")[1]
  catch x
    print("$i, ")
  end
end
close(f)

# Il faudrait refaire l'année 2016 car certaines news ont été updatées 2 fois (double analytic?)
