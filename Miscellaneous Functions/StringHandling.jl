module StringHandling

export concatStrings

"""
    concatStrings(X::Any... ; sep="")

### Description
Transform elements to string and concatenates them using *sep* as seperator
between them.

### Arguments
- `X::Any`: the variables to concatenate as Strings
- `sep::Any=""`: the string between concatenated elements
"""
function concatStrings(X... ; sep="")
    res = ""
    for x in X
        res = "$(res)$(x)$(sep)"
    end
    return res
end

end #module
