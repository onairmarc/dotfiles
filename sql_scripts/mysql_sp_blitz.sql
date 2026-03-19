DELIMITER //

DROP PROCEDURE IF EXISTS sp_Blitz//

CREATE PROCEDURE sp_Blitz(
    IN p_Help TINYINT,
    IN p_CheckUserDatabaseObjects TINYINT,
    IN p_CheckProcedureCache TINYINT,
    IN p_OutputType VARCHAR(20),
    IN p_OutputProcedureCache TINYINT,
    IN p_CheckProcedureCacheFilter VARCHAR(10),
    IN p_CheckServerInfo TINYINT,
    IN p_SkipChecksServer TEXT,
    IN p_SkipChecksDatabase TEXT,
    IN p_SkipChecksSchema TEXT,
    IN p_IgnorePrioritiesBelow INT,
    IN p_IgnorePrioritiesAbove INT,
    IN p_BringThePain TINYINT,
    IN p_VersionDate DATETIME,
    IN p_VersionCheckMode TINYINT,
    IN p_DatabaseName VARCHAR(128)
)
    READS SQL DATA
    DETERMINISTIC
    COMMENT 'MySQL conversion of sp_Blitz - Database Health Check Tool'

proc_label:
BEGIN
    DECLARE v_Version VARCHAR(29);
    DECLARE v_VersionDate DATETIME;
    DECLARE v_VersionCheckMode TINYINT DEFAULT 0;
    DECLARE v_OutputType VARCHAR(20);
    DECLARE v_StringToExecute TEXT;
    DECLARE v_ObjectName VARCHAR(128);
    DECLARE v_CheckID INT;
    DECLARE v_DatabaseName VARCHAR(128);
    DECLARE v_Priority SMALLINT;
    DECLARE v_FindingsGroup VARCHAR(50);
    DECLARE v_Finding VARCHAR(200);
    DECLARE v_URL VARCHAR(200);
    DECLARE v_Details TEXT;

    SET p_Help = COALESCE(p_Help, 0);
    SET p_CheckUserDatabaseObjects = COALESCE(p_CheckUserDatabaseObjects, 1);
    SET p_CheckProcedureCache = COALESCE(p_CheckProcedureCache, 0);
    SET p_OutputType = COALESCE(p_OutputType, 'TABLE');
    SET p_OutputProcedureCache = COALESCE(p_OutputProcedureCache, 0);
    SET p_CheckServerInfo = COALESCE(p_CheckServerInfo, 0);
    SET p_BringThePain = COALESCE(p_BringThePain, 0);
    SET p_VersionCheckMode = COALESCE(p_VersionCheckMode, 0);

    DROP TEMPORARY TABLE IF EXISTS BlitzResults;
    CREATE TEMPORARY TABLE BlitzResults
    (
        ID                INT AUTO_INCREMENT PRIMARY KEY,
        CheckID           INT,
        DatabaseName      VARCHAR(128),
        Priority          SMALLINT,
        FindingsGroup     VARCHAR(50),
        Finding           VARCHAR(200),
        URL               VARCHAR(200),
        Details           TEXT,
        HowToStopIt       TEXT,
        QueryPlan         TEXT,
        QueryPlanFiltered LONGTEXT
    );

    SET v_Version = '8.15 - November 6, 2023';
    SET v_VersionDate = '20231106';
    SET v_OutputType = p_OutputType;

    IF p_Help = 1 THEN
        SELECT 'sp_Blitz MySQL Version'                  AS Parameter,
               'For more info visit brentozar.com/blitz' AS Description
        UNION ALL
        SELECT 'CheckUserDatabaseObjects', 'Set to 0 to skip user database checks'
        UNION ALL
        SELECT 'CheckProcedureCache', 'Set to 1 to analyze procedure cache (NOT AVAILABLE IN MYSQL)'
        UNION ALL
        SELECT 'OutputType', 'TABLE, COUNT, or CSV output format'
        UNION ALL
        SELECT 'CheckServerInfo', 'Set to 1 to show server configuration info'
        UNION ALL
        SELECT 'DatabaseName', 'Filter results to specific database/schema name';

        DROP TEMPORARY TABLE BlitzResults;
        LEAVE proc_label;
    END IF;

    IF p_CheckServerInfo = 1 THEN
        INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (-1, 254, 'Informational', 'MySQL Server Version', 'brentozar.com/blitz', CONCAT('MySQL Version: ', VERSION()));

        INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
        VALUES (-2, 254, 'Informational', 'MySQL Configuration', 'brentozar.com/blitz',
                CONCAT('Max Connections: ', @@max_connections, ', InnoDB Buffer Pool Size: ', @@innodb_buffer_pool_size));
    END IF;

    INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 1                                                                                                             AS CheckID,
           SCHEMA_NAME                                                                                                   AS DatabaseName,
           1                                                                                                             AS Priority,
           'Backup'                                                                                                      AS FindingsGroup,
           'No Recent Backup Information Available'                                                                      AS Finding,
           'brentozar.com/blitz'                                                                                         AS URL,
           'MySQL does not track backup history in system tables like SQL Server. Implement external backup monitoring.' AS Details
    FROM information_schema.SCHEMATA
    WHERE SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
      AND p_CheckUserDatabaseObjects = 1
      AND (p_DatabaseName IS NULL OR SCHEMA_NAME = p_DatabaseName);

    INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 2                           AS CheckID,
           s.SCHEMA_NAME               AS DatabaseName,
           50                          AS Priority,
           'Reliability'               AS FindingsGroup,
           'Database Size Information' AS Finding,
           'brentozar.com/blitz'       AS URL,
           CONCAT('Schema: ', s.SCHEMA_NAME,
                  ' - Total Size: ',
                  ROUND(SUM(COALESCE(t.DATA_LENGTH + t.INDEX_LENGTH, 0)) / 1024 / 1024, 2),
                  ' MB')               AS Details
    FROM information_schema.SCHEMATA s
             LEFT JOIN information_schema.TABLES t ON s.SCHEMA_NAME = t.TABLE_SCHEMA
    WHERE s.SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
      AND p_CheckUserDatabaseObjects = 1
      AND (p_DatabaseName IS NULL OR s.SCHEMA_NAME = p_DatabaseName)
    GROUP BY s.SCHEMA_NAME
    HAVING SUM(COALESCE(t.DATA_LENGTH + t.INDEX_LENGTH, 0)) > 1073741824;

    INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 3                                                                AS CheckID,
           kcu.TABLE_SCHEMA                                                 AS DatabaseName,
           10                                                               AS Priority,
           'Performance'                                                    AS FindingsGroup,
           'Foreign Key Without Index'                                      AS Finding,
           'brentozar.com/blitz'                                            AS URL,
           CONCAT('Table: ', kcu.TABLE_NAME, ', Column: ', kcu.COLUMN_NAME) AS Details
    FROM information_schema.KEY_COLUMN_USAGE kcu
    WHERE kcu.REFERENCED_TABLE_NAME IS NOT NULL
      AND kcu.TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
      AND (p_DatabaseName IS NULL OR kcu.TABLE_SCHEMA = p_DatabaseName)
      AND NOT EXISTS (SELECT 1
                      FROM information_schema.STATISTICS s
                      WHERE s.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                        AND s.TABLE_NAME = kcu.TABLE_NAME
                        AND s.COLUMN_NAME = kcu.COLUMN_NAME
                        AND s.SEQ_IN_INDEX = 1)
      AND p_CheckUserDatabaseObjects = 1;

    IF (SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = 'performance_schema'
          AND table_name = 'table_io_waits_summary_by_index_usage') > 0 THEN

        INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
        SELECT 4                                                          AS CheckID,
               s.TABLE_SCHEMA                                             AS DatabaseName,
               10                                                         AS Priority,
               'Performance'                                              AS FindingsGroup,
               'Potentially Unused Index'                                 AS Finding,
               'brentozar.com/blitz'                                      AS URL,
               CONCAT('Table: ', s.TABLE_NAME, ', Index: ', s.INDEX_NAME) AS Details
        FROM information_schema.STATISTICS s
                 LEFT JOIN performance_schema.table_io_waits_summary_by_index_usage p
                           ON s.TABLE_SCHEMA = p.OBJECT_SCHEMA
                               AND s.TABLE_NAME = p.OBJECT_NAME
                               AND s.INDEX_NAME = p.INDEX_NAME
        WHERE s.TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
          AND s.INDEX_NAME != 'PRIMARY'
          AND (p.COUNT_STAR IS NULL OR p.COUNT_STAR = 0)
          AND (p_DatabaseName IS NULL OR s.TABLE_SCHEMA = p_DatabaseName)
          AND p_CheckUserDatabaseObjects = 1;
    END IF;

    INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 5                                                                                   AS CheckID,
           TABLE_SCHEMA                                                                        AS DatabaseName,
           20                                                                                  AS Priority,
           'Reliability'                                                                       AS FindingsGroup,
           'MyISAM Storage Engine'                                                             AS Finding,
           'brentozar.com/blitz'                                                               AS URL,
           CONCAT('Table: ', TABLE_NAME, ' uses MyISAM engine - consider migrating to InnoDB') AS Details
    FROM information_schema.TABLES
    WHERE ENGINE = 'MyISAM'
      AND TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
      AND (p_DatabaseName IS NULL OR TABLE_SCHEMA = p_DatabaseName)
      AND p_CheckUserDatabaseObjects = 1;

    INSERT INTO BlitzResults (CheckID, DatabaseName, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 6                                                      AS CheckID,
           t.TABLE_SCHEMA                                         AS DatabaseName,
           10                                                     AS Priority,
           'Performance'                                          AS FindingsGroup,
           'Table Without Primary Key'                            AS Finding,
           'brentozar.com/blitz'                                  AS URL,
           CONCAT('Table: ', t.TABLE_NAME, ' has no primary key') AS Details
    FROM information_schema.TABLES t
             LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu
                       ON t.TABLE_SCHEMA = kcu.TABLE_SCHEMA
                           AND t.TABLE_NAME = kcu.TABLE_NAME
                           AND kcu.CONSTRAINT_NAME = 'PRIMARY'
    WHERE t.TABLE_TYPE = 'BASE TABLE'
      AND t.TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
      AND kcu.TABLE_NAME IS NULL
      AND (p_DatabaseName IS NULL OR t.TABLE_SCHEMA = p_DatabaseName)
      AND p_CheckUserDatabaseObjects = 1;

    INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 7                                                  AS CheckID,
           100                                                AS Priority,
           'Monitoring'                                       AS FindingsGroup,
           'Slow Query Log Disabled'                          AS Finding,
           'brentozar.com/blitz'                              AS URL,
           'Enable slow query log for performance monitoring' AS Details
    WHERE @@slow_query_log = 0;

    INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 8                       AS CheckID,
           50                      AS Priority,
           'Backup'                AS FindingsGroup,
           'Binary Logging Status' AS Finding,
           'brentozar.com/blitz'   AS URL,
           CASE
               WHEN @@log_bin = 1 THEN 'Binary logging is enabled - good for point-in-time recovery'
               ELSE 'Binary logging is disabled - consider enabling for backup and replication'
               END                 AS Details;

    INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    SELECT 9                                               AS CheckID,
           20                                              AS Priority,
           'Performance'                                   AS FindingsGroup,
           'InnoDB Buffer Pool Size'                       AS Finding,
           'brentozar.com/blitz'                           AS URL,
           CONCAT('Current size: ',
                  ROUND(@@innodb_buffer_pool_size / 1024 / 1024 / 1024, 1),
                  'GB - Consider 70-80% of available RAM') AS Details
    WHERE @@innodb_buffer_pool_size < 134217728;

    INSERT INTO BlitzResults (CheckID, Priority, FindingsGroup, Finding, URL, Details)
    VALUES (999, 254, 'Informational', 'Conversion Notes', 'brentozar.com/blitz',
            'Many SQL Server specific checks cannot be converted to MySQL including DMV queries, wait stats analysis, procedure cache analysis, SQL Server specific
       configuration checks, trace flags, and Windows-specific features.');

    DELETE
    FROM BlitzResults
    WHERE (p_IgnorePrioritiesBelow IS NOT NULL AND Priority > p_IgnorePrioritiesBelow)
       OR (p_IgnorePrioritiesAbove IS NOT NULL AND Priority < p_IgnorePrioritiesAbove);

    IF v_OutputType = 'COUNT' THEN
        SELECT COUNT(*) AS BlitzChecks FROM BlitzResults;
    ELSEIF v_OutputType = 'CSV' THEN
        SELECT CONCAT(
                       COALESCE(CheckID, ''), ',',
                       COALESCE(DatabaseName, ''), ',',
                       COALESCE(Priority, ''), ',',
                       COALESCE(REPLACE(FindingsGroup, ',', ' '), ''), ',',
                       COALESCE(REPLACE(Finding, ',', ' '), ''), ',',
                       COALESCE(REPLACE(Details, ',', ' '), '')
               ) AS CSV_Output
        FROM BlitzResults
        ORDER BY Priority, CheckID;
    ELSE
        SELECT CheckID,
               DatabaseName,
               Priority,
               FindingsGroup,
               Finding,
               URL,
               Details
        FROM BlitzResults
        ORDER BY Priority, CheckID;
    END IF;

    DROP TEMPORARY TABLE BlitzResults;

END//

DELIMITER ;