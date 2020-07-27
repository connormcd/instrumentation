Instrumentation for PLSQL


Installation
============
    @debug_objects.sql
    @debug_info_g_ps.sql
    @debug_info_ps.sql
    @debug_info_pb.sql


Example of usage in PL/SQL
==========================

Start of each procedure, call INIT
Throughout procedures, call MSG where appropriate. The less critical the information, the higher the debug level can be set.
End of procedure, call CLEANUP (not strictly necessary, because the next INIT call will set things appropriately)

    PROCEDURE get_widget(p_seq          int,
                        ,p_settlement   varchar2) IS
    BEGIN
       debug_info.init('Starting widget update');
       msg('p_seq       ='|| p_seq, p_debug_level=>1);
       msg('p_settlement='|| p_settlement, p_debug_level=>1);

       IF l_type = 'P' THEN
         msg('Updating for type P');
             FORALL i IN 1 .. l_blah.count
                UPDATE ...
                SET    
                WHERE  rowid = ...
         msg('- '||sql%rowcount);
       ELSIF l_type = 'Q' THEN
         msg('Updating for type Q');
             FORALL i IN 1 .. l_blah.count
                UPDATE ...
                SET    
                WHERE  rowid = ...
         msg('- '||sql%rowcount);
       END IF;

       debug_info.cleanup;

    END;


What's going on
================
Each time you call INIT, in effect we're calling DBMS_APPLICATION_INFO.SET_ACTION. 
(You could set a module as well if you wanted - for my last client they were setting module at a less granular level upstream, ie, not at the PLSQL level)

Each time you call MSG, the *default* action is:
- extract the procedure/function/etc name from DBMS_UTILITY.FORMAT_CALL_STACK
- record the routine name and passed message in a circular PL/SQL array (default is hold the last 1000 messages)

Other things that a call the MSG *might* do is:
- output the message via DBMS_OUTPUT
- log the message in the DEBUG_LOG table via autonomous transaction
See "flags" below for how this is controlled.

There is a global debug level (defaults to zero). Any passed debug level larger than the default level is ignored. In the example above, you can see we are NOT logging the passed parameters by default, but if we were to set the global default level to 1 (or more) then we WOULD log them. So you can choose your level of logging.


Statistics
==========
Each action passed into INIT also becomes an varchar2 index into a array. Every time you call that routine, the execution stats are incremented.  eg The example above might yield something like:

    Action                   Execution Count
    ----------------------   ---------------
    Starting widget update   123
    Some other procedure      76

Every hour, or every 10,000 calls to INIT, we dump the stats out to DEBUG_STATISTICS and start afresh


Flags
=====
Every 10 seconds (on the next call to MSG) it will do a check to see if its has been signalled from another session to CHANGE what style of logging it should be doing (amongst other things). In this way, you can change logging WITHOUT having to recompile a PL/SQL routine.

Examples of this are:

- ``debug_info.msg_control(sid, serial#, state=>TRUE)``
start logging MSG calls to DEBUG_LOG in the session running under sid/serial

- ``debug_info.msg_control(sid, serial#, p_dbms_output=>TRUE)``
start outputting MSG calls to DBMS_OUTPUT in the session running under sid/serial

- ``debug_info.msg_control(sid, serial#, p_history=>2000)``
change the 1000 msg history to 2000 rows in the PL/SQL array in the session running under sid/serial

- ``debug_info.msg_control(sid, serial#, p_debug_level=>1)``
change the default debug level to 1 (to pick up more MSG detail) in the session running under sid/serial

(In all cases, we are *still* logging the msg data to the PL/SQL array...We always do that).


Other routines
==============
- ``debug_info.reset_stack``
empty the PL/SQL array, can also be done for a different session (passing sid/serial)

- ``debug_info.flush_message_stack``
ask a session (in the next 10 seconds, see Flags above) to dump its current PL/SQL array to DEBUG_LOG

- ``debug_info.fatal``
dump the stack, plus anything else useful into the DEBUG_LOG table. Typically called if you're about crash a routine

- ``debug_info.flush_statistics``
ask a session to flush execution statistics to the DEBUG_STATISTICS table.


Notes
=======
1) Because this is just debugging code, whilst most of the functionality was rigorously tested, I can't guarantee that all of works exactly as specified. The biggest challenge was getting developers to embrace it all, so caveat emptor on usage. It *should* work fine, but responsibilty lies with you.  Having said that, I have no interest in licensing the code etc, so you are free to use, copy, modify etc with no implied ownership of my own, or any attribution required.

2) In very high frequency call environments, just the act of calling MSG *many* times can have a performance overhead. I had an example where a developer put dozens of MSG calls in a function that was ultimately being called from SQL statements against a table with millions of rows. Common sense should prevail!

