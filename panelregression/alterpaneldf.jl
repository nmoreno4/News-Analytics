module alterpaneldf

export lagvariables

function lagvariables(subdf)
    nblags = []
    for row in eachrow(subdf)
        for col in row
            if String(col[1])[1:2]=="la"
                push!(nblags, (col[2], col[1][5:end]))
            end
        end
        break
    end
    for vlag in nblags
        lag = vlag[1]
        var = vlag[2]
        lagvec = subdf[Symbol("lag($lag)$(var)")][1:end-lag]
        lagvec = vcat(missings(Float64, lag), lagvec)
        subdf[Symbol("lag($lag)$(var)")] = lagvec
    end
end

end # module
