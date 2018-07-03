require(stargazer)
require(broom)
df <- read.csv("/home/nicolas/Data/monthlyMatrix.csv", header = TRUE, sep=";")

factor ="HML"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]

factor ="Ranks_beme"
quintile = c("10", "1")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]

factor ="Ranks_momentum"
quintile = c("10", "1")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]

factor ="Inv"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]

factor ="OP_Prof"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]


factor = c("HML", "Ranks_momentum", "OP_Prof", "HML", "Inv")
quintile = c("spread", "All", "H", "L")
ctype = c("sentClas", "diffPosNeg", "sentClasRel", "diffPosNegRel")
# ctype = c("diffPosNeg", "sentClasRel", "diffPosNegRel", "sentClas")
# ctype = c("sentClasRel", "diffPosNegRel", "sentClas", "diffPosNeg")
# ctype = c("diffPosNegRel", "sentClasRel", "diffPosNegRel", "sentClas")


fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_", ctype[1], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
stargazer(reg)
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_", ctype[2], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_", ctype[3], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_", ctype[4], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_ret_", factor[2], "_", quintile[2], sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[1], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[1], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

##########################################

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[1], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[2], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[3], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[4], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " ~ VW_ret_", factor[2], "_", quintile[2], sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[3], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[3], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))


##########################################

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[1], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[2], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[3], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], " ~ VW_", ctype[4], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], " - VW_ret_", factor[2], "_", quintile[2], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " ~ VW_ret_", factor[2], "_", quintile[2], sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))

fo <- as.formula(paste("VW_ret_", factor[1], "_", quintile[4], " ~ VW_ret_", factor[2], "_", quintile[2], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[4], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_", ctype[2], "_", factor, "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
label = c(paste("VW_ret_", factor[1], "_", quintile[4], "", sep=""), "R2-multiple", summary(reg)$r.squared, "R2-adjusted", summary(reg)$adj.r.squared)
tidyfit <- rbind(tidyfit, label, tidy(reg), c("","","","",""))


write.csv(tidyfit, paste(factor[1], "_regressions_", ctype[1], ".csv", sep=""))
          