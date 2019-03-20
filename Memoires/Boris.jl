using MongoDF, Dates, DataFrames, CSV

retvalues = ["date", "permno", "retadj", "permid",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100"]
X = @time TRNAmongoDF(retvalues; monthrange = Month(3), startDate = DateTime(2002,12,31), endDate = DateTime(2017,12,31))
names(X)
names!(X, [:date, :NBnews, :NegSum, :permid, :permno, :PosSum, :retadj])

typeof(X[:permid])
X[:NBnews] = replace(X[:NBnews], missing=>0)
X[:PosSum] = replace(X[:PosSum], missing=>99)
X[:NegSum] = replace(X[:NegSum], missing=>99)
X[:permid] = Int.(replace(X[:permid], missing=>0))
@time CSV.write("/run/media/nicolas/Research/Boris/data.csv", X)

X = CSV.read("/run/media/nicolas/Research/Boris/data.csv")
A = X[X[:permno].==58683, [:NBnews, :NegSum, :PosSum, :permid]]

X[[:permno, :posSum_nov24H_0_rel100, :negSum_nov24H_0_rel100]]
