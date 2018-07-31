using databaseQuerer, StringDistances, Mongo, JLD2

rootpath = "/home/nicolas/CodeGood/Data Inputs"

client = MongoClient()
CRSPconnect = MongoCollection(client, "NewsDB", "CRSPmonthly")
companiesConnect = MongoCollection(client, "NewsDB", "Companies")

allPERMNOs = collect(fieldDistinct(CRSPconnect, ["PERMNO"])[1])
intPERMNOs = map(x->trunc(Int, x),allPERMNOs)
CRSPallIds = []
idFields = ["TICKER", "NCUSIP", "PERMCO", "COMNAM", "FFI48_desc", "EXCHCD", "PERMNO"]
for permno in intPERMNOs
     uniquesets = fieldDistinct(CRSPconnect, idFields, "PERMNO", permno)
     push!(CRSPallIds, uniquesets)
end

allPermIDs = collect(fieldDistinct(companiesConnect, ["permID"])[1])
idFields = ["ticker", "COMNAM", "RIC", "status", "sector", "marketMIC", "country", "permID"]
ReutersallIds = []
for permId in allPermIDs
     uniquesets = fieldDistinct(companiesConnect, idFields, "permID", permId)
     push!(ReutersallIds, uniquesets)
end

toolow = []
c=0
mappingDict = Dict()
tic()
for comp in CRSPallIds
     print("\n")
     c+=1
     COMNAMs = collect(comp[4])
     tickers = collect(comp[1])
     PERMNO = collect(comp[7])[1]
     keptIdx = []
     for COMNAM in COMNAMs
          wastrue = 0
          collectedDistances = []
          idx = 0
          for Reut in ReutersallIds
               idx+=1
               if  compare(Winkler(Hamming()), lowercase(COMNAM), lowercase(collect(Reut[2])[1])) > -1
                    push!(keptIdx, idx)
               end
          end
     end #for COMNAM
     # print("\n # of sufficiently similar names: $(length(keptIdx))")
     same_ticker = []
     highest_likelyhood = [0,0]
     for i in keptIdx
          RCOMNAMs = collect(ReutersallIds[i][2])
          Rtickers = collect(ReutersallIds[i][1])
          permId = collect(ReutersallIds[i][8])
          if length(intersect(Rtickers, tickers)) > 0
               push!(same_ticker, i)
          end
          for COMNAM in COMNAMs
               if COMNAM==""
                    COMNAM = "isdjafhsadfn sadvjpoaskljvbksavj "
               end
               nameSimilarity = compare(Winkler(Hamming()), lowercase(COMNAM), lowercase(RCOMNAMs[1]))
               if nameSimilarity > highest_likelyhood[2]
                    highest_likelyhood = [i, nameSimilarity]
               end
          end # for COMNAM
     end #for kept Reuters Ids
     if length(same_ticker)!=0
          if highest_likelyhood[1] == same_ticker[1]
               # print("AWESOOOOME")
               mappingDict[PERMNO] = collect(ReutersallIds[trunc(Int,highest_likelyhood[1])][8])[1]
          elseif length(same_ticker)>1
               # print("TWO SAME TICKERS")
               if highest_likelyhood[2]>0.95
                    print(COMNAMs)
                    print(highest_likelyhood[2])
                    print(collect(ReutersallIds[trunc(Int,highest_likelyhood[1])][2])[1])
                    mappingDict[PERMNO] = collect(ReutersallIds[trunc(Int,highest_likelyhood[1])][8])[1]
               end
          end
     elseif highest_likelyhood[2]>0.975
          # print("Yay!")
          print(COMNAMs)
          print(highest_likelyhood[2])
          print(collect(ReutersallIds[trunc(Int,highest_likelyhood[1])][2])[1])
          mappingDict[PERMNO] = collect(ReutersallIds[trunc(Int,highest_likelyhood[1])][8])[1]
     end
     if c%100==0
          print(c)
     end
end #for comp
toc()

# Comp_curs = find(companiesConnect, Dict("marketMIC"=>Dict("\$in" => ["XNGS", "XNYS", "XNAS", "NASX", "XNIM", "XASE"])))

@save "$rootpath/permnoToPermId.jld2" mappingDict
