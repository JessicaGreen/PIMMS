---Select unique shelfmarks from a spreadsheet (de-duplicate), add an optional 'where' condition
---Combine unique shelfmarks from another spreadsheet using the 'union' keyword 
---The two 'shelfmark' columns should hold the same data, but may have different names - ie. Shelfmark vs. ms_shelfmark
--SELECT DISTINCT "Column1" FROM table1
--WHERE "Column2" = 'Specified value'
--UNION
--SELECT DISTINCT "Column 1" From table2;

SELECT DISTINCT Shelfmark FROM Analysis_AMEMM 
WHERE "Descriptive Metadata Source" = 'IAMS'
UNION
SELECT DISTINCT ms_shelfmark FROM Filemaker_AMEMM;


---Copy columns from source table into target table - the order of columns must line up/map correctly!
---Add 'where' conditions to only copy or 'insert' select rows from source table - like an Excel filter
--INSERT INTO target_table(target_column1, target_column2..)
--SELECT "Source column 1", 
--"Source column 2"..
--FROM source_table
--WHERE "Column name" = 'Specified value'
--AND/OR other conditions
--; 
INSERT INTO rights(shelfmark, system_num, project, dar_num, catalogue) 
SELECT Shelfmark, 
"System number", --Use double-quotes for column names with spaces, not needed without spaces
"Project (if part of a Project)", 
"DAR number", 
"Catalogued in Aleph or IAMS"
FROM source_Analysis_AAC 
WHERE Curator = 'Todd, Hamish' --Use single-quotes for 'strings' or text, in this case the value of a cell that column
--WHERE "In Sharepoint?" = 'No'
--WHERE "DAR number" = 'DAR 710'
AND "Source folder" LIKE '%AAS Storage%' --Use LIKE to add wildcards (%) to start and/or end of search term
--AND "Duplicate or Master?" = 'Master'
;

---Change or 'update' values in existing columns of target table based on 'where' conditions
---In this case, only update rows of target table where another column in that row contains a specified value
--UPDATE target_table 
--SET target_column = 'New value to insert'
--WHERE column_name = 'Specified value'
--; 
UPDATE rights
SET pub_unpub = 'Unpublished'
WHERE catalogue = 'IAMS'
;

UPDATE rights
SET pub_unpub = 'Published'
WHERE catalogue = 'Aleph'
;

UPDATE rights
SET uk_india_sa=(
CASE WHEN origin_country LIKE '%India%' THEN 'Yes'
WHEN origin_country LIKE '%United Kingdom%' THEN 'Yes'
WHEN origin_country LIKE '%South Africa%' THEN 'Yes'
WHEN origin_country IS NULL THEN 'Unknown'
ELSE 'No'
END);

---Change or 'update' values in existing columns of target table based data in another table
---In this case, only update rows of target table where the values of a source column match the values of a target column (e.g. shelfmark)
---And only update rows where the values of a column are greater than >, less than <, and/or equal = to a number (e.g. creation date)
--UPDATE target_table 
--SET target_column1 = 
--(SELECT t2."Source column 1" FROM source_table t2 --Assign the source table a shorter nickname, like t2 for table2
--WHERE t2."Source column 2" = target_table.target_column2
--AND/OR t2."Source column 1" is greater than or equal to a number) --Don't add quotes around numbers to do calculations
--;
UPDATE analysis
SET creation_date = 
(SELECT iams."End date" FROM source_IAMS_AAC iams 
WHERE iams."Record reference" = rights.shelfmark)
--AND iams."End date" >= 1900)
;

--Update the publication country column based on data in Aleph, then update country codes using mapping table
--The 008 field in Aleph includes spaces after some of the country codes. Use TRIM() to remove any spaces after the text. This should probably be applied to all data being pulled in from Aleph to be safe, and additional characters like ; can also be included. https://www.sqlitetutorial.net/sqlite-functions/sqlite-trim
UPDATE rights 
SET pub_country = 
(SELECT TRIM(source_Aleph_AAC."008 15-3 # 15-17 - Place of publication, production, or execution ") 
FROM source_Aleph_AAC
WHERE source_Aleph_AAC."001 # Control Number " = rights.system_num)
;

 UPDATE rights 
    SET pub_country = 
    (SELECT country_name FROM country_codes
    WHERE country_codes.country_code = rights.pub_country);
	
--Group results on image files based on common folders, this can then be joined with folder-level analysis spreadsheets
WITH files_and_paths AS (
	SELECT FILE_PATH, REPLACE(FILE_PATH, NAME, '') AS 'Path', 
	NAME, SIZE FROM source_AAC_Siegfried_201908
	LIMIT 10000
) SELECT Path, SUM(SIZE) AS folder_size, COUNT(NAME) AS num_files FROM files_and_paths
GROUP BY Path

---View or 'select' specific columns from a table
---Define the order of columns to view and rename them using 'as' clause
---Filter using 'where' conditions and sort columns using 'order by' clause
--SELECT column1 AS 'New Column Name 1', 
--column3  || 'semicolon + space' || column2 AS 'New Column Name 2', --Concatenate columns and add symbol/space between values
--column4 AS 'New Column Name 3'
--FROM table
--WHERE column4 is greater than a number
--AND/OR other conditions
--ORDER BY 'New Column Name 2'
--;
SELECT shelfmark AS Shelfmark,
dar_num || '; ' || project AS Project, 
pub_unpub AS 'Pubished or Unpublished',
pub_date AS 'Publication date - Aleph',
creation_date AS 'Creation date - IAMS'
FROM rights
WHERE pub_date > 1900
OR creation_date > 1900
ORDER BY Project
--ORDER BY "Publication date - Aleph" DESC --Sort numbers in descending order using 'desc' keyword
--ORDER BY "Creation date - IAMS" ASC --Or sort in ascending order using 'asc' keyword
;
