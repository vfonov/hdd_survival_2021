#library(DBI)
library(tidyverse)
library(scales)
library(survival)

# using survminer package for plotting pretty survival curves
library(survminer)

#bb <- dbConnect(RSQLite::SQLite(), "backblaze_2013_2017.db")

# get survival info
#hdd_surv<-dbGetQuery(bb, 'select serial_number,model,status,age_hrs/24.0 as age_days,capacity_bytes/1000000000000.0 as capacity,start from drives where 1500000000000 <= capacity_bytes')

hdd<-read_csv('backblaze_2013_2017_hdd_survival.csv')

hdd<-hdd %>% filter(make!="", make!="SAMSUNG", capacity>0, capacity<100) # limit capacity at 100Tb (there is one misreported drive)

hdd<-hdd %>% mutate(make=as.factor(make), model=as.factor(model), capacity = as.factor(capacity))

# let's see how the hard drives were installed

ggplot(hdd,aes(x=start,fill=capacity))+
   geom_histogram()+
   scale_x_date(labels=date_format("%Y-%b"),breaks = date_breaks('1 month'), limits = c(as.Date("2013-01-01"), as.Date("2018-01-01")))+
   theme_bw()+theme(axis.text.x = element_text(angle = 90, vjust = 0.5))+xlab(NULL)


# 0. overall survival plot, using K-M method

hdd_surv <- survfit(Surv(age_days, status) ~ 1, data=hdd)



# 1. let's see is there a difference between 




# remove rare hard drives
common_models<-hdd_surv %>% group_by(model) %>% summarise(n=n()) %>% filter(n>20)

hdd_surv<-hdd_surv %>% filter(model_no %in% common_models$names) %>% mutate(model_no=droplevels(model_no))

# overall survival regardless of any info

# plot overall survival curve
autoplot(hdd_surv_fit)
#summary(hdd_surv_fit)


# fit with drive make

# 1st with make
hdd_surv_fit <- survfit(Surv(age_days, status) ~ make, data=hdd_surv)
autoplot(hdd_surv_fit)

# 2nd with capacity
hdd_surv_fit <- survfit(Surv(age_days, status) ~ capacity, data=hdd_surv)
autoplot(hdd_surv_fit)


# let's take a look at WDC

wdc_surv<-hdd_surv %>% filter(make=='WDC') %>% mutate(model_no=droplevels(model_no))
# 3rd with model_no

wdc_surv_fit <- coxph(Surv(age_days, status) ~ model_no, data=wdc_surv)

hdd_surv_fit_tidy = tidy(hdd_surv_fit)
mx = max(hdd_surv_fit_tidy$n.censor)

#autoplot(hdd_surv_fit)
ggplot(hdd_surv_fit_tidy, aes(time, estimate)) + 
  geom_line() +
  facet_wrap(~strata) +
  geom_ribbon(aes(ymin=conf.low, ymax=conf.high), alpha=.25) + 
  xlab("Days") + 
  ylab("Proportion Survival")
  
  
st_surv<-hdd_surv %>% filter(make=='SEAGATE') %>% mutate(model_no=droplevels(model_no))
st_surv_fit <- survfit(Surv(age_days, status) ~ model_no, data=st_surv)

