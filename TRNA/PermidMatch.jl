module PermidMatch

using DataFrames, CSV
export splitCSVforPermiDMatch, gvkeyPermidMatchDF

function splitCSVforPermiDMatch(crtdf)
    permidmatchinput = by(crtdf, :gvkey, LocalID = :gvkey => x -> x[1], tic = :tic => x -> x[1], cik = :cik => x -> x[1], Name = :conm => x -> x[1])[[:LocalID, :tic, :cik, :Name]]
    # permidmatchinput[:LocalID] = parse.(Int, permidmatchinput[:LocalID])
    permidmatchinput[Symbol("Standard Identifier")] = ""
    for row in 1:size(permidmatchinput,1)
        if !(ismissing(permidmatchinput[row,:cik]))
            permidmatchinput[row,Symbol("Standard Identifier")] = "Ticker:$(permidmatchinput[row,:tic])|CIK:$(permidmatchinput[row,:cik])"
        else
            permidmatchinput[row,Symbol("Standard Identifier")] = "Ticker:$(permidmatchinput[row,:tic])"
        end
    end
    DataFrames.deletecols!(permidmatchinput, [:cik,:tic])
    for i in 1:32
        CSV.write("/home/nicolas/Data/permidmatch/newmatch/m$(i).csv", permidmatchinput[(i-1)*500+1:minimum([i*500,size(permidmatchinput,1)]),:])
    end
end


function gvkeyPermidMatchDF(rootpath="/home/nicolas/Data/permidmatch/newmatch/matched")
    matchDF = CSV.read("$(rootpath)/m1_matched_records.csv")
    for crtfile in readdir(rootpath)
        if crtfile!="m1_matched_records.csv"
            matchDF = vcat(matchDF, CSV.read("$(rootpath)/$(crtfile)"))
        end
    end
    return matchDF
end



end #module
