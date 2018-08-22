library("plm")
library("stargazer")
data <- read.csv(file="/home/nicolas/Data/Intermediate/rawpanel5_extended.csv", header=TRUE)

df <- as.data.frame(lapply(df, unlist))"
E <- plm::pdata.frame(df, index = c('permno', 'td'), drop.index=TRUE, row.names=TRUE)"
model <- plm::plm(retadj ~ sent*EAD*isgrowth+sent*EAD*isvalue+sent*lag1EAD*isvalue+sent*lag1EAD*isgrowth+sent*lag2EAD*isvalue+sent*lag2EAD*isgrowth+sent*lag_1EAD*isvalue+sent*lag_1EAD*isgrowth+sent*lag_1newsday*isvalue+sent*lag_1newsday*isgrowth+sent*EAD*MA_20sent*isvalue+sent*EAD*MA_20sent*isgrowth+mktrf+hml+smb+umd+lag_1ret+isvalue*VWvaluesent+isgrowth*VWgrowthsent, data=E, model = "random")
print(summary(model))
print(stargazer::stargazer(model))

library(dplyr)
set.seed(1234)
dat <- data.frame(x = rnorm(10, 30, .2), 
                  y = runif(10, 3, 5),
                  z = runif(10, 10, 20))
dat

myvars <- list(
  var1 = sym("y"),
  var2 = sym("z")
)
myvars<-c(var1 = "y", var2 ="z")
dat2 <- dat %>% mutate_at(var(dat, !!myvars), funs(scale(.) %>% as.vector))
x <- cbind(a = 1:3, pi = pi) # simple matrix with dimnames
attributes(x)

library(caret)