##########################################################################################
# Description...
##########################################################################################
using JSON, JLD2, Dates, ReadReuters, Statistics, StatsBase, Buckets, DBstats, Mongoc, ArgParse


# Add possibility to add relevance , volume and novelty alone!!!
s = ArgParseSettings()
@add_arg_table s begin
    "--y"
        help = "Serves for both yend and ystart"
        arg_type = Int
    "--f"
        help = "Is it permidTdDic or permidTdDic2?"
        arg_type = Int
    "--ioa"
        help = "Boolean. Should only analytics be inserted?"
        arg_type = Bool
        default = false
end
parsed_args = parse_args(ARGS, s)
############## Params ##############
offsetNewsDay = Dates.Minute(15)
datef = DateFormat("y-m-dTH:M:S.sZ");
recomputeUniqueTDs = false
ystart, yend = parsed_args["y"],parsed_args["y"]
insertOnlyAna = parsed_args["ioa"]
####################################
using Mongoc
client = Mongoc.Client()
database = client["Jan2019"]
collection = database["PermnoDay"]
####################################

function deleteMissingKeys!(myDic)
    keystodrop = []
    for i in keys(myDic)
        if ismissing(myDic[i])
            push!(keystodrop, i)
        end
    end
    for crtkey in keystodrop
        delete!(myDic, crtkey)
    end
    return myDic
end


mtopics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "JOB", "LAYOFS", "LIST1", "MCE",
          "MEET1", "MNGISS", "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "PRXF",
          "PS1", "RCH", "RECAP1", "RECLL", "REGS", "REORG", "SHPP", "SHRACT",
          "SISU", "SL1", "SPLITB", "STAT", "STK", "XPAND"]
# Compute sentiment aggregates, filtering by topic, novelty and relevance
for i in parsed_args["f"]
    print("This is Dict # $i \n")
    row = [0]
    if i==1
        print("effectively number 1 \n")
        GC.gc()
        try
            filetoload = "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic.jld2"
            @time JLD2.@load filetoload permidTdDic
        catch
            using JLD
            @time permidTdDic = load("/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic.jld", "permidTdDic")
        end
        print("size permidTdDic 4: $(length(permidTdDic))\n")
    elseif i==2
        print("effectively number 2 \n")
        permidTdDic = nothing
        GC.gc()
        try
            filetoload = "/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic2.jld2"
            @time JLD2.@load filetoload permidTdDic2
            permidTdDic = permidTdDic2
        catch
            print("\n Failed to ol' JLD\n")
            using JLD
            @time permidTdDic2 = load("/home/nicolas/Data/ProvDBconstr/$(yend)permidTdDic2.jld", "permidTdDic2")
            permidTdDic = permidTdDic2
        end
    end
    @time for (permid, permidDic) in permidTdDic
        row[1]+=1
        if row[1] in 1:40:length(permidTdDic)
            print("Advnacement : ~$(round(100*row[1]/length(permidTdDic)))% \n")
            print(Dates.now())
        end
        for (td, tdDic) in permidTdDic[permid]
            permnoday = permidTdDic[permid][td]["stories"]

            ############## only new news #######################
            rthresh = 90
            novthresh = 0

            restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true), ("N2:RES", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RCH", true), ("N2:RES", true), ("N2:RESF", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]


            ############## no rel thresh #######################
            rthresh = 0

            restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true), ("N2:RES", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RCH", true), ("N2:RES", true), ("N2:RESF", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            ############### no rel thresh  but multiply by relevance #######################
            rthresh = "smooth"

            restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true), ("N2:RES", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RCH", true), ("N2:RES", true), ("N2:RESF", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            ############### only new news #######################
            rthresh = 100
            novthresh = 0

            restruenov = computeTopicScores(permnoday; novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", false), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_excl_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:MRG", true), ("N2:DEAL1", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_MRG_DEAL1_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RES", true), ("N2:RESF", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RES_inc_RESF_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RESF", true), ("N2:RES", false); novFilter=("nov24H",novthresh), relthresh = rthresh)
            permidTdDic[permid][td]["nS_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RESF_inc_RES_excl_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            restruenov = computeTopicScores(permnoday, ("N2:RCH", true), ("N2:RES", true), ("N2:RESF", true); novFilter=("nov24H",novthresh), abjoin=|, relthresh = rthresh)
            permidTdDic[permid][td]["nS_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
            permidTdDic[permid][td]["posSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
            permidTdDic[permid][td]["negSum_RCH_RES_RESF_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]

            for top in mtopics
                restruenov = computeTopicScores(permnoday, ("N2:$(top)", true); novFilter=("nov24H",novthresh), relthresh = rthresh)
                permidTdDic[permid][td]["nS_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[1]
                permidTdDic[permid][td]["posSum_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[2]
                permidTdDic[permid][td]["negSum_$(top)_inc_nov24H_$(novthresh)_rel$(rthresh)"] = restruenov[3]
            end


            if insertOnlyAna
                delete!(permidTdDic[permid][td], "stories")
            end
        end
    end
    GC.gc()
    print("Inserting dictionary")
    row = [0]
    @time for (permid, permidDict) in permidTdDic
        row[1]+=1
        if row[1] in 1:40:length(permidTdDic)
            print("Advnacement : ~$(round(100*row[1]/length(permidTdDic)))% \n")
        end
        for (td, setDict) in permidDict
            setDict = deleteMissingKeys!(setDict)
            selectDict = [Dict("permid"=>permid), Dict("td"=>td)]
            # Update all matching in MongoDB
            crtselector = Mongoc.BSON(Dict("\$and" => selectDict))
            crtupdate = Mongoc.BSON(Dict("\$set"=>setDict))
            try
                Mongoc.update_many(collection, crtselector, crtupdate)
            catch x
                print("$(crtselector) \n")
                print(crtupdate)
                error(x)
            end
        end
    end
end
