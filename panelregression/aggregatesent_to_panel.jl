using CSV, DataFrames
dftoloadname = "rawpanel5"
df = CSV.read("/home/nicolas/Data/Intermediate/$(dftoloadname).csv", rows_for_type_detect=3737)
aggsent = CSV.read("/home/nicolas/Data/Intermediate/FF_sent.csv")

print("Data read!")

oldnames = names(df)
FFnames = names(aggsent)[[2:4;6:end]]
df = Array{Any}(df)
FF = Array{Any}(size(df,1), 10)
@time @inbounds for row in eachindex(df[:,2])
    td = df[row,2]-1
    FF[row,1] = aggsent[:mktrf][td]
    FF[row,2] = aggsent[:smb][td]
    FF[row,3] = aggsent[:hml][td]
    FF[row,4] = aggsent[:umd][td]
    FF[row,5] = aggsent[:VWvaluesent][td]
    FF[row,6] = aggsent[:VWgrowthsent][td]
    FF[row,7] = aggsent[:VWsmallsent][td]
    FF[row,8] = aggsent[:VWbigsent][td]
    FF[row,9] = aggsent[:smbsent][td]
    FF[row,10] = aggsent[:hmlsent][td]
end
CSV.write("/home/nicolas/Data/Intermediate/$(dftoloadname)_FF.csv", names!(DataFrame([df FF]), [oldnames; FFnames]))
