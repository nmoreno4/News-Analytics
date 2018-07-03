require(stargazer)
require(broom)
require(dynlm)
tFrequence = "1 month"
excludeDays = "0 days"
pastRollWindow = "0 years"
decayParam = "1"
nFilter = "(true, 2)_true"
pType = "5by5"
pNb = "1"
df_S1 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
pNb = "2"
df_S2 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
pNb = "3"
df_S3 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
pNb = "4"
df_S4 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
pNb = "5"
df_S5 <- read.csv(paste("/home/nicolas/Data/News Analytics Series/",tFrequence, "/", excludeDays, "/", pastRollWindow, "/", decayParam, "/", nFilter, "/", pType, "_", pNb, ".csv", sep=""), header = TRUE, sep=";")
CF_betas <- read.csv("/home/nicolas/Data/CF DR News/CF_36m_5by5.csv", header = TRUE, sep=";")
DR_betas <- read.csv("/home/nicolas/Data/CF DR News/DR_36m_5by5.csv", header = TRUE, sep=";")
CFmCFi_betas <- read.csv("/home/nicolas/Data/CF DR News/CFmCFi.csv", header = TRUE, sep=",")
CFmDRi_betas <- read.csv("/home/nicolas/Data/CF DR News/CFmDRi.csv", header = TRUE, sep=";")
DRmCFi_betas <- read.csv("/home/nicolas/Data/CF DR News/DRmCFi.csv", header = TRUE, sep=";")
DRmDRi_betas <- read.csv("/home/nicolas/Data/CF DR News/DRmDRi.csv", header = TRUE, sep=";")
TmCFi_betas <- read.csv("/home/nicolas/Data/CF DR News/TmCFi.csv", header = TRUE, sep=",")
TmDRi_betas <- read.csv("/home/nicolas/Data/CF DR News/TmDRi.csv", header = TRUE, sep=",")
CF_news <- read.csv("/home/nicolas/Data/CF DR News/CF5x5.csv", header = TRUE, sep=",")
DR_news <- read.csv("/home/nicolas/Data/CF DR News/DR5x5.csv", header = TRUE, sep=",")
#df <- cbind(df_S1[1:162,], df_S2[1:162,], df_S3[1:162,], df_S4[1:162,], df_S5[1:162,], CF_betas, DR_betas)
df <- cbind(df_S1[1:162,], df_S2[1:162,], df_S3[1:162,], df_S4[1:162,], df_S5[1:162,], CF_news[354:515,], DR_news[354:515,], CFmCFi_betas[,2:26], CFmDRi_betas[,2:26], DRmCFi_betas[,2:26], DRmDRi_betas[,2:26], TmCFi_betas[,2:26], TmDRi_betas[,2:26])


specDR = lm(DR1 ~ EW_sentClasRel_ptf_5by5_size_value_1.1, data = df)
specCF = lm(CF1 ~ VW_sentClasRel_ptf_5by5_size_value_1.1, data = df)
summary(specDR)
summary(specCF)
specDR = lm(DR2 ~ VW_sentClasRel_ptf_5by5_size_value_1.2, data = df)
specCF = lm(CF2 ~ VW_sentClasRel_ptf_5by5_size_value_1.2, data = df)
summary(specDR)
summary(specCF)
specDR = lm(DR3 ~ VW_sentClasRel_ptf_5by5_size_value_1.3, data = df)
specCF = lm(CF3 ~ VW_sentClasRel_ptf_5by5_size_value_1.3, data = df)
summary(specDR)
summary(specCF)
specDR = lm(DR4 ~ VW_sentClasRel_ptf_5by5_size_value_1.4, data = df)
specCF = lm(CF4 ~ VW_sentClasRel_ptf_5by5_size_value_1.4, data = df)
summary(specDR)
summary(specCF)
specDR = lm(DR13 ~ VW_diffPosNegRel_ptf_5by5_size_value_1.5, data = df)
specCF = lm(CF13 ~ VW_diffPosNegRel_ptf_5by5_size_value_1.5, data = df)
summary(specDR)
summary(specCF)

ctype = "sentClas"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
DR_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("DR", i, " ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    DR_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    DR_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}

ctype = "sentClas"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("CF", i, " ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], " ~ CF", i, "+ DR", i, sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
    DR_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
    DR_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}


###################################################################
#Controlling for lagged betas
###################################################################


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("TmDRi_", i, "[2:162] ~ TmDRi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("TmCFi_", i, "[2:162] ~ TmCFi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("CFmDRi_", i, "[2:162] ~ CFmDRi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("CFmCFi_", i, "[2:162] ~ CFmCFi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("DRmDRi_", i, "[2:162] ~ DRmDRi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("DRmCFi_", i, "[2:162] ~ DRmCFi_", i, "[1:161] + EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[3,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[3,3]
  }
}



###################################################################
#Not controlling for lagged betas
###################################################################


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("TmDRi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("TmCFi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}


ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("CFmDRi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("CFmCFi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("DRmDRi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}

ctype = "sentClasRel"
pSpec = c("1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3", "4.4", "4.5", "5.1", "5.2", "5.3", "5.4", "5.5")
CF_coeff = matrix(nrow=5, ncol=5)
for (i in 1:25){
  fo <- as.formula(paste("DRmCFi_", i, "[2:162] ~ EW_", ctype, "_ptf_5by5_size_value_", pSpec[i], "[2:162]", sep=""))
  reg = do.call("lm", list(fo, quote(df)))
  if (i%%5 == 0){
    CF_coeff[ceiling(i/5),5] = summary(reg)$coef[2,3]
  } else {
    CF_coeff[ceiling(i/5),((i%%5))] = summary(reg)$coef[2,3]
  }
}

