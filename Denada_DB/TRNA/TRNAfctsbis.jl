using IterTools, Statistics

function tdFilter(tdnews, myvars, filters, topics, includeSubjects=false)
    dicvars = variablenames(myvars, novrelfilters, topics)
    tdDic =  Dict{String, Any}(zip(dicvars, [nothing for x in dicvars])) #Dic for the sum of all stories
    tdDic["storyID"] = String[]
    includeSubjects ? tdDic["subjects"] = Any[] : nothing
    for story in tdnews[2]
        storyDic =  Dict{String, Any}(zip(dicvars, [Float64[] for x in dicvars])) #The dic for the current story
        dicIdx = idxDic(filters, topics) #init empty idx filters
        dicIdx = filterIdx(dicIdx, story, filters, myvars) #fill idx filters
        for varString in storyDic
            idxToKeep = variableIntersect(varString[1], dicIdx)
            if varString[1][1:3]=="pos" && length(idxToKeep)>0
                push!(storyDic[varString[1]], mean(1*story[2]["pos"][idxToKeep]))
            elseif varString[1][1:3]=="neg" && length(idxToKeep)>0
                push!(storyDic[varString[1]], mean(-1*story[2]["neg"][idxToKeep]))
            elseif varString[1][1:4]=="sent" && length(idxToKeep)>0
                sentclass = story[2]["sentClas"][idxToKeep]
                takesents = Float64[]
                for cl in sentclass
                    cl==-1 ? append!(takesents, -1 .* story[2]["neg"][idxToKeep]) : nothing
                    cl==1 ? append!(takesents, 1 .* story[2]["pos"][idxToKeep]) : nothing
                end
                push!(storyDic[varString[1]], mean(takesents))
            elseif varString[1][1:9]=="nbStories" && length(idxToKeep)>0
                isa(storyDic[varString[1]], Array) ? storyDic[varString[1]]=0 : nothing
                storyDic[varString[1]]+=1
            end
        end #for all numerical variables

        includeSubjects ? push!(tdDic["subjects"],collect(Set(collect(Base.Iterators.Flatten(story[2]["subjects"]))))) : nothing
        push!(tdDic["storyID"],story[1])

        # Sum of the dzielinski measures for the day-stock
        for el in storyDic
            if length(el[2])>0
                tdDic[el[1]]==nothing ? tdDic[el[1]] = sum(el[2]) : tdDic[el[1]] += sum(el[2])
            end
        end #for all storie's values
    end #for each story in the td pair.
    return tdDic
end

function variablenames(variables, filters, topics)
    varnames = String[]
    for var in variables
        for filt in filters
            crtfilter = "_rel$(filt[1])_nov$(filt[2])"
            push!(varnames, "$(var)$(crtfilter)")
        end
    end
    copyvarnames = copy(varnames)
    for top in topics
        for var in copyvarnames
            push!(varnames, "$(var)_$(top)")
        end
    end
    return varnames
end


function idxDic(filters, topics)
    filtidxs = String[]
    for filt in filters
        push!(filtidxs, "rel$(filt[1])")
        push!(filtidxs, "nov$(filt[2])")
    end
    append!(filtidxs, topics)
    append!(filtidxs, ["pos", "neg"])
    idxs = Dict()
    for x = filtidxs
        idxs[x] = Int[]
    end
    return idxs
end


function filterIdx(dicIdx, story, filters, myvars)
    for i in 1:length(story[2]["relevance"])
        for el in dicIdx
            if el[1][1:3]=="rel"
                relthresh = parse(Int, el[1][4:end])
                if story[2]["relevance"][i]>relthresh/100
                    push!(dicIdx[el[1]], i)
                end
            elseif el[1][1:3]=="nov"
                novspan = el[1][4:end]
                if length(novspan)>1 && story[2]["Nov$(novspan)"][i]==0
                    push!(dicIdx[el[1]], i)
                else #no novelty filter
                    push!(dicIdx[el[1]], i)
                end
            elseif el[1][1:3]=="pos"
                if story[2]["sentClas"][i] == 1
                    push!(dicIdx[el[1]], i)
                end
            elseif el[1][1:3]=="neg"
                if story[2]["sentClas"][i] == -1
                    push!(dicIdx[el[1]], i)
                end
            else
                if !(el[1] in myvars) && "N2:$(el[1])" in story[2]["subjects"][i]
                    push!(dicIdx[el[1]], i)
                end
            end #for type of filt: pos, neg, nov, rel, topic
        end #for all filter variables
    end #for all takes
    return dicIdx
end #fun

function variableIntersect(mystr, dicIdx)
    filtlist = Array{Int64,1}[]
    for filt in split(mystr, "_")
        !(filt in ["sent", "nbStories"]) ? push!(filtlist, dicIdx[filt]) : nothing
    end
    return intersect(filtlist...)
end


function trading_day(dates, crtdate, offset = Dates.Hour(0))
  i=0
  res = 0
  for d in dates
    i+=1
    if dates[i]-offset < crtdate <= dates[i+1]-offset
      return i
      break
    end
  end
  return res
end


function tuplerize(X)
    X = Array{Any}(X)
    for i in 1:length(X)
        X[i] = tuple(X[i]...)
    end
    return X
end


function allToTuple!(tdstories, emptyarrays=true)
    for pair in tdstories
        if pair[2]==nothing
            tdstories[pair[1]] = pair[2]
        elseif length(pair[2])==0 && emptyarrays
            tdstories[pair[1]] = nothing
        elseif isa(pair[2], Array)
            if isa(pair[2][1], Array)
                tdstories[pair[1]] = tuplerize(pair[2])
                tdstories[pair[1]] = tuple(tdstories[pair[1]]...)
            else
                tdstories[pair[1]] = tuple(pair[2]...)
            end
        else
            tdstories[pair[1]] = pair[2]
        end
    end
    return tdstories
end
