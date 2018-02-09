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
png("survival_example_one.png",width=800,height=600)

hdd_example1<-hdd %>% filter(model=='ST31500341AS')
ggsurvplot( survfit(Surv(age_days, status) ~ 1, data=hdd_example1),data=hdd_example1, 
  conf.int = TRUE,xlab = "Days of service",ylim=c(0.4,1.0),
  conf.int.style ='step',censor=T,legend='none',surv.scale='percent' )
  

png("survival_example_two_hdd.png",width=800,height=600)
hdd_example2<-hdd %>% filter(model %in% c('ST31500341AS','ST31500541AS')) %>% mutate(model=droplevels(model))
s<-survfit(Surv(age_days, status) ~ model, data=hdd_example2)
ggsurvplot(s,data=hdd_example2, legend.title='1.5Tb model',
  conf.int = TRUE,xlab = "Days of service",
  ylim=c(0.4,1.0),conf.int.style ='step',censor=T,pval=T,pval.coord=c(100,0.7),
  surv.scale='percent',
  legend.labs = levels(hdd_example2$model))

# 0. overall survival plot, using Kaplan-Meier notation
png("overall_survival.png",width=800,height=600)
ggsurvplot(survfit(Surv(age_days, status) ~ 1, data=hdd),data=hdd, 
  conf.int = TRUE,xlab = "Days of service",ylim=c(0.5,1.0),conf.int.style ='step',censor=F,legend='none',surv.scale='percent' )


png("survival_by_quarter.png",width=800,height=600)
hdd_ST4000DM000=hdd %>% filter(model=='ST4000DM000')

model_by_quarter<-survfit(Surv(age_days, status) ~ quarter, data=hdd_ST4000DM000 )
ggsurvplot(model_by_quarter,data=hdd_ST4000DM000,
  conf.int = F,xlab = "Days of service",ylim=c(0.7,1.0),censor=F,pval=T,
  pval.coord=c(100,0.7),surv.scale='percent',legend.labs = levels(hdd_ST4000DM000$quarter),
  legend.title="ST4000DM000\nby quarter",  legend = "right")

# now let's do something interesting
# here we COX proportional hazard model to estimate multiplicative effects 
# main assumptionis that they are actually fit Cox model
# see https://en.wikipedia.org/wiki/Proportional_hazards_model 
# and 
png("coxph_results_quarterly.png",width=800,height=1000)
model_by_quarter_coxph<-coxph(Surv(age_days, status) ~ quarter, data=hdd_ST4000DM000)
# plot results
ggforest(model_by_quarter_coxph)


  
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
hdd_common_large<-hdd_large %>% group_by(model) %>% summarise(n=n()) %>% arrange(desc(n)) %>% head(4)

hdd_large<-hdd_large %>% filter(model %in% hdd_common_large$model)  %>% mutate(model=droplevels(model))
print("Large models:")
print(hdd_common_large$model)

model_large<-survfit(Surv(age_days, status) ~ model, data=hdd_large)
ggsurvplot(model_large, data=hdd_large, 
  conf.int = TRUE,xlab = "Days",
  ylim=c(0.925,1.0),
  conf.int.style ='step', 
  pval=T, censor=F, pval.coord=c(10,0.95), surv.scale='percent',
  legend = "right",
  legend.labs = levels(hdd_large$model), legend.title='Large HDD' )

png("large_by_model_survival_coxph.png",width=800,height=300)
model_coxph<-coxph(Surv(age_days, status) ~ model, data=hdd_large)
# plot results
ggforest(model_coxph)

  

  
png("survival_top10.png",width=800,height=600)
hdd_common_10<-hdd %>% group_by(model) %>% summarise(n=n()) %>% arrange(desc(n)) %>% head(10)
hdd_common<-hdd %>% filter(model %in% hdd_common_10$model) %>% 
      mutate( model=factor( as.character(model),levels=hdd_common_10$model))

ggsurvplot(survfit(Surv(age_days, status) ~ model, data=hdd_common),data=hdd_common,
  conf.int = F,xlab = "Days of service",ylim=c(0.4,1.0),conf.int.style ='step',censor=F,pval=T,
  pval.coord=c(100,0.7),surv.scale='percent',legend.labs = levels(hdd_common$model),
  legend.title='Top 10 models',  legend = "right")

png("survival_top10_coxph.png",width=1000,height=800)
hdd_common_coxph<-coxph(Surv(age_days, status) ~ model, data=hdd_common)
# plot results
ggforest(hdd_common_coxph)

# post-hoc comparision of most reliable hard drives:
compare<-pairwise_survdiff(Surv(age_days, status) ~ model, data=hdd_common)

# check if 5 most reliable are different:
reliable=c('HDS5C3030ALA630', 'HMS5C4040ALE640', 'HDS5C4040ALE630' , 'HDS722020ALA330' , 'HMS5C4040BLE640')

broom::tidy(res) %>% filter(group1 %in% reliable , group2 %in% reliable) %>% 
    mutate( sig=symnum(p.value, cutpoints = c(0, 0.0001, 0.001, 0.01, 0.05, 0.1, 1),
                                symbols = c("****", "***", "**", "*", "+", " ") ) )


# parametric models                                
png("survreg_time_to_failure.png",width=800,height=600)

fit_model_year<-survreg(Surv(age_days, status) ~ model*year, data=hdd_common)

newdat<-expand.grid(model=levels(hdd_common$model),year='2017')
newdat<-cbind(newdat,predict(fit_model_year, newdata=newdat,type="quantile",p=0.1,se=T))


#ST4000DM000:
data_ST4000DM000_2017<-hdd %>% filter(model=='ST4000DM000',year=='2017')
k_m_fit<-broom::tidy(survfit(Surv(age_days, status) ~ 1, data=data_ST4000DM000_2017))

par_fit<-expand.grid(model='ST4000DM000',year='2017',time=1:600)
par_fit<-cbind(par_fit,predict(fit_model_year, newdata=par_fit,se=T))



ggplot(k_m_fit,aes(x=time,y=estimate,ymin=conf.low,ymax=conf.high))+
  geom_line()+
  geom_ribbon(alpha=0.1)



ggplot(newdat,aes(x=model,y=fit,ymin=fit-1.96*se.fit,ymax=fit+1.96*se.fit))+
    geom_errorbar()+geom_point()+coord_flip()+ylab('Days of service')+xlab('HDD Model')+ggtitle('Expected time to 10% failure')







