using Mongo
client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "copyflatstockdate")

cursor = find(TRNAcoll,Dict())

sents = Array{Float64}(14100000)
sentsonlynews = Array{Float64}(4100000)
i=0
j=1
@inbounds @time for doc in cursor
    i+=1
    try
        sent = doc["sentClasRel"]
        sents[i] = sent
        sentsonlynews[j] = sent
        j+=1
    catch
        sents[i] = 0
    end
end
sents = sents[1:i]
sentsonlynews = sentsonlynews[1:j]
std(sents)
std(sentsonlynews)
median(sentsonlynews)
using GR, Plots, StatsBase
gr()
histogram(sents)
histogram(sentsonlynews)
ma = Float64[]
w = 60
i=0
for el in sentsonlynews
    i+=1
    if i>w
        push!(ma, mean(sentsonlynews[i-w:i]))
    end
end
std(ma)
GR.histogram(ma)
mean(ma)
percentile(ma, 50)
percentile(ma, 60)
percentile(ma, 40)
percentile(ma, 97)
percentile(ma, 3)
