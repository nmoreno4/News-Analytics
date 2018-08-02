using Mongo

client = MongoClient()   # Defaults to MongoClient("localhost", 27017)
TRNAcoll = MongoCollection(client, "NewsDB", "copyflatstockdate")

excludezerosent = 0.00000000000000002

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
for td in 2:3777
  smallgrowthcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"SL"))
  biggrowthcursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"BL"))
  smallvaluecursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"SH"))
  bigvaluecursor = find(TRNAcoll,
    Dict("td"=>td, "ptf_2by3_size_value"=>"BH"))

  smallgrowthret, smallgrowthsent, biggrowthret, biggrowthsent = [], [], [], []
  smallvalueret, smallvaluesent, bigvalueret, bigvaluesent = [], [], [], []
  smallgrowthwport, biggrowthwport, smallvaluewport, bigvaluewport = [], [], [], []
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

end

using RCall
@rput VWgrowthsent
@rput VWvaluesent
R"plot(VWgrowthsent)"
R"plot(VWvaluesent)"
R"plot(TTR::SMA(VWvaluesent, n=60), type = 'l')"
R"plot(TTR::SMA(VWgrowthsent, n=60), type = 'l')"
R"plot(TTR::SMA(VWvaluesent-VWgrowthsent, n=60), type = 'l')"
