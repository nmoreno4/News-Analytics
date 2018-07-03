using Mongo, TimeSeries, Plots, DataFrames, NaNMath, StatsBase, CSV
client = MongoClient()
MERGEconnect = MongoCollection(client, "NewsDB", "CRSPTRNAmerge2")

factor = "value"
periodlength = Dates.Year(1)
startdate = Dates.Date(2003,1,1)
enddate = Dates.Date(2017,7,1)
wholeresults = []
for period in startdate:periodlength:enddate
        periodresults = []
        print(period)
        for decile in 0:9
                sentiment = Float64[]
                storiesCount = Float64[]
                wport = Float64[]
                diffPosNeg = Float64[]
                adjret = Float64[]
                cursor = find(MERGEconnect,
                                Mongo.query("date" => Dict(
                                                    "\$gt"=>period,
                                                    "\$lte"=>period+periodlength
                                            )
                                        )
                                )
                for entry in cursor
                        sent = entry["sentClasRel"]
                        count = entry["storiesCount"]
                        w = entry["wport"]
                        sent2 = entry["diffPosNeg"]
                        ret = entry["adjret"]
                        a = entry["ptf_10by10_size_value"]
                        if factor == "size"
                                if floor(entry["ptf_10by10_size_value"])==decile
                                        push!(sentiment, sent)
                                        push!(storiesCount, count)
                                        push!(diffPosNeg, sent2)
                                        push!(adjret, ret)
                                        push!(wport, w)
                                end
                        elseif factor == "value"
                                if round((a-floor(a))*10)==decile
                                        push!(sentiment, sent)
                                        push!(storiesCount, count)
                                        push!(diffPosNeg, sent2)
                                        push!(adjret, ret)
                                        push!(wport, w)
                                end
                        end
                end
                wport = wport./NaNMath.sum(wport)
                push!(periodresults, (NaNMath.mean(sentiment),
                                      NaNMath.sum(storiesCount),
                                      NaNMath.mean(storiesCount),
                                      NaNMath.mean(diffPosNeg),
                                      (NaNMath.mean(adjret)+1)^252-1,
                                      (NaNMath.sum(adjret.*wport)+1)^252-1,
                                      NaNMath.sum(sentiment.*wport),
                                      NaNMath.sum(diffPosNeg.*wport),
                                      NaNMath.sum(storiesCount.*wport)))
        end
        push!(wholeresults, periodresults)
end


df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][1],period[2][1],period[3][1],period[4][1], period[5][1], period[6][1],period[7][1],period[8][1],period[9][1], period[10][1], period[10][1]-period[1][1]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)sentsummary.csv"
CSV.write(output, df)

## Stories count sum ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][2],period[2][2],period[3][2],period[4][2], period[5][2], period[6][2],period[7][2],period[8][2],period[9][2], period[10][2], period[10][2]-period[1][2]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)storiescountsumsummary.csv"
CSV.write(output, df)

## Stories count mean ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][3],period[2][3],period[3][3],period[4][3], period[5][3], period[6][3],period[7][3],period[8][3],period[9][3], period[10][3], period[10][3]-period[1][3]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)storiescountmeansummary.csv"
CSV.write(output, df)

## diffposneg ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][4],period[2][4],period[3][4],period[4][4], period[5][4], period[6][4],period[7][4],period[8][4],period[9][4], period[10][4], period[10][4]-period[1][4]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)diffposnegsummary.csv"
CSV.write(output, df)

## EW adjret ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][5],period[2][5],period[3][5],period[4][5], period[5][5], period[6][5],period[7][5],period[8][5],period[9][5], period[10][5], period[10][5]-period[1][5]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)EWretsummary.csv"
CSV.write(output, df)

## VW ret ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][6],period[2][6],period[3][6],period[4][6], period[5][6], period[6][6],period[7][6],period[8][6],period[9][6], period[10][6], period[10][6]-period[1][6]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)VWretsummary.csv"
CSV.write(output, df)


## VW sentposneg ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][7],period[2][7],period[3][7],period[4][7], period[5][7], period[6][7],period[7][7],period[8][7],period[9][7], period[10][7], period[10][7]-period[1][7]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)VWsentclasrelsummary.csv"
CSV.write(output, df)


## VW stories count ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][8],period[2][8],period[3][8],period[4][8], period[5][8], period[6][8],period[7][8],period[8][8],period[9][8], period[10][8], period[10][8]-period[1][8]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)VWdiffposnegsummary.csv"
CSV.write(output, df)


## VW ret ##
df = DataFrame(p1 = Float64[], p2 = Float64[], p3 = Float64[], p4 = Float64[], p5 = Float64[], p6 = Float64[], p7 = Float64[], p8 = Float64[], p9 = Float64[], p10 = Float64[], p10_1 = Float64[])
for period in wholeresults
        push!(df, hcat(period[1][9],period[2][9],period[3][9],period[4][9], period[5][9], period[6][9],period[7][9],period[8][9],period[9][9], period[10][9], period[10][9]-period[1][9]))
end
output = "/run/media/nicolas/OtherData/home/home/nicolas/Data/Results/$(factor)VWcountsummary.csv"
CSV.write(output, df)





















wholeresults = []
for period in startdate:periodlength:enddate
    print(period)
    periodresults = []
    for decile in ("SH", "SM", "SL", "BH", "BM", "BL")
        sentiment = Float64[]
        storiesCount = Float64[]
        cursor = find(MERGEconnect,
                        Mongo.query("date" => Dict(
                                            "\$gt"=>period,
                                            "\$lte"=>period+periodlength),
                                    "ptf_2by3_size_value" => decile
                                    )
                        )
        for entry in cursor
            push!(sentiment, entry["sentClasRel"])
            push!(storiesCount, entry["storiesCount"])
        end
        push!(periodresults, (NaNMath.mean(sentiment),
                              NaNMath.sum(storiesCount)))
    end
    push!(wholeresults, periodresults)
end















# wholeresults = []
# for period in startdate:periodlength:enddate
#     periodresults = []
#     for decile in 0:9
#         sentiment = Float64[]
#         storiesCount = Float64[]
#         cursor = find(MERGEconnect,
#                         Mongo.query("date" => Dict(
#                                             "\$gt"=>period,
#                                             "\$lte"=>period+periodlength),
#                                     "ptf_10by10_size_value" => Dict(
#                                             "\$gte"=>decile,
#                                             "\$lt"=>decile+1)
#                                     )
#                         )
#         for entry in cursor
#             push!(sentiment, entry["sentClasRel"])
#             push!(storiesCount, entry["storiesCount"])
#         end
#         push!(periodresults, (NaNMath.mean(sentiment),
#                               NaNMath.sum(storiesCount)))
#     end
#     push!(wholeresults, periodresults)
# end
