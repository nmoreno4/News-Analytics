using JLD2, CSV, DataFrames, Dates

laptop = "/home/nicolas/github/News-Analytics"
include("$(laptop)/News Risk premium/GAoptim/GAhelp.jl")

@time JLD2.@load "/run/media/nicolas/Research/SummaryStats/agg/sectorsimple_allobs_Dates.day_(1, 3776).jld2"
data = aggDicFreq[1][[:permno, :perid, :sum_perSent_RES, :sum_perNbStories_RES, :cumret, :wt, :sizedecile]]
names!(data, [:permno, :perid, :sum_perSent_, :sum_perNbStories_, :cumret, :wt, :sizedecile])

@time JLD2.@save "/run/media/nicolas/Research/GAdataRES.jld2" data
