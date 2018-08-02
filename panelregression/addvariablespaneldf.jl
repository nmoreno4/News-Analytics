using CSV

### Load panel df ###
dftoloadname = "rawpanel1"
df = CSV.read("/home/nicolas/Data/Intermediate/$(dftosavename).csv", rows_for_type_detect=3737)

sort!(df, cols = [:permno, :td])
groupeddf = groupby(df, :permno)
