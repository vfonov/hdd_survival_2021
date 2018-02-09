library(tidyverse)
library(scales)
library(survival)
library(zoo)

# using survminer package for plotting pretty survival curves
library(survminer)

# make graph plotting prettier on linux without X11
#options(bitmapType='cairo')

# default theme 
theme_set(theme_bw(base_size = 20))

hdd<-read_csv('backblaze_2013_2017_hdd_survival.csv')

hdd<-hdd %>% filter(make!="", make!="SAMSUNG", capacity>0, capacity<100) # limit capacity at 100Tb (there is one misreported drive)

hdd<-hdd %>% mutate(make=as.factor(make), model=as.factor(model), capacity = as.factor(capacity),
                    year=as.factor(format(start,format='%Y')),
                    quarter=as.factor(as.yearqtr(start)))

# let's see how the hard drives were installed

png("capacity_by_year.png",width=800,height=600)

ggplot(hdd,aes(x=start, fill=capacity))+
   geom_histogram()+
   scale_x_date(labels=date_format("%Y-%b"),
                breaks = date_breaks('1 month'), 
                limits = c(as.Date("2013-01-01"), as.Date("2018-01-01")))+
   theme(axis.text.x = element_text(angle = 90, vjust = 0.5))+xlab(NULL)


# example of survival plot:
png("survival_example1.png",width=800,height=600)

hdd_example1<-hdd %>% filter(model=='ST31500341AS')
ggsurvplot(survfit(Surv(age_days, status) ~ 1, data=hdd_example1),data=hdd_example1, 
  conf.int = TRUE,xlab = "Days of service",ylim=c(0.4,1.0),conf.int.style ='step',censor=T,legend='none',surv.scale='percent' ),
  

png("survival_example2.png",width=800,height=600)
hdd_example2<-hdd %>% filter(model %in% c('ST31500341AS','ST31500541AS')) %>% mutate(model=droplevels(model))
s<-survfit(Surv(age_days, status) ~ model, data=hdd_example2)
ggsurvplot(s,data=hdd_example2, legend.title='1.5Tb model',
  conf.int = TRUE,xlab = "Days of service",ylim=c(0.4,1.0),conf.int.style ='step',censor=T,pval=T,pval.coord=c(100,0.7),
  surv.scale='percent',
  legend.labs = levels(hdd_example2$model))

# 0. overall survival plot, using Kaplan-Meier notation
png("overall_survival.png",width=800,height=600)
ggsurvplot(survfit(Surv(age_days, status) ~ 1, data=hdd),data=hdd, 
  conf.int = TRUE,xlab = "Days of service",ylim=c(0.5,1.0),conf.int.style ='step',censor=F,legend='none',surv.scale='percent' )


png("survival_example3.png",width=800,height=600)
hdd_common_10<-hdd %>% group_by(model) %>% summarise(n=n()) %>% arrange(desc(n)) %>% head(10)
hdd_common<-hdd %>% filter(model %in% hdd_common_10$model) %>% 
      mutate( model=factor( as.character(model),levels=hdd_common_10$model))

ggsurvplot(survfit(Surv(age_days, status) ~ model, data=hdd_common),data=hdd_common,
  conf.int = F,xlab = "Days of service",ylim=c(0.4,1.0),conf.int.style ='step',censor=F,pval=T,
  pval.coord=c(100,0.7),surv.scale='percent',legend.labs = levels(hdd_common$model),
  legend.title='Top 10 models',  legend = "right")


# 1. let's see is there a difference between different capacities, simple Kaplan-Meier case

png("by_capacity_survival.png",width=800,height=600)
cap<-survfit(Surv(age_days, status) ~ capacity, data=hdd)
ggsurvplot(cap, data=hdd, 
  conf.int = TRUE,xlab = "Days of service",
  ylim=c(0.7,1.0),
  conf.int.style ='step', 
  pval=TRUE, censor=F,pval.coord=c(100,0.7),surv.scale='percent',
  legend.labs = levels(hdd$capacity),legend.title='Capacity (Tb)' )

png("by_make_survival.png",width=800,height=600)
make<-survfit(Surv(age_days, status) ~ make, data=hdd)
ggsurvplot(make, data=hdd, 
  conf.int = TRUE,xlab = "Days of service",
  ylim=c(0.75,1.0),
  conf.int.style ='step', 
  pval=TRUE, censor=F,pval.coord=c(100,0.7),surv.scale='percent',
  legend.labs = levels(hdd$make),legend.title='Make' )


png("by_year_survival.png",width=800,height=600)
by_year<-survfit(Surv(age_days, status) ~ year, data=hdd)
ggsurvplot(by_year, data=hdd, 
  conf.int = TRUE,xlab = "Days of service",
  ylim=c(0.75,1.0),
  pval=TRUE, censor=F,pval.coord=c(100,0.8),surv.scale='percent',
  legend.labs = levels(hdd$year),legend.title='by Year' )

