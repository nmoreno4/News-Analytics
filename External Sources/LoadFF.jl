module LoadFF

using Dates, CSV, DataFrames
export FFfactors

function FFfactors(filename="dailyFactors.csv" ; rootpath="/home/nicolas/Data/FF", rowstoread=1:3776)
    FFfactors = CSV.read("$rootpath/$filename")[rowstoread,:]
    todate = x -> Date(string(x),"yyyymmdd")
    FFfactors[:Date] = todate.(FFfactors[:Date])
    div100 = x -> x ./ 100
    FFfactors[:,2:end] = mapcols(div100, FFfactors[:,2:end])
    return FFfactors
end

end #module
