module aggregateQueries
using Mongo
export aggregSentiment, matchingDay, postregression

"""
    marketSentiment(alldates, MERGEconnect, ptftype = "ptf_2by3_size_value", ptfquintiles = ["SL", "SM", "SH", "BL", "BM", "BH"], sentType = "sentClasRel")

Input dates and Mongo connection to get the returns and sentiments of stocks matching the desired portfolio.

This function queries the TRNA-CRSP merged database to find all returns and sentiments of stocks in a portfolio at each date given in the vector *alldates*
"""
function aggregSentiment(alldates, MERGEconnect, sentType = "sentClasRel", ptftype = "ptf_2by3_size_value", ptfquintiles = ["SL", "SM", "SH", "BL", "BM", "BH"])
    EWsent, VWsent, EWret, VWret = Float64[], Float64[], Float64[], Float64[]
    for date in alldates
        sent, wport, returns = Float64[], Float64[], Float64[]
        cursor = find(MERGEconnect,
                    Mongo.query("date" => date,
                                ptftype => Dict("\$in" => ptfquintiles)))
        for entry in cursor
            weight = entry["wport"]
            sentiment = entry[sentType]
            ret = entry["adjret"]
            if isnan(sentiment)
                sentiment=0
            end
            push!(wport, weight)
            push!(sent, sentiment)
            push!(returns, ret)
        end
        push!(EWsent, mean(sent))
        wvec = wport./sum(wport)
        push!(VWsent, sum(sent.*wvec))
        push!(EWret, mean(returns))
        push!(VWret, sum(returns.*wvec))
    end
    return VWsent, VWret, EWsent, EWret
end

function matchingDay(MERGEconnect, crtperiod, pastspan, ptftype = "ptf_2by3_size_value", ptfquintiles = ["SL", "SM", "SH", "BL", "BM", "BH"])
    cursor = find(MERGEconnect,
                Mongo.query("date" => Dict("\$gte"=>crtperiod-pastspan,
                                           "\$lt"=>crtperiod),
                            ptftype => Dict("\$in" => ptfquintiles)))
    return cursor
end

function postregression(MERGEconnect, chosenstocks, firstdate, lastdate, ptftype = "ptf_2by3_size_value", ptfquintiles = ["SL", "SM", "SH", "BL", "BM", "BH"])
    cursor = find(MERGEconnect,
                Mongo.query("date" => Dict("\$gte"=>firstdate,
                                           "\$lt"=>lastdate),
                            "permno" => Dict("\$in" => chosenstocks),
                            ptftype => Dict("\$in" => ptfquintiles)))
    return cursor
end

end #module
