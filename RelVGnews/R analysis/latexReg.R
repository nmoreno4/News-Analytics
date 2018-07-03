require(stargazer)
require(broom)
df <- read.csv("/home/nicolas/Data/monthlyMatrixBIS.csv", header = TRUE, sep=";")
FF <- read.csv("/home/nicolas/CodeGood/Data Inputs/FF/FF_Factors.CSV", header = TRUE, sep=",")
FF <- FF[-c(1:480, 649:655), ]/100
FF[,1] <- FF[,1]*100
df <- cbind(df,FF)

factor ="HML"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_ret_", factor, "_spread", sep="")] = df[,paste("NVW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClas_", factor, "_spread", sep="")] = df[,paste("NVW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("NVW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_novelty_", factor, "_spread", sep="")] = df[,paste("NVW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_novelty_", factor, "_", quintile[2], sep="")]

factor ="SMB"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_ret_", factor, "_spread", sep="")] = df[,paste("NVW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClas_", factor, "_spread", sep="")] = df[,paste("NVW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("NVW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_novelty_", factor, "_spread", sep="")] = df[,paste("NVW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_novelty_", factor, "_", quintile[2], sep="")]


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
df[,paste("NVW_ret_", factor, "_spread", sep="")] = df[,paste("NVW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClas_", factor, "_spread", sep="")] = df[,paste("NVW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("NVW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_novelty_", factor, "_spread", sep="")] = df[,paste("NVW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_novelty_", factor, "_", quintile[2], sep="")]

factor ="Inv"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_ret_", factor, "_spread", sep="")] = df[,paste("NVW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClas_", factor, "_spread", sep="")] = df[,paste("NVW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("NVW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_novelty_", factor, "_spread", sep="")] = df[,paste("NVW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_novelty_", factor, "_", quintile[2], sep="")]

factor ="OP_Prof"
quintile = c("H", "L")
df[,paste("VW_ret_", factor, "_spread", sep="")] = df[,paste("VW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("VW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClas_", factor, "_spread", sep="")] = df[,paste("VW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("VW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("VW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("VW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("VW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("VW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("VW_novelty_", factor, "_spread", sep="")] = df[,paste("VW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("VW_novelty_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_ret_", factor, "_spread", sep="")] = df[,paste("NVW_ret_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_ret_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClas_", factor, "_spread", sep="")] = df[,paste("NVW_sentClas_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClas_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_sentClasRel_", factor, "_spread", sep="")] = df[,paste("NVW_sentClasRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_sentClasRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNeg_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNeg_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNeg_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_diffPosNegRel_", factor, "_spread", sep="")] = df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_diffPosNegRel_", factor, "_", quintile[2], sep="")]
df[,paste("NVW_novelty_", factor, "_spread", sep="")] = df[,paste("NVW_novelty_", factor, "_", quintile[1], sep="")] - df[,paste("NVW_novelty_", factor, "_", quintile[2], sep="")]



wtype = c("VW", "NVW", "EW")
factor = c("HML", "Ranks_momentum", "OP_Prof", "String.H..M..L.", "Inv", "SMB")
quintile = c("spread", "All", "H", "L", "String.H..M..L.")
ctype = c("sentClas", "diffPosNeg", "sentClasRel", "diffPosNegRel")
# ctype = c("diffPosNeg", "sentClasRel", "diffPosNegRel", "sentClas")
# ctype = c("sentClasRel", "diffPosNegRel", "sentClas", "diffPosNeg")
# ctype = c("diffPosNegRel", "sentClasRel", "diffPosNegRel", "sentClas")

fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], "", sep=""))
reg1 = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ VW_ret_", factor[1], "_", quintile[5], " + VW_ret_", factor[6], "_", quintile[1], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_ret_", factor[2], "_", quintile[1], sep=""))
reg2 = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[5], " ~ VW_ret_", factor[1], "_", quintile[1], " + VW_ret_", factor[6], "_", quintile[1], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_ret_", factor[2], "_", quintile[1], sep=""))
reg2bis = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ Mkt.RF + SMB + RMW + CMA + Mom", sep=""))
reg2ter = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], " + VW_ret_", factor[1], "_", quintile[5], " + VW_ret_", factor[6], "_", quintile[1], " + VW_ret_", factor[3], "_", quintile[1], " + VW_ret_", factor[5], "_", quintile[1], " + VW_ret_", factor[2], "_", quintile[1], sep=""))
reg3 = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], " + VW_ret_", factor[1], "_", quintile[5], " + SMB + CMA + RMW ", sep=""))
reg3bis = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[1], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], " + Mkt.RF + SMB + CMA + RMW +Mom ", sep=""))
reg3ter = do.call("lm", list(fo, quote(df)))
summary(reg2ter)

fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[3], " ~ Mkt.RF + SMB + RMW + CMA + Mom", sep=""))
reg4 = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[3], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], " + Mkt.RF + SMB + RMW + CMA + Mom", sep=""))
reg5 = do.call("lm", list(fo, quote(df)))
summary(reg5)
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[4], " ~ Mkt.RF + SMB + RMW + CMA + Mom", sep=""))
reg6 = do.call("lm", list(fo, quote(df)))
fo <- as.formula(paste(wtype[1], "_ret_", factor[1], "_", quintile[4], " ~ ", wtype[1], "_", ctype[3], "_", factor[1], "_", quintile[1], " + Mkt.RF + SMB + RMW + CMA + Mom", sep=""))
reg7 = do.call("lm", list(fo, quote(df)))
summary(reg6)


fo <- as.formula(paste("HML ~ VW_", ctype[1], "_", factor[1], "_", quintile[1], "", sep=""))
reg = do.call("lm", list(fo, quote(df)))
summary(reg)

stargazer(reg1, reg2ter, reg3ter)
stargazer(reg4, reg5, reg6, reg7)


###################Correlation Regressions###########################################
r_corr = c()
windowSize = 24
for (i in 1:(168-windowSize)){
  r_corr = c(r_corr, cor(FF$Lo10_BEME[i:(i+windowSize)]-FF$Mkt.RF[i:(i+windowSize)], FF$Hi10_BEME[i:(i+windowSize)]-FF$Mkt.RF[i:(i+windowSize)]))
}
r_corr = c()
for (i in 1:(168-windowSize)){
  r_corr = c(r_corr, cor(FF$Lo10_BEME[i:(i+windowSize)], FF$Hi10_BEME[i:(i+windowSize)]))
}
plot(r_corr, type="l")
#df$VW_sentClasRel_HML_spread
reg1 <- lm(r_corr ~ VW_sentClasRel_HML_spread[(1+windowSize):168], data = df)
reg2 <- lm(r_corr ~ VW_sentClasRel_HML_spread[1:(168-windowSize)], data = df)
reg3 <- lm(r_corr ~ VW_sentClasRel_HML_H[1:(168-windowSize)]+VW_sentClasRel_HML_L[1:(168-windowSize)], data = df)
reg4 <- lm(r_corr ~ rollmean(VW_sentClasRel_HML_H, windowSize)[1:(168-windowSize)]+rollmean(VW_sentClasRel_HML_L, windowSize)[1:(168-windowSize)], data = df)
reg5 <- lm(r_corr ~ rollmean(VW_sentClasRel_HML_spread, windowSize)[1:(168-windowSize)], data = df)
reg6 <- lm(r_corr ~ rollmean(VW_sentClasRel_HML_spread, windowSize)[2:(168-windowSize+1)], data = df)
plot(rollmean(r_corr, windowSize), type="l")
lines(rollmean(df$VW_sentClasRel_HML_spread, windowSize+1), col=2)
summary(reg1)
stargazer(reg2, reg3, reg4, reg5)
####################################################################################
df$VW_sentClasRel_HML_String.H..M..L.
reg <- lm(VW_ret_HML_String.H..M..L. ~ VW_sentClasRel_HML_String.H..M..L., data = df)
summary(reg)
