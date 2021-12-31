library(survminer)
library(survival)
library(tidyverse)

data("mastectomy", package = "HSAUR")

#fit <- survfit(Surv(time, event) ~ metastized, data = mastectomy)
k_m_fit<-broom::tidy(survfit(Surv(time, event) ~ metastized, data=mastectomy)) %>%
    filter(strata=="metastized=yes")

fit<-survreg(Surv(time, event) ~ metastized, data=mastectomy,dist='exponential')

print("Exponential fit:")
print(summary(fit))


fit_range=seq(0.0,0.75,length.out=45)

par_fit<-data.frame(predict(fit, newdata=list(metastized="yes"),se=T,type="quantile",p=fit_range))
par_fit$survival<-1.0-fit_range
par_fit$se[is.na(par_fit$se)]=0.0 # fix undefined Se at 0 


png("survfit.png",width=600,height=600)

ggplot(k_m_fit,aes(x=time,y=estimate))+
  geom_line(aes(colour='K-M'),alpha=0.6)+
  geom_line(aes(x=time,y=conf.low,colour='K-M'),lty=2,alpha=0.6)+
  geom_line(aes(x=time,y=conf.high,colour='K-M'),lty=2,alpha=0.6)+

  geom_line(data=par_fit,aes(x=fit,y=survival,colour='Exponential'),alpha=0.4)+
  geom_line(data=par_fit,aes(x=fit+se*1.96,y=survival,colour='Exponential'),lty=2,alpha=0.4)+
  geom_line(data=par_fit,aes(x=fit-se*1.96,y=survival,colour='Exponential'),lty=2,alpha=0.4)+
  scale_colour_manual(values=c("black", "green"), 
                      name="Fit type",
                      breaks=c("K-M", "Exponential"))



#ggsurvplot(fit, data = mastectomy)
