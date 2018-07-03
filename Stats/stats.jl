using JLD2, DataFrames, CSV

@load "/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/Data Inputs/permnoToPermId.jld2"

a = DataFrame(Any[values(mappingDict)...],Symbol[map(Symbol,keys(mappingDict))...])
CSV.write("/run/media/nicolas/OtherData/home/home/nicolas/CodeGood/Data Inputs/permnoToPermId.csv", a)
