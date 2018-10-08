
writecsv("/home/nicolas/Data/gvkeys.csv", collect(Set(ccm1[:gvkey])))

open("/home/nicolas/Data/identifierdata.csv", "r") do file
    i = 0
    gvkey = 0
    for ln in eachline(file)
        i+=1
        println("$(ln[])")
        if i > 10
            break
        end
    end
end

foo = CSV.read("/home/nicolas/Data/identifierdata.csv", rows_for_type_detect=1000)
gvkey = 0
res = []
for ln in eachrow(foo)
    if ln[:gvkey] != gvkey
        gvkey = ln[:gvkey]
        push!(res, [ln[:gvkey], "ticker:$(ln[:tic])", ln[:conml], ln[:city], ln[:state], ln[:weburl]])
    end
end

writecsv("/home/nicolas/Data/identifierReutersgvkey.csv",res)
