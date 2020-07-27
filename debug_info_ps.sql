define schema = ????

CREATE OR REPLACE PACKAGE &&schema..DEBUG_INFO IS

   FUNCTION  db_stack RETURN debug_info_g.t_msg_list;

   PROCEDURE reset_db_stack;

   PROCEDURE reset_db_stack(p_sid     NUMBER
                           ,p_serial# NUMBER) ;

   PROCEDURE internal_log_msg (p_msg           varchar2
                              ,p_call_stack    varchar2
                              ,p_logged_time   timestamp default current_timestamp);

   PROCEDURE flush_statistics(p_sid     NUMBER
                             ,p_serial# NUMBER) ;

   PROCEDURE flush_statistics;

   PROCEDURE flush_message_stack(p_sid     NUMBER
                                ,p_serial# NUMBER
                                ,p_reset_stack boolean default false) ;

   PROCEDURE flush_message_stack(p_reset_stack boolean default false);

   PROCEDURE msg(p_msg          VARCHAR2,
                 p_debug_level  PLS_INTEGER DEFAULT 0,
                 p_stack_offset PLS_INTEGER DEFAULT 0) ;

   --
   -- enable/disable logging of messages to a table
   --
   PROCEDURE msg_control(p_unique_session_id VARCHAR2
                        ,p_state             BOOLEAN
                        ,p_dbms_output       BOOLEAN DEFAULT FALSE);

   PROCEDURE msg_control(p_sid     NUMBER
                        ,p_serial# NUMBER
                        ,p_state   BOOLEAN
                        ,p_dbms_output       BOOLEAN DEFAULT FALSE);

   --
   -- change defaults for current messaging
   --
   PROCEDURE msg_control(p_unique_session_id VARCHAR2
                        ,p_history           NUMBER
                        ,p_debug_level       NUMBER
                        ,p_dbms_output       BOOLEAN);

   PROCEDURE msg_control(p_sid         NUMBER
                        ,p_serial#     NUMBER
                        ,p_history     NUMBER 
                        ,p_debug_level NUMBER
                        ,p_dbms_output BOOLEAN);

--   PROCEDURE my_msg_control(p_state   BOOLEAN, p_dbms_output BOOLEAN DEFAULT FALSE);

   PROCEDURE assert(p_assertion     BOOLEAN,
                    p_error_message VARCHAR2);

   PROCEDURE set_module(p_module VARCHAR2, p_action VARCHAR2 DEFAULT null);

   PROCEDURE set_action(p_action VARCHAR2);

   FUNCTION debug_is_active RETURN BOOLEAN;

   PROCEDURE logger(p_msg1 varchar2,
                    p_msg2 varchar2 default null,
                    p_msg3 varchar2 default null,
                    p_msg4 varchar2 default null,
                    p_msg5 varchar2 default null,
                    p_msg6 varchar2 default null,
                    p_msg7 varchar2 default null,
                    p_msg8 varchar2 default null,
                    p_msg9 varchar2 default null,
                    p_call_stack varchar2 default null,
                    p_tstamp     timestamp default null);

   PROCEDURE cleanup;

   PROCEDURE fatal(p_msg1 varchar2 default null,
                   p_msg2 varchar2 default null,
                   p_msg3 varchar2 default null,
                   p_msg4 varchar2 default null,
                   p_msg5 varchar2 default null,
                   p_msg6 varchar2 default null,
                   p_msg7 varchar2 default null,
                   p_msg8 varchar2 default null,
                   p_msg9 varchar2 default null);

   PROCEDURE init(p_action VARCHAR2);

                    
END;
/
sho err

