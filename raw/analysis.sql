-- create additional tables that help analysis

-- speedup queries
create index if not exists model_idx on drive_stats(model_id);
create index if not exists serial_idx on drive_stats(serial_number_id);


-- table of model drive capacity
create table if not exists model_capacity as select model_id,max(capacity_bytes) as capacity_bytes from drive_stats group by 1;


-- table of model to serial number correspondance 
create table if not exists model_serial as select distinct model_id,serial_number_id from drive_stats;

-- drive survival table
create table if not exists drive_surv as select model_id,serial_number_id,min(day) as start,max(day) as stop,max(failure) as failure from drive_stats group by 1,2;
alter table drive_surv add column age integer;
update drive_surv set age=stop-start;
