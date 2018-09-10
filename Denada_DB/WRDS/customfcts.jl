function cumcount(X)
    res = Array{Int,1}(undef,length(X))
    for i = 1:length(X)
        res[i] = i-1
    end
    return res
end

function countmissing(X)
    return count(i->ismissing(i), X)
end

val2missing(v,mv) = mv >= v ? missing : v



function mergepermnopermco!(df)
    # Get sum and maximum for all permnos in a permco at a given date
    @time a = by(df, [:date, :permco]) do pdf
      DataFrame(sum_me = sum(pdf[:me]), max_me = maximum(pdf[:me]))
    end
    print(size(a,1))
    # prepare to drop permnos with lower me
    rename!(a, :max_me => :me)
    # drop permnos with lower me
    @time df = join(df, a, on = [:date, :permco, :me], kind = :inner)
    # drop this :me column which was just used to match the correct permnos
    delete!(df, [:me]); delete!(a, [:me]);
    # prepare to assign total me
    rename!(a, :sum_me => :me)
    #assign total me
    @time df = join(df, a, on = [:date, :permco], kind = :inner)
    return df
end


function groupcumret!(df, groupvar, myvar)
    a = by(df, groupvar) do pdf
      DataFrame(cumret = cumprod(pdf[myvar].+1))
    end
    df[Symbol("cum$(myvar)")] = a[:cumret]
    return df
end

function grouplag!(df, groupvar, myvar, nlags)
    a = by(df, groupvar) do pdf
      DataFrame(lag = lag(pdf[myvar], nlags))
    end
    df[Symbol("lag$(myvar)_$(nlags)")] = a[:lag]
    return df
end

function setfirstlme!(df, groupvar=:permno, myvar=:lagme_1)
    # First value of group is me/(1+retx)
    a = by(df, groupvar) do pdf
      DataFrame(firstlme = [pdf[:me][1]/(pdf[:retx][1]+1) ; pdf[myvar][2:end]])
    end
    df[myvar] = a[:firstlme]
    return df
end

function firstdiff(X)
    return [missing; X[2:end]-X[1:end-1]]
end


function changeColumnType!(df, columnSymbols, chosentype)
    for col in columnSymbols
        df[col] = Array{chosentype}(df[col])
    end
    return df
end


function lineupDate!(df, freq, newname, oldvar, endmonth=true)
    if endmonth
        adjust = Dates.Day(1)
    else
        adjust = Dates.Day(0)
    end
    df[newname] = map(x->ceil(x, freq)-adjust, df[oldvar])
    return df
end


function invertbool(x)
    if x
        return false
    else
        return true
    end
end
