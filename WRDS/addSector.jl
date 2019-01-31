using WRDSdownload, DataFrames, Mongoc, Dates, JSON
################################
#  Earnings Announcemnt Dates  #
################################
realstartdate = Dates.Date(2003,1,1)
indusDF = GICdownload()
# Delete observations without industry classification after "realstartdate"
indusDF[:indthru] = replace(indusDF[:indthru], missing=>now())
indusDF[:indfrom] = DateTime.(indusDF[:indfrom])
indusDF = indusDF[indusDF[:indthru].>=realstartdate,:]
# ccm = linktabledownload()
# ccm[:linkenddt] = replace(ccm[:linkenddt], missing=>Dates.Date(now()))
# indusDFPermno=join(indusDF,ccm,kind=:left,on=[:gvkey])
# rowstokeep = Int[]
# for row in 1:size(indusDFPermno, 1)
#
#     if !ismissing(indusDFPermno[row, :indfrom]) && !ismissing(indusDFPermno[row, :linkenddt]) && (indusDFPermno[row, :indfrom] < indusDFPermno[row, :linkdt] ||  indusDFPermno[row, :indthru] > indusDFPermno[row, :linkenddt])
#         nothing
#     else
#         push!(rowstokeep, row)
#     end
# end
# indusDFPermno = indusDFPermno[rowstokeep, :]
# indusDFPermno = indusDFPermno[.!ismissing.(indusDFPermno[:permno]),:]


indusDF[:gvkey] = parse.(Int, indusDF[:gvkey])
client = Mongoc.Client()
database = client["Jan2019"]
collection = database["PermnoDay"]
for row in 1:size(indusDF,1)
    # Show advancement
    if row in 2:1000:size(indusDF,1)
        print("Advnacement : ~$(round(100*row/size(indusDF,1)))% \n")
    end

    setDict = Dict("gsector"=>indusDF[row,:gsector], "gsubind"=>indusDF[row,:gsubind], "indtype"=>indusDF[row,:indtype])
    selectDict = [Dict( "date"=>Dict("\$gte"=>indusDF[row,:indfrom], "\$lte"=>indusDF[row,:indthru]),
                        "gvkey"=>indusDF[row,:gvkey] )]
    crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
    crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
    Mongoc.update_many(collection, crtselector, crtupdate)
end
