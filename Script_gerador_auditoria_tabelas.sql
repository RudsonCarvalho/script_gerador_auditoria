-- GERADOR DE TABELA DE AUDITORIA E TRIGGERS PARA LOGS DE TABELAS

 - - - - - - - - - - - - - - - - - - - - - - - - - - - 

DECLARE @table VARCHAR(100), @schema VARCHAR(100), @generateScriptOnly BIT

-- TABELAS PARA AUDITORIA
SET @schema = 'dbo'
SET @table = 'teste'

-- Set @generateScriptOnly = 1 PARA GERAR UM SCRIPT PARA RODAR POSTERIORMENTE
SET @generateScriptOnly = 1

------------------------------------------------------------------------------
-- CRIAR _Audit table
------------------------------------------------------------------------------

DECLARE @crlf CHAR(2), @sql NVARCHAR(MAX)
SET @crlf = CHAR(10)

SET @sql = '
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[' + @schema + '].[_' + @table + '_Audit]'') AND type in (N''U''))
	DROP TABLE [' + @schema + '].[_' + @table + '_Audit]'

PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

set @sql = 'CREATE TABLE [' + @schema + '].[_' + @table + '_Audit]
(' + @crlf

DECLARE
	@columnID INT,
	@columnName VARCHAR(MAX),
	@columnType VARCHAR(MAX),
	@columnSize INT,
	@done BIT

SET @columnID = 0
SET @done = 0

WHILE @done = 0   
BEGIN            
    SELECT TOP 1
		@columnID = c.column_id,
		@columnName = c.name,
		@columnType = ut.name,
		@columnSize = CAST(
			CASE
				WHEN bt.name IN (N'nchar', N'nvarchar') AND c.max_length != -1
				THEN c.max_length/2
				ELSE c.max_length
			END
			AS INT)
    FROM
		sys.tables t
		INNER JOIN sys.all_columns c ON
			c.object_id = t.object_id
		LEFT JOIN sys.types AS ut ON
			ut.user_type_id = c.user_type_id
		LEFT JOIN sys.types AS bt ON
			bt.user_type_id = c.system_type_id 
			AND bt.user_type_id = bt.system_type_id
    WHERE
		(t.name = @table AND SCHEMA_NAME(t.schema_id) = @schema)
		AND c.column_id > @columnID
	ORDER BY
		c.column_id

    IF @@ROWCOUNT = 0   
		SET @done = 1
    ELSE
    BEGIN
        SET @sql = @sql + '	[' + @columnName + '] [' + @columnType + ']'
        IF @columnType IN ('varchar', 'nvarchar')
			IF @columnSize = -1
				SET @sql = @sql + '(MAX)'
			ELSE
				SET @sql = @sql + '('+LTRIM(STR(@columnSize)) + ')'
        SET @sql = @sql + ' NULL, ' + @crlf
    END
END

SET @sql = @sql + '	[Audit_Command] [varchar](20),
	[Audit_TimeStamp] [datetime],
	[Audit_SystemUser] [nvarchar](255)
)'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

------------------------------------------------------------------------------
-- Create UPDATE trigger
------------------------------------------------------------------------------

SET @sql = 'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[' + @schema + '].[_' + @table + '_AuditOnUpdate]''))
	DROP TRIGGER [' + @schema + '].[_' + @table + '_AuditOnUpdate]'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

set @sql = 'CREATE TRIGGER [_' + @table + '_AuditOnUpdate] 
   ON  ['+@schema+'].['+@table+'] 
   AFTER UPDATE
AS 
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO [' + @schema + '].[_' + @table + '_Audit]
    SELECT
		*,
		''UPDATE'',
		GETDATE(),
		system_user
	FROM
		Inserted
END'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

------------------------------------------------------------------------------
-- Create INSERT trigger
------------------------------------------------------------------------------

SET @sql = 'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[' + @schema + '].[_' + @table + '_AuditOnInsert]''))
	DROP TRIGGER [' + @schema + '].[_' + @table + '_AuditOnInsert]'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

set @sql = 'CREATE TRIGGER [_'+@table+'_AuditOnInsert] 
   ON  ['+@schema+'].['+@table+'] 
   AFTER INSERT
AS 
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO [' + @schema + '].[_' + @table + '_Audit]
    SELECT
		*,
		''INSERT'',
		GETDATE(),
		system_user
	FROM
		Inserted
END'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

------------------------------------------------------------------------------
-- Create DELETE trigger
------------------------------------------------------------------------------

SET @sql = 'IF  EXISTS (SELECT * FROM sys.triggers WHERE object_id = OBJECT_ID(N''[' + @schema + '].[_' + @table + '_AuditOnDelete]''))
	DROP TRIGGER [' + @schema + '].[_' + @table + '_AuditOnDelete]'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

set @sql = 'CREATE TRIGGER [_'+@table+'_AuditOnDelete] 
   ON  ['+@schema+'].['+@table+'] 
   AFTER DELETE
AS 
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO [' + @schema + '].[_' + @table + '_Audit]
    SELECT
		*,
		''DELETE'',
		GETDATE(),
		system_user
	FROM
		DELETED
END'
PRINT @sql
IF @generateScriptOnly != 1 EXEC sp_executesql @sql ELSE PRINT 'GO' + @crlf

-- End