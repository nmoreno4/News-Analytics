using PyCall, Statistics

# Connect to the database
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:DenadaDB]
collection = db[:daily_CRSP_CS_TRNA]

foo = @time sizeValRetSent(3, (1,3), (6,10))

function sizeValRetSent(td, valR, sizeR)
    dayretvec = Float64[]
    daywtvec = Union{Float64, Missing}[]
    dayspreadvec = Union{Float64, Missing}[]
    for filtDic in collection[:find](Dict("td"=>td, "rankbm"=>Dict("\$gte"=>valR[1], "\$lte"=>valR[2]),
                                            "ranksize"=>Dict("\$gte"=>sizeR[1], "\$lte"=>sizeR[2])))
        push!(dayretvec, filtDic["dailyretadj"])
        if typeof(filtDic["wt"])==Float64
            push!(daywtvec, filtDic["wt"])
        else
            push!(daywtvec, missing)
        end
        if haskey(filtDic, "spread_rel50nov3D_m")
            push!(dayspreadvec, filtDic["spread_rel50nov3D_m"])
        else
            push!(dayspreadvec, missing)
        end
    end
    VWret = sum(skipmissing(dayretvec.*daywtvec))/sum(skipmissing(daywtvec))
    EWret = mean(dayretvec)
    EWsent = mean(skipmissing(dayspreadvec))
    VWsent = sum(skipmissing(dayspreadvec.*daywtvec))/sum(skipmissing(daywtvec))
    return (VWret, EWret, EWsent, VWsent)
end
