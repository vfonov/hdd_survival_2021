#! /bin/bash

sqlite3 -header raw/backblaze.sqlite3 \
	"select model.val,count(distinct serial_number_id) from drive_stats left join model on model.id=drive_stats.model_id group by 1;"
