push!(LOAD_PATH, "$(pwd())/Database management/WRDSmodules")
push!(LOAD_PATH, "$(pwd())/Database management/Mongo_Queries")
push!(LOAD_PATH, "$(pwd())/Useful functions")
using Mongo, WRDSdownload, CSV

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "copyflatstockdate")
### Load dates and trading days ###
y_start = 2003
y_end = 2017
FF_factors = FF_factors_download(["01/01/$(y_start)", "12/31/$(y_end)"])

excludezerosent = 0.00000000000000001

function meanexclude(X, toexclude = 0)
  res = Float64[]
  for x in X
    if x!= toexclude
      push!(res, x)
    end
  end
  if length(res)==0
    push!(res,0)
  end
  return mean(res)
end

VWvaluesent = Float64[]
VWgrowthsent = Float64[]
EWvaluesent = Float64[]
EWgrowthsent = Float64[]
VWsmallsent = Float64[]
VWbigsent = Float64[]
EWsmallsent = Float64[]
EWbigsent = Float64[]
for td in 2:3777
  smallgrowthcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"SL"))
  biggrowthcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"BL"))
  smallvaluecursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"SH"))
  bigvaluecursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"BH"))
  smallmedcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"SM"))
  bigmedcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"BM"))

  smallgrowthret, smallgrowthsent, biggrowthret, biggrowthsent = [], [], [], []
  smallvalueret, smallvaluesent, bigvalueret, bigvaluesent = [], [], [], []
  smallgrowthwport, biggrowthwport, smallvaluewport, bigvaluewport = [], [], [], []
  smallmedwport, smallmedret, smallmedsent = [], [], []
  bigmedwport, bigmedret, bigmedsent = [], [], []

  for entry in smallgrowthcursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(smallgrowthsent, crtsent)
    push!(smallgrowthret, entry["dailyretadj"])
    push!(smallgrowthwport, entry["wport"])
  end
  for entry in biggrowthcursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(biggrowthsent, crtsent)
    push!(biggrowthret, entry["dailyretadj"])
    push!(biggrowthwport, entry["wport"])
  end
  for entry in smallvaluecursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(smallvaluesent, crtsent)
    push!(smallvalueret, entry["dailyretadj"])
    push!(smallvaluewport, entry["wport"])
  end
  for entry in bigvaluecursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(bigvaluesent, crtsent)
    push!(bigvalueret, entry["dailyretadj"])
    push!(bigvaluewport, entry["wport"])
  end
  for entry in smallmedcursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(smallmedsent, crtsent)
    push!(smallmedret, entry["dailyretadj"])
    push!(smallmedwport, entry["wport"])
  end
  for entry in bigmedcursor
    crtsent = 0.00000000000000001
    try
      crtsent = entry["sentClasRel"]
    end
    push!(bigmedsent, crtsent)
    push!(bigmedret, entry["dailyretadj"])
    push!(bigmedwport, entry["wport"])
  end

  smallvaluewport[findin(smallvaluesent, excludezerosent)] = excludezerosent
  bigvaluewport[findin(bigvaluesent, excludezerosent)] = excludezerosent
  filter!(e->e≠excludezerosent, smallvaluewport)
  filter!(e->e≠excludezerosent, bigvaluewport)
  filter!(e->e≠excludezerosent, bigvaluesent)
  filter!(e->e≠excludezerosent, smallvaluesent)
  push!(VWvaluesent, (sum((smallvaluewport.*smallvaluesent)./sum(smallvaluewport))
                    + sum((bigvaluewport.*bigvaluesent)./sum(bigvaluewport)))
                    / 2)
  push!(EWvaluesent, (mean(smallvaluesent) + mean(bigvaluesent))/2)

  smallgrowthwport[findin(smallgrowthsent, excludezerosent)] = excludezerosent
  biggrowthwport[findin(biggrowthsent, excludezerosent)] = excludezerosent
  filter!(e->e≠excludezerosent, smallgrowthwport)
  filter!(e->e≠excludezerosent, biggrowthwport)
  filter!(e->e≠excludezerosent, biggrowthsent)
  filter!(e->e≠excludezerosent, smallgrowthsent)
  push!(VWgrowthsent, (sum((smallgrowthwport.*smallgrowthsent)./sum(smallgrowthwport))
                    + sum((biggrowthwport.*biggrowthsent)./sum(biggrowthwport)))
                    / 2)
  push!(EWgrowthsent, (mean(smallgrowthsent) + mean(biggrowthsent))/2)


  #size portfolios
  smallmedwport[findin(smallmedsent, excludezerosent)] = excludezerosent
  bigmedwport[findin(bigmedsent, excludezerosent)] = excludezerosent
  filter!(e->e≠excludezerosent, smallmedwport)
  filter!(e->e≠excludezerosent, bigmedwport)
  filter!(e->e≠excludezerosent, bigmedsent)
  filter!(e->e≠excludezerosent, smallmedsent)

  push!(VWbigsent, (sum((biggrowthwport.*biggrowthsent)./sum(biggrowthwport))
                    + sum((bigmedwport.*bigmedsent)./sum(bigmedwport))
                    + sum((bigvaluewport.*bigvaluesent)./sum(bigvaluewport)))
                    / 3)
  push!(EWbigsent, (mean(biggrowthsent) + mean(bigmedsent) + mean(bigvaluesent))/3)

  push!(VWsmallsent, (sum((smallgrowthwport.*smallgrowthsent)./sum(smallgrowthwport))
                    + sum((smallmedwport.*smallmedsent)./sum(smallmedwport))
                    + sum((smallvaluewport.*smallvaluesent)./sum(smallvaluewport)))
                    / 3)
  push!(EWsmallsent, (mean(smallgrowthsent) + mean(smallmedsent) + mean(smallvaluesent))/3)

