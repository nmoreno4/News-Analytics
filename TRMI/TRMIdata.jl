module TRMIdata
using InfoZIP, CSV, DataFrames, PyCall, Dates
export load_market_TRMI, aggregTRMI, rollingAggregTRMI, multipleTRMIvars

function __init__()
    py"""
    import os
    def renameCSV(extractDir):
        print(extractDir)
        for filename in os.listdir(extractDir):
            # print(extractDir + "/" + filename[0:-3]+"csv")
            os.rename(extractDir + "/" + filename, extractDir + "/" + filename[0:-3]+"csv")
    """
end

function load_market_TRMI(crtdir="/home/nicolas/Data/TRMI", country="US", targetextract = "tmp")
    filenames = readdir(crtdir)
    try
        mkdir("$(crtdir)/$(targetextract)")
    catch err
        print("Directory '$(crtdir)/$(targetextract)' already exists")
    end

    for crtfile in filenames
        try
            InfoZIP.unzip("$(crtdir)/$(crtfile)", "$(crtdir)/$(targetextract)/")
        catch err
            print("File already extracted here")
        end
    end

    extractDir = "$(crtdir)/$(targetextract)"

    py"""
    renameCSV($extractDir)
    """

    filenames = readdir(extractDir)
    crtfile = filenames[1]
    df = CSV.read("$(extractDir)/$(crtfile)", delim='	')
    df = df[df[:assetCode].==country, :]

    df = addTRMIdfs!(df, filenames[2:end], extractDir, country)

    return df
end



function addTRMIdfs!(df, filenames, extractDir, country)
    for crtfile in filenames
        prov = CSV.read("$(extractDir)/$(crtfile)", delim='	')
        df = vcat(df, prov[prov[:assetCode].==country, :])
    end
    return df
end



function aggregTRMI(df, winLength, varName)
    res, dates = [[] for i in 1:2]
    for date in ceil(minimum(df[:windowTimestamp]), Month):winLength:ceil(maximum(df[:windowTimestamp]), Month)
        crtdf = df[findall((df[:windowTimestamp].<date) .& (df[:windowTimestamp].>=date-winLength)), :]
        crtdf = crtdf[(.!ismissing.(crtdf[:stockIndexBuzz])) .& (.!ismissing.(crtdf[varName])), : ]
        push!(res, sum(crtdf[:stockIndexBuzz] .* crtdf[varName])/sum(crtdf[:stockIndexBuzz]))
        push!(dates, date)
    end
    return DataFrame(Dict("date"=>dates, "$(varName)"=>res))
end

function rollingAggregTRMI(df, wLength, varName)
    rollLength = wLength[1]
    winLength = wLength[2]
    res, dates = [[] for i in 1:2]
    for date in ceil(minimum(df[:windowTimestamp]), Month):rollLength:ceil(maximum(df[:windowTimestamp]), Month)
        crtdf = df[findall((df[:windowTimestamp].<date) .& (df[:windowTimestamp].>=date-winLength)), :]
        crtdf = crtdf[(.!ismissing.(crtdf[:stockIndexBuzz])) .& (.!ismissing.(crtdf[varName])), : ]
        push!(res, sum(crtdf[:stockIndexBuzz] .* crtdf[varName])/sum(crtdf[:stockIndexBuzz]))
        push!(dates, date)
    end
    return DataFrame(Dict("date"=>dates, "$(varName)"=>res))
end

function multipleTRMIvars(df, winLength, vars, aggregfct=aggregTRMI)
    resdf = aggregfct(df, winLength, vars[1])
    for crtvar in vars[2:end]
        resdf = hcat(resdf, aggregfct(df, winLength, crtvar)[crtvar])
        names!(resdf, [names(resdf)[1:end-1]; crtvar])
    end
    return resdf
end

end #module
