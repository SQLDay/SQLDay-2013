use tempdb;
GO
create table dbo.t_log1 (i int identity primary key);
GO
create table dbo.insert_table (data int);
GO
create procedure dbo.insert_exec_proc @dzielnik int = 1
as
set nocount on
begin
  insert into t_log1 default values;
  select 100/@dzielnik as d;
end;
GO
-- prosty przypadek
insert into dbo.insert_table (data) exec dbo.insert_exec_proc 1;
select * from dbo.t_log1;
select * from dbo.insert_Table; 

GO
-- wyj¹tek, oczekiwany rollback
insert into dbo.insert_table (data) exec dbo.insert_exec_proc 0;
select * from dbo.t_log1; -- jeœli procedura by³a w transakcji, to nie powinno byæ drugiego wpisu
select * from dbo.insert_Table; 

GO
-- i jeszcze select..into


select 
   1/(object_id-20) pulapka, 
   * 
   into dbo.temp_objects 
   from sys.objects where object_id between 1 and 100;
GO
exec sp_help 'dbo.temp_objects';
select * from dbo.temp_objects;

--
begin tran
exec as login = 'sa'
select suser_sname()
rollback tran
select suser_sname()

-- czyszczenie
if object_id('dbo.t_log1') is not null drop table dbo.t_log1;
if object_id('dbo.insert_table') is not null drop table dbo.insert_table;
if object_id('dbo.insert_exec_proc') is not null drop procedure dbo.insert_exec_proc;
if object_id('dbo.temp_objects') is not null drop table dbo.temp_objects;
