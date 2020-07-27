define schema = ????

CREATE OR REPLACE PACKAGE BODY &&schema..DEBUG_INFO IS

   
-- Private Program Units ------------------------------------------------------------------------

   -- Routine that does the database-specific logging

   PROCEDURE internal_log_msg (p_msg           varchar2
                              ,p_call_stack    varchar2
                              ,p_logged_time   timestamp default current_timestamp) IS

      PRAGMA AUTONOMOUS_TRANSACTION;

   BEGIN
      insert into debug_log
         (dl_id
         ,call_stack
         ,action
         ,client_identifier
         ,host
         ,instance_name
         ,ip_address
         ,module
         ,os_user
         ,service_name
         ,sessionid
         ,sid
         ,logged_time
         ,msg)
      values
         ( seq_debug_log.nextval
--          ,p_call_stack
          ,trim(chr(10) from regexp_replace(p_call_stack,chr(10)||'.{20}',chr(10)))
          ,sys_context('userenv','action')
          ,sys_context('userenv','client_identifier')
          ,sys_context('userenv','host')
          ,sys_context('userenv','instance_name')
          ,sys_context('userenv','ip_address')
          ,sys_context('userenv','module')
          ,sys_context('userenv','os_user')
          ,sys_context('userenv','service_name')
          ,sys_context('userenv','sessionid')
          ,sys_context('userenv','sid')
          ,p_logged_time
          ,substr(p_msg, 1, 4000)
          );
      COMMIT;
   END;

FUNCTION  db_stack RETURN debug_info_g.t_msg_list is
  l_stack debug_info_g.t_msg_list;
  l_idx   pls_integer;
BEGIN
  FOR l_idx IN REVERSE 1 .. debug_info_g.g_db_stack_pos-1 LOOP
    IF debug_info_g.g_db_stack.exists(l_idx) THEN
      l_stack(l_stack.count+1) := debug_info_g.g_db_stack(l_idx);
    ELSE
      EXIT;
    END IF;
  END LOOP;

  FOR l_idx IN REVERSE debug_info_g.g_db_stack_pos .. debug_info_g.g_db_stack_history LOOP
    IF debug_info_g.g_db_stack.exists(l_idx) THEN
      l_stack(l_stack.count+1) := debug_info_g.g_db_stack(l_idx);
    ELSE
      EXIT;
    END IF;
  END LOOP;
  
  RETURN l_stack;
END;

FUNCTION  db_stack_oldest_last RETURN debug_info_g.t_msg_list is
  l_stack debug_info_g.t_msg_list;
  l_idx   pls_integer;
BEGIN
  FOR l_idx IN debug_info_g.g_db_stack_pos .. debug_info_g.g_db_stack_history LOOP
    IF debug_info_g.g_db_stack.exists(l_idx) THEN
      l_stack(l_stack.count+1) := debug_info_g.g_db_stack(l_idx);
    ELSE
      EXIT;
    END IF;
  END LOOP;
  
  FOR l_idx IN 1 .. debug_info_g.g_db_stack_pos-1 LOOP
    IF debug_info_g.g_db_stack.exists(l_idx) THEN
      l_stack(l_stack.count+1) := debug_info_g.g_db_stack(l_idx);
    ELSE
      EXIT;
    END IF;
  END LOOP;
  
  RETURN l_stack;
END;

PROCEDURE set_context(p_attrib varchar2, p_value varchar2) is
BEGIN
    dbms_session.set_context(
        namespace  => debug_info_g.g_debug_info_ctx,
        attribute  => p_attrib,
        value      => p_value);
END;

PROCEDURE clear_context(p_attrib varchar2) is
BEGIN
    dbms_session.clear_context(
        namespace  => debug_info_g.g_debug_info_ctx,
        attribute  => p_attrib);
END;


PROCEDURE reset_db_stack is
BEGIN
  debug_info_g.g_db_stack.delete;
  debug_info_g.g_db_stack_pos := 0;
END;

