# Threads.nthreads()
# res = Dict()
# @time Threads.@threads for i = 1:100000
#    res[i] = Threads.threadid()
# end
#
# using R
# function par_by(df::AbstractDataFrame,f::Function,cols::Symbol...;block_size=40)
#     #f needs to be precompiled - we precompile using the first row of the DataFrame.
#     #If try to do it within @thread macro
#     #Julia will crash in most ugly and unexpected ways
#     #if you comment out this line you can observe a different crash with every run
#     by(view(df,1:1),[cols...],f);
#
#     nr = nrow(df)
#     local dfs = DataFrame()
#     blocks = Int(ceil(nr/block_size))
#     s = Threads.SpinLock()
#     Threads.@threads for block in 1:blocks
#         startix = (block-1)*block_size+1
#         endix = min(block*block_size,nr)
#         rv= by(view(df,startix:endix), [cols...], f)
#         Threads.lock(s)
#         if nrow(dfs) == 0
#             dfs = rv
#         else
#             append!(dfs,rv)
#         end
#         Threads.unlock(s)
#     end
#     dfs
# end
#
#
#
#
#
#
# using Distributed
# rmprocs(2)
# addprocs(2)
#
# A = rand(1000,1000);
# Bref = @spawn A^2
# fetch(Bref)
#
# @everywhere function count_heads(n)
#     c::Int = 0
#     for i = 1:n
#         c += rand(Bool)
#     end
#     c
# end
#
# a = @spawn count_heads(100000000)
# b = @spawn count_heads(100000000)
# fetch(a)+fetch(b)
#
# a = zeros(100000)
# @distributed for i = 1:100000
#     a[i] = i
# end
# fetch(a)
#
#
#
# @everywhere using SharedArrays
# struct Foo
#    a::Int
#    b::Float64
# end
# a = SharedArray{StaticArray}(10)
# @distributed for i = 1:10
#     a[i] = Dict(i=>1)
# end
#
#
# using Distributed
# addprocs(3)
# workers()
# @spawn data
#
# @time foo = filteredSeriesCompute(data, 1);
#
# function filteredSeriesCompute(data, thresh, focusonNewsdaysonly = false, anomaly = :provptf)
#     data = data[isnotmissing.(data[anomaly]), :]
#     res = Dict()
#     byptf = by(data, [anomaly, :perid]) do v
#         if focusonNewsdaysonly
#             v = v[isnotmissing.(v[:sum_perNbStories_]),:]
#             vwithoutnews = v[ismissing.(v[:sum_perNbStories_]),:]
#         end
#         res[:VWret_v] = VWeight(v, :cumret)
#         res[:VWsent_v] = VWeight(v, :aggSent_)
#         res[:EWret_v] = EWeight(v, :cumret)
#         res[:EWsent_v] = EWeight(v, :aggSent_)
#         res[:coverage_v] = sum(v[:sum_perNbStories_])
#         res[:rawnewsstrength_v] = custom_sum(v[:rawnewsstrength])
#         res[:VWnewsstrength_v] = VWeight(v, :rawnewsstrength)
#         res[:EWnewsstrength_v] = EWeight(v, :rawnewsstrength)
#         DataFrame(res)
#     end
#     return byptf
# end
#
#
# for thresh in 1:nbBuckets
#     @time byday = by(data, :perid) do df
#         df = df[isnotmissing.(df[anomaly]), :]
#         res = Dict()
#
#         v = df[df[anomaly].==thresh,:]
#
#         print(VWeight(df, :cumret))
#         error()
#
#         if focusonNewsdaysonly
#             v = v[isnotmissing.(v[:sum_perNbStories_]),:]
#             vwithoutnews = v[ismissing.(v[:sum_perNbStories_]),:]
#         end
#         res[:VWret_v] = VWeight(v, :cumret)
#         res[:VWsent_v] = VWeight(v, :aggSent_)
#         res[:EWret_v] = EWeight(v, :cumret)
#         res[:EWsent_v] = EWeight(v, :aggSent_)
#         res[:coverage_v] = sum(v[:sum_perNbStories_])
#         res[:rawnewsstrength_v] = custom_sum(v[:rawnewsstrength])
#         res[:VWnewsstrength_v] = VWeight(v, :rawnewsstrength)
#         res[:EWnewsstrength_v] = EWeight(v, :rawnewsstrength)
#
#         lom = df[df[anomaly].!=thresh,:]
#
#         if focusonNewsdaysonly
#             lom = vcat(lom, vwithoutnews)
#         end
#
#         res[:VWret_lom] = VWeight(lom, :cumret)
#         res[:VWsent_lom] = VWeight(lom, :aggSent_)
#         res[:EWret_lom] = EWeight(lom, :cumret)
#         res[:EWsent_lom] = EWeight(lom, :aggSent_)
#         res[:coverage_lom] = custom_sum(lom[:sum_perNbStories_])
#         res[:rawnewsstrength_lom] = custom_sum(lom[:rawnewsstrength])
#         res[:VWnewsstrength_lom] = VWeight(lom, :rawnewsstrength)
#         res[:EWnewsstrength_lom] = EWeight(lom, :rawnewsstrength)
#         DataFrame(res)
#     end
#     allptfs[thresh] = byday
# end
#


using Distributed
addprocs(4)
@everywhere function compute_pi(N::Int)
    """
    Compute pi with a Monte Carlo simulation of N darts thrown in [-1,1]^2
    Returns estimate of pi
    """
    n_landed_in_circle = 0  # counts number of points that have radial coordinate < 1, i.e. in circle
    for i = 1:N
        x = rand() * 2 - 1  # uniformly distributed number on x-axis
        y = rand() * 2 - 1  # uniformly distributed number on y-axis

        r2 = x*x + y*y  # radius squared, in radial coordinates
        if r2 < 1.0
            n_landed_in_circle += 1
        end
    end

    return n_landed_in_circle / N * 4.0
end

# for i in 1:10
#     print("\n \n start over \n \n")
#     @time compute_pi(1000000000)
#     @time job = @spawn compute_pi(1000000000)
#     @time fetch(job)
# end
for i in 1:5
    @time compute_pi(1000000000)
    results = @time pmap(compute_pi,[250000000,250000000,250000000,250000000])
end
