require(stargazer)
require(broom)
tFrequence = "1 month"
excludeDays = "0 days"
pastRollWindow = "0 years"
decayParam = "1"
nFilter = "(true, 2)_true"
pType = "ptf_2by3_size_value"
pNb = "_"
df_S1 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
pType = "all"
pNb = "_"
df_S2 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
FF <- read.csv(paste("/home/nicolas/Data/FF/FF_Factors.CSV", sep=""), header = TRUE, sep=",")
df <- cbind(df_S1, df_S2, FF[475:648, 2:50]/100)

df["EW_ret_LowBM"] <- apply(cbind(df_S1[,2], df_S1[,16]), 1, mean)
df["VW_ret_LowBM"] <- apply(cbind(df_S1[,3], df_S1[,17]), 1, mean)
df["EW_vol_LowBM"] <- apply(cbind(df_S1[,4], df_S1[,18]), 1, mean)
df["VW_vol_LowBM"] <- apply(cbind(df_S1[,5], df_S1[,19]), 1, mean)
df["EW_sentClas_LowBM"] <- apply(cbind(df_S1[,6], df_S1[,20]), 1, mean)
df["VW_sentClas_LowBM"] <- apply(cbind(df_S1[,7], df_S1[,21]), 1, mean)
df["EW_sentClasRel_LowBM"] <- apply(cbind(df_S1[,8], df_S1[,22]), 1, mean)
df["VW_sentClasRel_LowBM"] <- apply(cbind(df_S1[,9], df_S1[,23]), 1, mean)
df["EW_diffPosNeg_LowBM"] <- apply(cbind(df_S1[,10], df_S1[,24]), 1, mean)
df["VW_diffPosNeg_LowBM"] <- apply(cbind(df_S1[,11], df_S1[,25]), 1, mean)
df["EW_diffPosNegrel_LowBM"] <- apply(cbind(df_S1[,12], df_S1[,26]), 1, mean)
df["VW_diffPosNegrel_LowBM"] <- apply(cbind(df_S1[,13], df_S1[,27]), 1, mean)
df["EW_novelty_LowBM"] <- apply(cbind(df_S1[,14], df_S1[,28]), 1, mean)
df["VW_novelty_LowBM"] <- apply(cbind(df_S1[,15], df_S1[,29]), 1, mean)
df["EW_ret_HiBM"] <- apply(cbind(df_S1[,30], df_S1[,44]), 1, mean)
df["VW_ret_HiBM"] <- apply(cbind(df_S1[,31], df_S1[,45]), 1, mean)
df["EW_vol_HiBM"] <- apply(cbind(df_S1[,32], df_S1[,46]), 1, mean)
df["VW_vol_HiBM"] <- apply(cbind(df_S1[,33], df_S1[,47]), 1, mean)
df["EW_sentClas_HiBM"] <- apply(cbind(df_S1[,34], df_S1[,48]), 1, mean)
df["VW_sentClas_HiBM"] <- apply(cbind(df_S1[,35], df_S1[,49]), 1, mean)
df["EW_sentClasRel_HiBM"] <- apply(cbind(df_S1[,36], df_S1[,50]), 1, mean)
df["VW_sentClasRel_HiBM"] <- apply(cbind(df_S1[,37], df_S1[,51]), 1, mean)
df["EW_diffPosNeg_HiBM"] <- apply(cbind(df_S1[,38], df_S1[,52]), 1, mean)
df["VW_diffPosNeg_HiBM"] <- apply(cbind(df_S1[,39], df_S1[,53]), 1, mean)
df["EW_diffPosNegrel_HiBM"] <- apply(cbind(df_S1[,40], df_S1[,54]), 1, mean)
df["VW_diffPosNegrel_HiBM"] <- apply(cbind(df_S1[,41], df_S1[,55]), 1, mean)
df["EW_novelty_HiBM"] <- apply(cbind(df_S1[,42], df_S1[,56]), 1, mean)
df["VW_novelty_HiBM"] <- apply(cbind(df_S1[,43], df_S1[,57]), 1, mean)
df["VW_ret_HML"] <- df["VW_ret_HiBM"]-df["VW_ret_LowBM"]
df["VW_sentClasRel_HML"] <- df["VW_sentClasRel_HiBM"]-df["VW_sentClasRel_LowBM"]

df = df[1:162,]

spec = lm(df$VW_ret_HML_String.H..M..L. ~ df$VW_sentClasRel_HML_String.H..M..L.)
summary(spec)
spec = lm(df$VW_ret_HiBM ~ df$VW_sentClasRel_HML)
summary(spec)


df$VW_sentClasRel_LowBM