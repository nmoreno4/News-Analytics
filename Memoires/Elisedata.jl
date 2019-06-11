using PyMongoDF, Dates, CSV, DataFrames

retvalues = ["date", "permno", "permid",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",]
X = @time TRNAmongoDF(retvalues; monthrange = Month(3), startDate = DateTime(2010,12,31), endDate = DateTime(2017,12,31), showAdv=true)
X = X[.!ismissing.(X[:nS_nov24H_0_rel100]), :]
sort!(X, [:permid, :date])
@time CSV.write("/home/nicolas/Documents/Memoires/elisedata.csv", X)
sum((.!ismissing.(X[:permid])) .& (X[:permid].==5030853586))
