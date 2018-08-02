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

end


function test(x, y)
    print()
    if y == 2
        return x*2
    else
        return x-1
    end
end

map(test, [1,2,1,2], [2,2,2,2])

a = df[1:5,:]
a[:sent][[1,3]] = missing
DataFrame(skipmissing(a))
val = 2
a[Symbol("hey$(val)")] = val

by(a, :permno, customrow)

meltdf(gd)
b=map(customrow, gd, ones(length(gd))*2)
join(b[1], b[2], :permno, :outer)

function customrow(subdf)
    for row in eachrow(subdf)
        row[Symbol("hey$(Int(val))")] = row[:retadj]*val
    end
    return subdf
end

for row in eachrow(a)
    for col in row
        if String(col[1])[1:2]=="he"
            print(col[2])
        end
    end
end

d1 = DataFrame(a = repeat([1:3;], inner = [4]),
               b = repeat([1:4;], inner = [3]),
               c = randn(12),
               d = randn(12),
               e = map(string, 'a':'l'))
d1s = stack(d1, [:c, :d])

foo = a[1,:]
for i in foo

    print(i)
end
