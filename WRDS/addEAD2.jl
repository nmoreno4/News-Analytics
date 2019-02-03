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
EADdf = deleteMissingRows(EAdfq, :rdq)
EADdf[:date] = convert(Array{DateTime}, EADdf[:rdq])
dates = [ZonedDateTime(d, tz"America/New_York") for d in EADdf[:date] .+ Dates.Hour(16)]
EADdf[:date] = [DateTime(astimezone(d, tz"UTC")) for d in dates]
EADdf = EADdf[EADdf[:,:date].>=realstartdate,[:gvkey, :date, :EAD]]

EADdf[:gvkey] = parse.(Int, EADdf[:gvkey])
client = Mongoc.Client()
database = client["Jan2019"]
collection = database["PermnoDay"]
for row in 1:size(EADdf,1)
    # Show advancement
    if row in 2:10000:size(EADdf,1)
        print("Advnacement : ~$(round(100*row/size(EADdf,1)))% \n")
    end

    setDict = Dict("EAD"=>1)
    selectDict = [Dict( "date"=>EADdf[row,:date],
                        "gvkey"=>EADdf[row,:gvkey] )]
    crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
    crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
    Mongoc.update_many(collection, crtselector, crtupdate)
end
