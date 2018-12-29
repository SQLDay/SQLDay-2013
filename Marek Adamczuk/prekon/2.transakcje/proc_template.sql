create procedure dbo.proc_template
as
begin
  DECLARE @TranCnt int = @@TRANCOUNT;
  DECLARE @SavePoint varchar(40) SET @SavePoint = REPLACE(CONVERT(VARCHAR(36),NEWID()),'-','');
  IF @TranCnt = 0 BEGIN TRAN; 
  SAVE TRAN @SavePoint;
  
  -- tu cia³o procedury
  IF @@ERROR <> 0 GOTO END_ROLLBACK;

  IF @TranCnt = 0 AND @@TRANCOUNT > 0 COMMIT TRAN;
  RETURN 0;
  END_ROLLBACK:
  IF @@TRANCOUNT > 0 ROLLBACK TRAN @SavePoint;
  IF @TranCnt = 0 AND @@TRANCOUNT > 0 ROLLBACK TRAN;
  RETURN -1; 
end;