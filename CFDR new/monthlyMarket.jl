using MongoDF, Dates, DataFrames

retvalues = ["date", "permno", "retadj", "me",
             "nS_nov24H_0_rel100", "posSum_nov24H_0_rel100", "negSum_nov24H_0_rel100",
             "nS_RES_inc_RESF_excl_nov24H_0_rel100", "posSum_RES_inc_RESF_excl_nov24H_0_rel100", "negSum_RES_inc_RESF_excl_nov24H_0_rel100",
             "nS_RES_excl_RESF_excl_nov24H_0_rel100", "posSum_RES_excl_RESF_excl_nov24H_0_rel100", "negSum_RES_excl_RESF_excl_nov24H_0_rel100",
             "nS_RESF_inc_nov24H_0_rel100", "posSum_RESF_inc_nov24H_0_rel100", "negSum_RESF_inc_nov24H_0_rel100",
             "nS_BACT_inc_nov24H_0_rel100", "posSum_BACT_inc_nov24H_0_rel100", "negSum_BACT_inc_nov24H_0_rel100",
             "nS_CMPNY_inc_nov24H_0_rel100", "posSum_CMPNY_inc_nov24H_0_rel100", "negSum_CMPNY_inc_nov24H_0_rel100"]
X = @time TRNAmongoDF(retvalues; monthrange = Month(3), startDate = DateTime(2002,12,31), endDate = DateTime(2017,12,31))
