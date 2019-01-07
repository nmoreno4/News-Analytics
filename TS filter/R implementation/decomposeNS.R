library(readr)
library(zoo)
library(xts)
library(knitr)
library(neverhpfilter)

BG_all_VW_month <- read_csv("~/Data/TS/NS/BG/BG_all_VW_month.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
BG_all_VW_day <- read_csv("~/Data/TS/NS/BG/BG_all_VW_day.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
BV_all_VW_month <- read_csv("~/Data/TS/NS/BV/BV_all_VW_month.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
SG_all_VW_month <- read_csv("~/Data/TS/NS/SG/SG_all_VW_month.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
SV_all_VW_month <- read_csv("~/Data/TS/NS/SV/SV_all_VW_month.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
ALL_all_VW_month <- read_csv("~/Data/TS/NS/ALL/ALL_all_VW_month.csv", 
                            col_types = cols(perID = col_date(format = "%Y-%m-%d")))
ALL_all_VW_quarter <- read_csv("~/Data/TS/NS/ALL/ALL_all_VW_quarter.csv", 
                             col_types = cols(perID = col_date(format = "%Y-%m-%d")))
BG_all_VW_day <- read_csv("~/Data/TS/NS/BG/BG_all_VW_day.csv", 
                               col_types = cols(perID = col_date(format = "%Y-%m-%d")))
plot(BG_all_VW_month$NS, type="l")
plot(BV_all_VW_month$NS, type="l")
plot(SV_all_VW_month$NS, type="l")
plot(SG_all_VW_month$NS, type="l")

val = (BV_all_VW_month$NS + SV_all_VW_month$NS)/2
gro = (BG_all_VW_month$NS + SG_all_VW_month$NS)/2
HML = val-gro
MktNS = ALL_all_VW_quarter$NS


NS = BV_all_VW_month$NS
idx = BV_all_VW_month$perID

plot(val, type="l")
plot(gro, type="l")
plot(val-gro, type="l")

mean(ALL_all_VW_month$NS, na.rm = T)


M = cbind(NS)
M = xts(M, order.by = idx)
plot(M)

data("GDPC1")

news_filter <- yth_filter(M, h = 36, p = 4)
plot(news_filter$NS.cycle)
plot(news_filter$NS.trend)
plot(news_filter$NS.random)
plot(M)
news_reg <- yth_glm(M, h = 36, p = 4)
summary(news_reg)

gdp_filter <- yth_filter(GDPC1, h = 8, p = 2)
plot(gdp_filter$GDPC1.cycle)
plot(gdp_filter$GDPC1.trend)
plot(gdp_filter$GDPC1.random)
gdp_reg <- yth_glm(GDPC1, h = 8, p = 2)
summary(gdp_reg)