--
-- ask another session to reset stack
--
PROCEDURE reset_db_stack(p_sid     NUMBER
                          ,p_serial# NUMBER) is
  l_status       NUMBER;
  l_unique_id    VARCHAR2(10);
BEGIN

  l_unique_id := ltrim(to_char(p_sid,'00XX'))||
                 ltrim(to_char(p_serial#,'00XX'));

  set_context(substr(l_unique_id,1,8),debug_info_g.g_reset_tag);

END;


--
-- ask another session to flush stats
--
PROCEDURE flush_statistics(p_sid     NUMBER
                          ,p_serial# NUMBER) is
  l_status       NUMBER;
  l_unique_id    VARCHAR2(10);
BEGIN

  l_unique_id := ltrim(to_char(p_sid,'00XX'))||
                 ltrim(to_char(p_serial#,'00XX'));

  set_context(substr(l_unique_id,1,8),debug_info_g.g_flush_tag||'statistics');

END;

--
-- flush out execution statistics
--
PROCEDURE flush_statistics is
  pragma autonomous_transaction;
  
  l_stats_idx varchar2(60);

  type t_number_array    is table of number       index by pls_integer;
  type t_timestamp_array is table of timestamp(6) index by pls_integer;
  type t_varchar2_array  is table of varchar2(60) index by pls_integer;
  
  l_action    t_varchar2_array;
  l_from_time t_timestamp_array;
  l_execution t_number_array;

BEGIN
  l_stats_idx := debug_info_g.g_usage_stats.first;
  while l_stats_idx is not null loop
      l_action(l_action.count+1)       :=  l_stats_idx;
      l_from_time(l_from_time.count+1) :=  debug_info_g.g_usage_stats(l_stats_idx).from_time;   
      l_execution(l_execution.count+1) :=  debug_info_g.g_usage_stats(l_stats_idx).execution_count;
      l_stats_idx := debug_info_g.g_usage_stats.next(l_stats_idx);
  end loop;

  debug_info_g.g_usage_flush_time := current_date;
  debug_info_g.g_usage_stats.delete;

  forall i in 1 .. l_action.count
     insert into DEBUG_STATISTICS 
        ( MODULE,
          ACTION,
          FROM_TIME,
          TO_TIME,
          EXECUTION_COUNT)
     values 
        ( sys_context('USERENV','MODULE'),
          l_action(i),
          l_from_time(i),
          current_timestamp,
          l_execution(i));
  commit;
END;

--
-- ask another session to flush stats
--
PROCEDURE flush_message_stack(p_sid     NUMBER
                             ,p_serial# NUMBER
                             ,p_reset_stack boolean default false) is
  l_status       NUMBER;
  l_unique_id    VARCHAR2(10);
BEGIN

  l_unique_id := ltrim(to_char(p_sid,'00XX'))||
                 ltrim(to_char(p_serial#,'00XX'));

  set_context(substr(l_unique_id,1,8),debug_info_g.g_flush_tag||'stack'||case when p_reset_stack then debug_info_g.g_reset_tag end);

END;

--
-- flush out execution statistics
--
PROCEDURE flush_message_stack(p_reset_stack boolean default false) is
  pragma autonomous_transaction;
  l_stack debug_info_g.t_msg_list := db_stack_oldest_last;
BEGIN
  forall i in 1 .. l_stack.count
      insert into debug_log
         (dl_id
         ,call_stack
         ,action
         ,client_identifier
         ,host
         ,instance_name
         ,ip_address
         ,module
         ,os_user
         ,service_name
         ,sessionid
         ,sid
         ,logged_time
         ,msg)
      values
         ( seq_debug_log.nextval
          ,trim(chr(10) from regexp_replace(l_stack(i).call_stack,chr(10)||'.{20}',chr(10)))
          ,sys_context('userenv','action')
          ,sys_context('userenv','client_identifier')
          ,sys_context('userenv','host')
          ,sys_context('userenv','instance_name')
          ,sys_context('userenv','ip_address')
          ,sys_context('userenv','module')
          ,sys_context('userenv','os_user')
          ,sys_context('userenv','service_name')
          ,sys_context('userenv','sessionid')
          ,sys_context('userenv','sid')
          ,l_stack(i).logged_time
          ,substr(l_stack(i).msg, 1, 4000)
          );

      COMMIT;

  if p_reset_stack then
    reset_db_stack;
  end if;

END;

--
-- the facility to store debug information in DEBUG_LOG
--

PROCEDURE msg(p_msg VARCHAR2,
              p_debug_level PLS_INTEGER default 0,
              p_stack_offset PLS_INTEGER default 0) is

-- Private Variables
   l_call_stack      VARCHAR2(4001);
   l_status          NUMBER;
   l_pipe_msg        VARCHAR2(255);
   l_client_id       VARCHAR2(255);
BEGIN

--
-- debugging levels higher than default level is ignored
--
  if p_debug_level > debug_info_g.g_db_stack_level then  
     return;
  end if;

--
-- otherwise, proceed and log messages where appropriate.
-- first we identify plsql name and line
--

  l_call_stack := dbms_utility.format_call_stack;
  l_call_stack := substr(l_call_stack,instr(l_call_stack,chr(10),1,p_stack_offset+4));

--
-- Client info messaging is always done
--
  debug_info_g.g_db_stack(debug_info_g.g_db_stack_pos).msg         := substr(p_msg,1,4000);
  debug_info_g.g_db_stack(debug_info_g.g_db_stack_pos).call_stack  := l_call_stack;
  debug_info_g.g_db_stack(debug_info_g.g_db_stack_pos).logged_time := current_timestamp;
  debug_info_g.g_db_stack_pos                         := debug_info_g.g_db_stack_pos+1; 

  -- faster than mod
  if debug_info_g.g_db_stack_pos > debug_info_g.g_db_stack_history then
    debug_info_g.g_db_stack_pos := 1;
  end if;

  -- every 10 seconds, we'll check to see if someone has passed a "debug:on" signal
  -- along the context for a client id of null, which means we need to:
  --    -- remember the current ID (typically UUID)
  --    -- clear it
  --    -- check the global null context for debug requests
  --    -- then reset it back to what it was

  if current_date - debug_info_g.g_last_debug_flag_check > .000115741  -- 10 seconds
  then
    dbms_application_info.set_client_info(to_char(current_date,'HH24MISS:')||p_msg);    
    l_client_id  := sys_context('userenv','client_identifier');
    dbms_session.clear_identifier;
    l_pipe_msg   := sys_context(debug_info_g.g_debug_info_ctx,debug_info_g.g_session_id);
    dbms_session.set_identifier(l_client_id);
    debug_info_g.g_last_debug_flag_check := current_date;

    if l_pipe_msg is not null then
       if l_pipe_msg like debug_info_g.g_enable_tag||'%' then
         debug_info_g.g_db_logging_date := to_date(substr(l_pipe_msg,length(debug_info_g.g_enable_tag)+1, length(debug_info_g.g_pipe_format_mask)-2),debug_info_g.g_pipe_format_mask);
         debug_info_g.g_use_dbms_output := ( substr(l_pipe_msg,length(debug_info_g.g_enable_tag)+length(debug_info_g.g_pipe_format_mask),1) = 'Y' );
       elsif l_pipe_msg like debug_info_g.g_modify_tag||'%' then
         debug_info_g.g_db_stack_history   := to_number(substr(l_pipe_msg,length(debug_info_g.g_modify_tag)+1,5));
         debug_info_g.g_db_stack_level     := to_number(substr(l_pipe_msg,length(debug_info_g.g_modify_tag)+7,3));
         debug_info_g.g_use_dbms_output := ( substr(l_pipe_msg,length(debug_info_g.g_modify_tag)+11,1) = 'Y' );
       elsif l_pipe_msg like debug_info_g.g_flush_tag||'%stat%' then
         flush_statistics;
       elsif l_pipe_msg like debug_info_g.g_flush_tag||'%stack%' then
         flush_message_stack;
         -- we must recheck the pipe, because its possible that a subsequent
         -- 'reset' message has been sent as well
         if l_pipe_msg like '%'||debug_info_g.g_reset_tag then
            reset_db_stack;
         end if;
       elsif l_pipe_msg = debug_info_g.g_reset_tag then
         reset_db_stack;
       elsif l_pipe_msg like debug_info_g.g_disable_tag||'%' then
         debug_info_g.g_use_dbms_output := ( substr(l_pipe_msg,length(debug_info_g.g_disable_tag)+1,1) = 'Y' );
         debug_info_g.g_db_logging_date := current_date-1000;
       else
         debug_info_g.g_db_logging_date := current_date-1000;
       end if;
       debug_info_g.g_rows_logged := 0; -- any kind of signal means reset the counter
       -- now remove any surplus pipe messages
       debug_info_g.g_db_logging_enabled := (  debug_info_g.g_db_logging_date > current_date - 1);
       clear_context(debug_info_g.g_session_id);
    end if;
  end if;

  if debug_info_g.g_use_dbms_output then
      dbms_output.put_line(p_msg);
  end if;

  --
  -- if you told me to start more than 1 day ago, I'm gonna ignore you
  --
  if debug_info_g.g_db_logging_enabled then
     debug_info_g.g_rows_logged := debug_info_g.g_rows_logged + 1;
     if debug_info_g.g_rows_logged < debug_info_g.g_max_rows_debug then
       internal_log_msg(p_msg,l_call_stack);
     else
       internal_log_msg('WARNING: Maximum debugging rows reached',l_call_stack);
       debug_info_g.g_db_logging_date    := current_date-1000;
       debug_info_g.g_db_logging_enabled := false;
     end if;
  end if;

END;

--
-- These routines allow us to send a blip down a pipe to an active session
--
--  this one is useful for sessions wanting to activate themselves
--   ie, db_msg_control(dbms_session.unique_session_id);
--
PROCEDURE msg_control(p_unique_session_id varchar2,p_state boolean,p_dbms_output BOOLEAN DEFAULT FALSE) is
  status       NUMBER;
  l_unique_session_id VARCHAR2(20) := p_unique_session_id;
BEGIN

  IF l_unique_session_id IS NULL THEN
     select ltrim(to_char(sid,'00XX'))||ltrim(to_char(serial#,'00XX'))
     into   l_unique_session_id
     from   v$session
     where  sid = sys_context('USERENV','SID');
  END IF;
  --
  -- if the length is not 8 or 12, there's a good chance the unique session
  -- has not been passed in, so we chuck an error
  --
  if length(l_unique_session_id) not in (8,12) then
    raise_application_error(-20000,'Using first 8 chars of dbms_session.unique_session_id typically here');
  end if;

  --
  -- pack in our enable/disable flag
  --
  if p_state then
    set_context(substr(l_unique_session_id,1,8),
                case when p_state then debug_info_g.g_enable_tag else debug_info_g.g_disable_tag end||to_char(current_date,debug_info_g.g_pipe_format_mask)||':'||case when p_dbms_output then 'Y' else 'N' end);
  else
    set_context(substr(l_unique_session_id,1,8),
                debug_info_g.g_disable_tag||case when p_dbms_output then 'Y' else 'N' end);
  end if;

END;

--  and this for activating from another session


PROCEDURE msg_control(p_sid number, p_serial# number, p_state boolean,p_dbms_output BOOLEAN DEFAULT FALSE) is
  l_unique_id varchar2(20);
BEGIN
  l_unique_id := ltrim(to_char(p_sid,'00XX'))||
                 ltrim(to_char(p_serial#,'00XX'));

  msg_control(l_unique_id,p_state,p_dbms_output);
END;

--
-- These routines allow us to send a blip down a pipe to an active session
--
--  this one is useful for sessions wanting to activate themselves
--   ie, db_msg_control(dbms_session.unique_session_id);
--
PROCEDURE msg_control(p_unique_session_id varchar2,p_history number,p_debug_level number,p_dbms_output BOOLEAN) is
  status       NUMBER;
  l_unique_session_id VARCHAR2(20) := p_unique_session_id;
BEGIN

  IF l_unique_session_id IS NULL THEN
     select ltrim(to_char(sid,'00XX'))||ltrim(to_char(serial#,'00XX'))
     into   l_unique_session_id
     from   v$session
     where  sid = sys_context('USERENV','SID');
  END IF;
  --
  --
  -- if the length is not 8 or 12, there's a good chance the unique session
  -- has not been passed in, so we chuck an error
  --
  if length(l_unique_session_id) not in (8,12) then
    raise_application_error(-20000,'Using first 8 chars of dbms_session.unique_session_id typically here');
  end if;

  if nvl(p_history,0) not between 1 and 50000 then
    raise_application_error(-20000,'History must be between 1 and 50000');
  end if;

  if nvl(p_debug_level,0) not between 0 and 100 then
    raise_application_error(-20000,'Debug level must be between 1 and 100');
  end if;
  
  --
  -- pack in our modify flag
  --
  set_context(substr(l_unique_session_id,1,8),
              debug_info_g.g_modify_tag||to_char(p_history,'fm00000')||':'||to_char(p_debug_level,'fm000')||':'||case when p_dbms_output then 'Y' else 'N' end);

END;

--  and this for activating from another session


PROCEDURE msg_control(p_sid number, p_serial# number, p_history number,p_debug_level number,p_dbms_output BOOLEAN) is
  l_unique_id varchar2(20);
BEGIN
  l_unique_id := ltrim(to_char(p_sid,'00XX'))||
                 ltrim(to_char(p_serial#,'00XX'));

  msg_control(l_unique_id,p_history,p_debug_level,p_dbms_output);
END;


--PROCEDURE my_msg_control(p_state   BOOLEAN,p_dbms_output BOOLEAN DEFAULT FALSE) is
--BEGIN
--  msg_control(dbms_session.unique_session_id,p_state,p_dbms_output);
--END;


PROCEDURE assert(p_assertion     IN BOOLEAN,
                 p_error_message IN VARCHAR2) IS
BEGIN
   IF NOT p_assertion THEN
      RAISE_APPLICATION_ERROR(-20099, p_error_message);
   END IF;
END;

PROCEDURE set_module(p_module VARCHAR2, p_action VARCHAR2 DEFAULT null) IS
BEGIN
  dbms_application_info.set_module(p_module,p_action);

  if debug_info_g.g_db_logging_enabled then
     debug_info_g.g_rows_logged := debug_info_g.g_rows_logged + 1;
     if debug_info_g.g_rows_logged < debug_info_g.g_max_rows_debug then
       internal_log_msg('MODULE:'||p_module||', ACTION:'||p_action,null);
     else
       internal_log_msg('WARNING: Maximum debugging rows reached',null);
       debug_info_g.g_db_logging_date    := current_date-1000;
       debug_info_g.g_db_logging_enabled := false;
     end if;
  end if;

END;

PROCEDURE set_action(p_action VARCHAR2) IS
BEGIN
  init(p_action);
END;

FUNCTION debug_is_active RETURN BOOLEAN IS
BEGIN
  return debug_info_g.g_db_logging_enabled;
END;  


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
                 p_tstamp     timestamp default null) IS
                    
  type t_msg_set is table of varchar2(4000);                  
  l_msg t_msg_set := 
            t_msg_set(substr(p_msg1,1,4000),
                       substr(p_msg2,1,4000),
                       substr(p_msg3,1,4000),
                       substr(p_msg4,1,4000),
                       substr(p_msg5,1,4000),
                       substr(p_msg6,1,4000),
                       substr(p_msg7,1,4000),
                       substr(p_msg8,1,4000),
                       substr(p_msg9,1,4000));
  l_call_stack varchar2(4000) := nvl(p_call_stack,dbms_utility.format_call_stack);
  l_now        timestamp      := nvl(p_tstamp,current_timestamp);
BEGIN
  for i in 1 .. l_msg.count loop
    if l_msg(i) is not null then
      internal_log_msg(l_msg(i),l_call_stack,l_now);
    end if;
  end loop;
END;  

PROCEDURE cleanup IS
BEGIN
  dbms_application_info.set_action('');
END;  

PROCEDURE fatal(
               p_msg1 varchar2 default null,
               p_msg2 varchar2 default null,
               p_msg3 varchar2 default null,
               p_msg4 varchar2 default null,
               p_msg5 varchar2 default null,
               p_msg6 varchar2 default null,
               p_msg7 varchar2 default null,
               p_msg8 varchar2 default null,
               p_msg9 varchar2 default null) IS
  l_call_stack varchar2(4000) := dbms_utility.format_call_stack;
  l_now        timestamp      := current_timestamp;
BEGIN
 logger(dbms_utility.FORMAT_ERROR_BACKTRACE,
        dbms_utility.FORMAT_ERROR_STACK,
        p_call_stack=>l_call_stack,
        p_tstamp=>l_now);

 logger(p_msg1,
        p_msg2,
        p_msg3,
        p_msg4,
        p_msg5,
        p_msg6,
        p_msg7,
        p_msg8,
        p_msg9,
        p_call_stack=>l_call_stack,
        p_tstamp=>l_now);

  cleanup;         
END;

PROCEDURE init(p_action VARCHAR2) IS
  l_action varchar2(60) := substr(p_action,1,60);
BEGIN
  dbms_application_info.set_action(l_action);
  debug_info_g.g_usage_logged := debug_info_g.g_usage_logged + 1;
  -- a new action is starting
  
  IF l_action IS NOT NULL THEN
    IF debug_info_g.g_usage_stats.exists(l_action) THEN
       debug_info_g.g_usage_stats(l_action).execution_count := debug_info_g.g_usage_stats(l_action).execution_count + 1;
    ELSE
       debug_info_g.g_usage_stats(l_action).execution_count := 1;
       debug_info_g.g_usage_stats(l_action).from_time  := current_timestamp;
    END IF;
  END IF;
  
  IF current_date - debug_info_g.g_usage_flush_time > 1/24 THEN
    IF debug_info_g.g_usage_logged < 10000 OR debug_info_g.g_usage_stats.count > 500 THEN
    -- flush statistics every hour (if its not really busy)
      flush_statistics;
    END IF;
    debug_info_g.g_usage_logged := 0;
  END IF;
END;  

BEGIN
  debug_info_g.g_usage_flush_time := current_date;
END;
/
sho err


