using ImageFiltering

function rolling(fun::Function, data::AbstractVector{T}, windowspan::Int) where {T}
    nvals  = nrolled(length(data), windowspan)
    offset = windowspan - 1
    result = zeros(T, nvals)

    @inbounds for idx in eachindex(result)
        result[idx] = fun( view(data, idx:idx+offset) )
    end

    return result
end
function running(fun::Function, data::AbstractVector{T}, windowspan::Int) where {T}
    if length(data)<windowspan
        nbmissing = windowspan-length(data)
        toprepend = ones(nbmissing)*data[1]
        data = [toprepend;data]
    end
    ndata   = length(data)
    nvals   = nrolled(ndata, windowspan)
    ntapers = ndata - nvals

    result = zeros(T, ndata)

    result[1:ntapers] = tapers(fun, data[1:ntapers])
    ntapers += 1
    result[ntapers:ndata] = rolling(fun, data, windowspan)

    return result
end
function nrolled(seqlength::T, windowspan::T) where {T<:Signed}
    (0 < windowspan <= seqlength) || throw(SpanError(seqlength,windowspan))

    return seqlength - windowspan + 1
end
function tapers(fun::Function, data::AbstractVector{T}) where {T}
    nvals  = length(data)
    result = zeros(T, nvals)

    @inbounds for idx in nvals:-1:1
        result[idx] = fun( view(data, 1:idx) )
    end

    return result
end

running(lagcoll, a[:,2], 4)

function lagcoll(x)
    return x[1]
end

a = [[1 2 3 4 5 8 9 10];[0 0.05 -0.02 -0.03 0.01 0.018 0.06 -0.02]]'
