using InfoZIP, CSV, DataFrames, PyCall, Dates, Plots

crtdir = "/home/nicolas/Data/TRMI"
filenames = readdir(crtdir)

crtfile = filenames[1]
for crtfile in filenames
    InfoZIP.unzip("$(crtdir)/$(crtfile)", "$(crtdir)/tmp/")
end

extractDir = "$(crtdir)/tmp"

py"""
import os
for filename in os.listdir($extractDir):
    print($extractDir + "/" + filename[0:-3]+"csv")
    os.rename($extractDir + "/" + filename, $extractDir + "/" + filename[0:-3]+"csv")
"""

filenames = readdir(extractDir)
crtfile = filenames[1]
df = CSV.read("$(extractDir)/$(crtfile)", delim='	')
df = df[df[:assetCode].=="US", :]
function addTRMIdfs!(df, filenames)
    for crtfile in filenames
        prov = CSV.read("$(extractDir)/$(crtfile)", delim='	')
        df = vcat(df, prov[prov[:assetCode].=="US", :])
    end
    return df
end
df = addTRMIdfs!(df, filenames[2:end])

names(df)
reutersDateformat = DateFormat("yyyy-mm-ddTHH:MM:SS.sssZ")
DateTime("1995-04-15 15:45:45", reutersDateformat)
reutersDate(x) = DateTime(x, reutersDateformat)
df[:windowTimestamp] = reutersDate.(df[:windowTimestamp])
social = df[df[:dataType].=="Social", :]
news = df[df[:dataType].=="News", :]
news_social = df[df[:dataType].=="News_Social", :]

plotlyjs()
plot(social[:windowTimestamp], [news[:stockIndexBuzz], news_social[:stockIndexBuzz]])
plot(social[:windowTimestamp], [news[:stockIndexSentiment], news_social[:stockIndexSentiment], social[:stockIndexSentiment]])
plot(social[:windowTimestamp], [social[:stockIndexOptimism]])
