module LoadFF

using Dates, CSV
export FFfactors

function FFfactors(filename="dailyFactors.csv" ; rootpath="/home/nicolas/Data/FF", rowstoread=1:3776)
    FFfactors = CSV.read("$rootpath/$filename")[rowstoread,:]
    todate = x -> Date(string(x),"yyyymmdd")
    FFfactors[:Date] = todate.(FFfactors[:Date])
    return FFfactors
end

end #module
