-- create additional tables that help analysis

-- speedup queries
create index if not exists model_idx on drive_stats(model_id);
create index if not exists serial_idx on drive_stats(serial_number_id);


drop table model_capacity;
drop table model_serial;
drop table drive_surv;

-- table of model drive capacity
create table if not exists model_capacity as select model_id,max(capacity_bytes) as capacity_bytes from drive_stats group by 1;


-- table of model to serial number correspondance 
create table if not exists model_serial as select distinct model_id,serial_number_id from drive_stats;



-- drive survival table
create table if not exists drive_surv as select model_id,serial_number_id,min(day) as start from drive_stats group by 1,2;
-- ,max(day) as stop,max(failure) as failure 

alter table drive_surv add column stop integer;
alter table drive_surv add column age integer;
alter table drive_surv add column failure integer;

-- have to make a separate query for hard drives that failed, because as it turns out the record continues after drive is failed
update drive_surv as a set stop=(select min(b.day) from drive_stats as b where b.model_id=a.model_id and b.serial_number_id=a.serial_number_id and b.failure=1);
update drive_surv set failure=1 where stop is not NULL;
update drive_surv as a set stop=(select max(b.day) from drive_stats as b where b.model_id=a.model_id and b.serial_number_id=a.serial_number_id ) where a.stop is NULL;


update drive_surv set age=stop-start;
update drive_surv set failure=0 where failure is NULL;