end

mktrf = FF_factors[:mktrf]
smb = FF_factors[:smb]
hml = FF_factors[:hml]
umd = FF_factors[:umd]
smbsent = VWsmallsent-VWbigsent
hmlsent = VWvaluesent-VWgrowthsent

FF_factors[:VWvaluesent] = VWvaluesent
FF_factors[:VWgrowthsent] = VWgrowthsent
FF_factors[:VWsmallsent] = VWsmallsent
FF_factors[:VWbigsent] = VWbigsent
FF_factors[:smbsent] = smbsent
FF_factors[:hmlsent] = hmlsent

CSV.write("/home/nicolas/Data/Intermediate/FF_sent.csv", FF_factors)

using RCall, TimeSeries
# dates  = collect(Date(1999,1,1):Date(2000,12,31))
# mytime = TimeArray(dates, rand(length(dates),2))
TS = TimeArray(FF_factors[:date], Array{Float64}(FF_factors[:, 2:end]), [String(x) for x in names(FF_factors)][2:end])
TSbis = moving(mean, TS, 5)
TSbis = when(TSbis, dayofweekofmonth, 1)
TSbis = when(TSbis, dayofweek, 3)
TSter = moving(geomean, TS+1, 5)-1
TSter = when(TSter, dayofweekofmonth, 1)
TSter = when(TSter, dayofweek, 3)

mktrf = values(TSter["mktrf"])
hml = values(TSter["hml"])
smb = values(TSter["smb"])
smbsent = values(TSbis["smbsent"])
hmlsent = values(TSbis["hmlsent"])

@rput VWgrowthsent
@rput VWvaluesent
@rput mktrf
@rput smb
@rput hml
@rput umd
@rput smbsent
@rput hmlsent
R"lmmod <- lm(hml[2:length(mktrf)] ~ hmlsent[2:length(mktrf)-0] + hmlsent[1:length(mktrf)-1])"
R"summary(lmmod)"
R"plot(VWvaluesent)"
R"plot(TTR::SMA(VWvaluesent, n=60), type = 'l')"
R"plot(TTR::SMA(VWgrowthsent, n=60), type = 'l')"
R"plot(TTR::SMA(VWvaluesent-VWgrowthsent, n=60), type = 'l')"
