define schema = ?????

CREATE OR REPLACE PACKAGE &&schema..DEBUG_INFO_G IS

-- public types, each debug item consists of the following data

   TYPE r_msg_details IS RECORD
      (msg          VARCHAR2(4000)       -- the message info
      ,call_stack   VARCHAR2(4000)       -- plsql call_stack
      ,logged_time  TIMESTAMP);          -- when

   TYPE t_msg_list IS TABLE OF r_msg_details INDEX BY BINARY_INTEGER;

   TYPE r_usage_stats IS RECORD
      (EXECUTION_COUNT    NUMBER(10),
       FROM_TIME          TIMESTAMP(6)
      );
  
   TYPE t_usage_stats IS TABLE OF r_usage_stats INDEX BY VARCHAR2(64);

-- constants

   g_enable_tag            constant varchar2(10) := 'enable:';          -- pipe message tags (turn on logging)
   g_disable_tag           constant varchar2(10) := 'disable:';         -- pipe message tags (turn off)
   g_modify_tag            constant varchar2(10) := 'modify:';          -- pipe message tags (change logging parms)
   g_flush_tag             constant varchar2(10) := 'flush:';           -- pipe message tags (flush execution stats)
   g_reset_tag             constant varchar2(10) := 'reset:';           -- pipe message tags (reset stack)
   g_pipe_format_mask      constant varchar2(20) := 'yyyymmddhh24miss'; -- pipe message content
   g_debug_info_ctx        constant varchar2(20) := 'DEBUG_INFO_CTX';

-- configurables

   g_db_logging_date       date         := current_date-1000;       -- any old long time ago
   g_db_logging_enabled    boolean      := false;
   g_use_dbms_output       boolean      := false;
   g_rows_logged           pls_integer  := 0;                  -- counter on rows logged
   g_usage_logged          pls_integer  := 0;
 
   g_max_rows_debug        pls_integer  := 100000;             -- max rows per session allowed for insertion

   g_db_stack              t_msg_list;                         -- db message stack
   g_db_stack_pos          pls_integer  := 1;                  -- db stack pointer
   g_db_stack_history      pls_integer  := 1000;               -- default max stack size
   g_db_stack_level        pls_integer  := 0;                  -- level of debug
   
   g_usage_stats           t_usage_stats;
   g_usage_flush_time      date;
   
   g_session_id            varchar2(8) := substr(dbms_session.unique_session_id,1,8);

   g_last_debug_flag_check date := sysdate;


END;
/

sho err
