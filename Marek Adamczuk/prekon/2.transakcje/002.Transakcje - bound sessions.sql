GO
begin tran
declare @Token varchar(128)
exec sp_getbindtoken @Token out
select @Token
GO
select @@trancount
GO
-- drugie connection
sp_bindsession 'T_NG_J5_0Q7:7RL;0Ubjh=5----ZBM--'
GO
rollback tran
GO