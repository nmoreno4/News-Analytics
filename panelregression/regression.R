library("plm")
data <- read.csv(file="/home/nicolas/Data/Intermediate/paneldf3.csv", header=TRUE)

data$random = runif(13991485)*2-1
model <- plm(retadj ~ sent*isgrowth*EAD + sent*isvalue*EAD, data = data, model = "within")
summary(model)
