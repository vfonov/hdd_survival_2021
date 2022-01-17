library(tidyverse)
library(survival)

con<-DBI::dbConnect(RSQLite::SQLite(), "raw/backblaze.sqlite3")

model="ST12000NM0007"
res <- DBI::dbSendQuery(con, "select id from model where val=?",model)

model_id<-DBI::dbFetch(res)

res <- DBI::dbSendQuery(con, "select age,failure from drive_surv where model_id=?",model_id$id)

hdd_surv<-DBI::dbFetch(res)

# surprisingly there are a few drives with zero age . IE DOA drives?
hdd_surv<-hdd_surv%>%filter(age>0)%>%mutate(age=as.numeric(age))

# run survival regression
model_par<-survreg(Surv(age, failure) ~ 1, hdd_surv, dist='weibull')
model_km<-survfit(Surv(age, failure) ~ 1, hdd_surv)

pred_km<-data.frame(
    age=model_km$time,
    surv=model_km$surv,
    hi=model_km$upper,
    low=model_km$lower
)
print(summary(model_par))

pred_par<-data.frame(predict(model_par, se=T,type="quantile",p=1:100/1000,newdata=data.frame(1)))
pred_par$surv=1.0-1:100/1000

pred_par<-pred_par%>%mutate(age=fit,age_lo=fit-2*se.fit,age_hi=fit+2*se.fit,low=1,hi=1)

#png("R_survival.png",width=800,height=800)

ggplot(pred_km,aes(x=age,y=surv,ymin=low,ymax=hi))+
    geom_line(col='red')+geom_ribbon(col='red',alpha=0.4)+
    geom_line(data=pred_par,aes(x=age,y=surv),col='green',inherit.aes=F)+
    geom_line(data=pred_par,aes(y=surv,x=age_lo),col='green',alpha=0.4,inherit.aes=F,lty=2)+
    geom_line(data=pred_par,aes(y=surv,x=age_hi),col='green',alpha=0.4,inherit.aes=F,lty=2)



