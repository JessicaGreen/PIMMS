---Analyze Siegfried/DROID report by grouping technical metadata about each of the files (tif, xml, etc.) within a folder 
---Image files (tiff, jpg) represent one  digitized page of an item, each folder contains one or more files that represent one physical item
---The Siegfried/DROID report contains one row per file, but most other data sources have one row per folder/item
---Save this output as new csv file - relevant columns can then be joined and analyzed with folder-level analysis spreadsheets
WITH files_and_paths AS (
	SELECT FILE_PATH, substr(FILE_PATH, 1, length(FILE_PATH) - length(NAME) - 1) AS FOLDER_PATH, --substr() removes the file name and trailing \ from the file path by calculating: (length of file name) - (length of file path) - 1 
	NAME, 
	CASE WHEN upper(EXT) = 'TIF' OR upper(EXT) = 'TIFF' THEN NAME --these CASE WHEN statements limits results to only files with matching file extensions or file names and creates new filtered columns to use below - in this case XML_NAMES
	ELSE NULL END TIF_NAME,
	CASE WHEN upper(NAME) NOT LIKE '%CONTROL%' THEN NAME --limits COUNT to only file names not containing the word 'control' - case insensitive using upper()
	ELSE NULL END CONTROL_NAME,
	CASE WHEN upper(EXT) = 'XML' THEN NAME --upper() makes it possible to do a case insensitive match for 'tif' or 'TIFF' - it normalising the data in the extension column by making it all uppercase, then has to check for only uppercase matches
	ELSE NULL END XML_NAME,
	coalesce(SIZE, 0) AS SIZE, --coalesce() replaces any null value in the size column with '0' to make calculations possible
	CASE WHEN upper(EXT) = 'TIF' OR upper(EXT) = 'TIFF' THEN coalesce(SIZE, 0)
	ELSE 0 END TIF_SIZE,
	CASE WHEN upper(EXT) = 'XML' THEN coalesce(SIZE, 0)
	ELSE 0 END XML_SIZE,
	CASE WHEN coalesce(SIZE, 0) < 20480 AND (upper(EXT) = 'TIFF' OR upper(EXT) = 'TIF') THEN NAME --SIZE is calculated in bytes - divide by 1024 to convert to KB, 1024/1024 to MB, etc.
	ELSE NULL END SMALL_TIF_NAME,
	EXT, EXTENSION_MISMATCH, 
	CASE WHEN STATUS <> 'Done' THEN STATUS ELSE NULL END ERRORS --renames STATUS column ERRORS and limits values to only those with errors
	FROM source_AAC_Siegfried_201908
	--WHERE EXT = 'xml' OR EXT = 'tif' --limits the results of the whole query by only testing on a subset of the data - helpful to test results of new queries
	--WHERE STATUS <> 'Done' --limits results by only folders that have files with errors
	LIMIT 100000) 
SELECT FOLDER_PATH AS "Absolute folder path",
SUM(SIZE)/1024/1024 AS "Total file size (MB)", --calculates total folder size by summing SIZE of all files, divides the SIZE by 1024 twice to convert B to MB
SUM(SIZE) AS "Total file size (B)", 
SUM(TIF_SIZE + XML_SIZE) AS "Size of tif and xml files (B)",
SUM(TIF_SIZE) AS "Size of tif files (B)",
SUM(XML_SIZE) AS "Size of xml files (B)",
COUNT(NAME) AS "Number of files",
COUNT(TIF_NAME) + COUNT(XML_NAME) AS "Number of tif and xml files",
COUNT(TIF_NAME) AS "Number of tif files", --only calculates number of files with the tif or tiff file extensions - uses new TIF_NAMES column created above
COUNT(TIF_NAME - CONTROL_NAME) AS "Number of tif files (excl. control shots)", 
COUNT(XML_NAME) AS "Number of xml files",
replace(group_concat(DISTINCT EXT), ',', '; ') AS  "File extensions", --concatenates all file extensions in folder and replaces default comma seperators with a semi-colon and space
(SELECT group_concat(NAME, '; ') WHERE EXTENSION_MISMATCH = 'TRUE') AS "File extension mismatches", --concatenates all file names in folder where there is an extension mismatch - file type doesn't match file extension
replace(group_concat(DISTINCT ERRORS), ',', '; ') AS "Errors",
replace(group_concat(DISTINCT SMALL_TIF_NAME), ',', '; ') AS "Tif files under 20 KB"
FROM files_and_paths
GROUP BY "Absolute folder path";