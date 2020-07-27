define schema = ?????

create table &&schema..debug_log
(dl_id   number
,call_stack varchar2(1000)
,action     varchar2(64)
,client_identifier varchar2(64)
,host varchar2(64)
,instance_name varchar2(32)
,ip_address varchar2(32)
,module  varchar2(64)
,os_user varchar2(64)
,service_name varchar2(64)
,sessionid varchar2(64)
,sid number
,logged_time timestamp
,msg varchar2(4000))
/


create sequence seq_debug_log cache 1000;

CREATE CONTEXT "DEBUG_INFO_CTX" USING &&schema.."DEBUG_INFO" ACCESSED GLOBALLY;  


create table &&schema..DEBUG_STATISTICS
   ( MODULE varchar2(64),
     ACTION varchar2(64),
     FROM_TIME timestamp,
     TO_TIME timestamp,
     EXECUTION_COUNT number);


create or replace synonym msg for debug_info.msg;
