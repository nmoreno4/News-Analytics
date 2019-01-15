using WRDSdownload, FindFcts, DataFrames, Mongoc, Dates, JSON, TimeZones
################################
#  Earnings Announcemnt Dates  #
################################
realstartdate = Dates.Date(2003,1,1)
CSdaterange = ["01/01/1999", "12/31/2017"]
print("Compute EAD")
CSvariables = "gvkey, datadate, rdq" #addzip, city, conml, naicsh, state
CSdatatable = "comp.fundq"
EAdfq = WRDSdownload.CSdownload(CSdaterange, CSvariables, CSdatatable)
EAdfq[:EAD] = 1
unique!(EAdfq)
# EAdfq = EAdfq[[:gvkey, :rdq, :EAD]]
EAdfq = deleteMissingRows(EAdfq, :rdq)
ccm = linktabledownload()
# if linkenddt is missing then set to today date
ccm[:linkenddt] = replace(ccm[:linkenddt], missing=>Dates.Date(now()))
EAdfqPermno=join(EAdfq,ccm,kind=:left,on=[:gvkey])
rowstokeep = Int[]
for row in 1:size(EAdfqPermno, 1)
    if !ismissing(EAdfqPermno[row, :datadate]) && !ismissing(EAdfqPermno[row, :linkenddt]) && (EAdfqPermno[row, :datadate] < EAdfqPermno[row, :linkdt] ||  EAdfqPermno[row, :datadate] > EAdfqPermno[row, :linkenddt])
        nothing
    else
        push!(rowstokeep, row)
    end
end
EAdfqPermno = EAdfqPermno[rowstokeep, :]

# Check everything is all right
# by(EAdfqPermno, [:gvkey, :datadate]) do xdf
#     if size(xdf,1)>1
#         print(xdf)
#     end
# end

EADdf = EAdfqPermno[EAdfqPermno[:,:rdq].>=realstartdate,[:permno, :rdq, :EAD]]
EADdf = EADdf[.!ismissing.(EADdf[:permno]),:]

# Good market close dates
EADdf[:date] = convert(Array{DateTime}, EADdf[:rdq])
dates = [ZonedDateTime(d, tz"America/New_York") for d in EADdf[:date] .+ Dates.Hour(16)]
EADdf[:date] = [DateTime(astimezone(d, tz"UTC")) for d in dates]


# Add to MongoDB
client = Mongoc.Client()
database = client["Dec2018"]
collection = database["PermnoDay"]
varToUpdate = :EAD

for row in 1:size(EADdf,1)
    # Show advancement
    if row in 2:50000:size(EADdf,1)
        print("Advnacement : ~$(round(100*row/size(EADdf,1)))% \n")
    end

    setDict = Dict("$varToUpdate"=>EADdf[row,varToUpdate])
    selectDict = [Dict("date"=>EADdf[row,:date]), Dict("permno"=>EADdf[row,:permno])]
    crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
    crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
    Mongoc.update_many(collection, crtselector, crtupdate)
end
