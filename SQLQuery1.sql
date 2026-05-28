USE AcidentesAereosBrasil;
GO

CREATE SCHEMA eda;
GO



CREATE OR ALTER PROCEDURE eda.usp_analise_geral
	@schema_name SYSNAME,
	@table_name SYSNAME,
	@column_name SYSNAME,
	@tipo_analitico VARCHAR(50),
	@top_n INT = 30,
	@nax_edit_distance INT = 3
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE
		@sql NVARCHAR(MAX);
		@full_table_name NVARCHAR(256) = QUOTENAME(@schema_name) + '.' + QUOTENAME(@table_name);
		@object_id INT = OBJECT_ID(@full_table_name);

	IF @object_id IS NULL
	BEGIN
		RAISERROR('A tabela especificada não existe: %s.%s', 16, 1, @schema_name, @table_name);
		RETURN;
	END

	IF NOT EXISTS (
	SELECT 1 
	FROM sys.columns 
	WHERE object_id = @object_id AND name = @column_name
	)
	BEGIN
		RAISERROR('A coluna especificada não existe na tabela: %s.%s', 16, 1, @full_table_name);
		RETURN;
	END


	SET @sql = N'
			SELCT
				''' @schema_name + '.' + @table_name + ''' AS tabela,
				''' + @column_name + ''' AS coluna,
				'''UPPER(@tipo_analitico) + ''' AS tipo_analitico,
				COUBT(*) AS LINHAS,
				SUM(
					CASE
						WHEN '+ QUOTENAME(@column_name) + ' IS NULL THEN 1
						WHEN '+ QUOTENAME(@column_name) + ' = '''' THEN 1
						ELSE 0
					END
				) AS LINHAS_VAZIAS,
				CAST(
				ROUND(
					(CAST(SUM(
						CASE
							WHEN '+ QUOTENAME(@column_name) + ' IS NULL THEN 1
							WHEN '+ QUOTENAME(@column_name) + ' = '''' THEN 1
							ELSE 0
						END
					) AS FLOAT) / COUNT(*)) * 100, 2) AS PERCENTUAL_VAZIO
			FROM ' + @full_table_name + ';';

	EXEC sp_executesql @sql;


	IF UPPER(@tipo_analitico) = 'CATEGORICA'
	BEGIN
		SET @sql = N'
			SELECT TOP ' + CAST(@top_n AS NVARCHAR(10)) + '
				''' + @schema_name + '.' + @table_name + ''' AS tabela,
				''' + @column_name + ''' AS coluna,
				'''UPPER(@tipo_analitico) + ''' AS tipo_analitico,
				CAST('+ QUOTENAME(@column_name) +' AS NVARCHAR(255)) AS valor,
				COUNT(*) AS frequencia
			FROM ' + @full_table_name + '
			WHERE '+ QUOTENAME(@column_name) +' IS NOT NULL AND '+ QUOTENAME(@column_name) +' <> ''''
			GROUP BY '+ QUOTENAME(@column_name) +'
			ORDER BY frequencia DESC;';
		
		EXEC sp_executesql @sql;
	END


	EXEC sp_executesql @sql;

	SET 