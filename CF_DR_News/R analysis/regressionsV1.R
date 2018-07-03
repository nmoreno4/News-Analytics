require(stargazer)
require(broom)
df <- read.csv("/home/nicolas/Data/monthlyMatrix.csv", header = TRUE, sep=";")
CFDR_df <- read.csv("/home/nicolas/Data/news_CF_DR.csv", header = TRUE, sep=";")


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

df[,"NBER"] = rep(1, 168)
df[,"NBER"][c(69:74)] = 0

df <- cbind(df, CFDR_df)
plot(df[,"CF_VW_HML_H"])

df <- cbind(df,CFDR_df)
df <- df[-c(157:168), ]
# df <- df[-c(69:76), ]


df[,"CF_VW_HML_spread"] = df[,"CF_VW_HML_H"]-df[,"CF_VW_HML_L"]
df[,"DR_VW_HML_spread"] = df[,"DR_VW_HML_H"]-df[,"DR_VW_HML_L"]


simplereg = lm(VW_diffPosNegRel_HML_spread ~ CF_VW_HML_spread+DR_VW_HML_spread, data = df)
summary(simplereg)
simplereg = lm(VW_diffPosNegRel_HML_L ~ CF_VW_HML_L+DR_VW_HML_L, data = df)
summary(simplereg)
simplereg = lm(VW_diffPosNegRel_HML_H ~ CF_VW_HML_H:NBER+DR_VW_HML_H:NBER, data = df)
summary(simplereg)
simplereg = lm(VW_diffPosNegRel_HML_H ~ CF_VW_HML_H+DR_VW_HML_H, data = df)
summary(simplereg)

#variance information factor