png("by_year_survival_1st_year.png",width=800,height=600)
ggsurvplot(by_year, data=hdd,
    conf.int = TRUE, xlab = "Days of service", break.time.by=30,
    ylim=c(0.975,1.0), 
    xlim=c(0,365),  
    censor=F,pval.coord=c(100,0.8), 
    surv.scale='percent', legend.labs = levels(hdd$year), legend.title='by Year' )
  
  
# now let's see how different models of 8Tb hard drives behave, again using Kaplan-Meier
png("8tb_by_model_survival.png",width=800,height=600)
hdd_8Tb<-hdd %>% filter(capacity==8) %>% mutate(model=droplevels(model))

model8<-survfit(Surv(age_days, status) ~ model, data=hdd_8Tb)
ggsurvplot(model8, data=hdd_8Tb, 
  conf.int = TRUE,xlab = "Days",
  ylim=c(0.75,1.0),
  conf.int.style ='step', 
  pval=TRUE, censor=T, pval.coord=c(100,0.7), surv.scale='percent',
  legend.labs = levels(hdd_8Tb$model), legend.title='8TB model' )


# and now for large hard drives
png("large_by_model_survival.png",width=800,height=600)
hdd_large<-hdd %>% filter(capacity %in% c(8,10,12)) %>% mutate(model=droplevels(model))
# remove rare hard drives and make informative name
hdd_large_common<-hdd_large %>% group_by(model) %>% summarise(n=n()) %>% filter(n>20)
hdd_large<-hdd_large %>% filter(model %in% hdd_large_common$model) %>% mutate(mdl=as.factor(paste(capacity,make,model,sep="\n")))

model_large<-survfit(Surv(age_days, status) ~ mdl, data=hdd_large)
ggsurvplot(model_large, data=hdd_large, 
  conf.int = TRUE,xlab = "Days",
  ylim=c(0.75,1.0),
  conf.int.style ='step', 
  pval=TRUE, censor=F, pval.coord=c(100,0.7), surv.scale='percent',
  legend.labs = levels(hdd_large$mdl), legend.title='Large HDD' )


# large (8,10,12) vs med (3,4,5,6) vs small (1.5,2)

png("by_category_survival.png",width=800,height=600)

hdd<-hdd %>% mutate(cap=as.factor( ifelse(capacity %in% c(1.5,2),'small: <3 ', ifelse(capacity %in% c(3,4,5,6), 'med: [3-6]','large: >6'))))
model_by_category<-survfit(Surv(age_days, status) ~ cap, data=hdd)

ggsurvplot(model_by_category, data=hdd,
    conf.int = TRUE, xlab = "Days of service",
    ylim=c(0.75,1.0), 
    pval=T,
    censor=F,pval.coord=c(100,0.8), 
    surv.scale='percent', legend.labs = levels(hdd$cap), legend.title='by category' )


    
# now let's do something interesting

# here we COX proportional hazard model to estimate multiplicative effects 
# main assumptionis that they are actually fit Cox model
# see https://en.wikipedia.org/wiki/Proportional_hazards_model 
# and 
png("coxph_results_yearly.png",width=800,height=1000)

model_coxph<-coxph(Surv(age_days, status) ~ make + capacity + year, data=hdd)
# plot results
ggforest(model_coxph)



# let's see top 3 popular models
hdd_common<-hdd %>% group_by(model) %>% summarise(n=n()) %>% arrange(desc(n)) %>% head(4)
hdd_pop<-hdd %>% filter(model  %in% hdd_common$model)
hdd_pop<-hdd_pop %>% mutate(model=droplevels(model))
model_pop<-survfit(Surv(age_days, status) ~ model, data=hdd_pop)
ggsurvplot(model_pop, data=hdd_pop,
    conf.int = TRUE, xlab = "Days of service",
    ylim=c(0.75,1.0), 
    pval=T,
    censor=F,pval.coord=c(100,0.8), 
    surv.scale='percent', legend.labs = levels(hdd_pop$model), legend.title='top 4 HDD' )


hdd_st4000dm000<-hdd %>% 
  filter(model=='ST4000DM000') %>% 
  mutate(quarter=as.factor(as.yearqtr(start)),monthly=as.factor(format(start,'%Y-%m')))

model_st4000dm000<-survfit(Surv(age_days, status) ~ quarter, data=hdd_st4000dm000)
ggsurvplot(model_st4000dm000, data=hdd_st4000dm000,
    conf.int = F, xlab = "Days of service",
    ylim=c(0.75,1.0), 
    pval=T,
    censor=F,pval.coord=c(100,0.8), 
    surv.scale='percent', legend.labs = levels(hdd_st4000dm000$quarter), legend.title='top 4 HDD' )

