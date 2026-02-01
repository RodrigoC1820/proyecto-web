USE SafeZoneDB_Final_2026_Limpia;
GO

/* =========================================================
   1) TABLA DE AUDITORÍA
   ========================================================= */
IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditLog
    (
        AuditId     INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        EntityName  NVARCHAR(100) NOT NULL,      -- Ej: 'Alerts'
        EntityId    INT NULL,                    -- Ej: AlertId
        Action      NVARCHAR(10) NOT NULL,       -- INSERT/UPDATE/DELETE
        ChangedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_AuditLog_ChangedAt DEFAULT (SYSDATETIME()),
        ChangedBy   NVARCHAR(128) NULL,          -- opcional (puedes mandar desde la app)
        OldValues   NVARCHAR(MAX) NULL,          -- JSON antes
        NewValues   NVARCHAR(MAX) NULL           -- JSON después
    );

    CREATE INDEX IX_AuditLog_Entity ON dbo.AuditLog(EntityName, EntityId, ChangedAt DESC);
END
GO

/* =========================================================
   2) TRIGGER DE AUDITORÍA PARA dbo.Alerts
   ========================================================= */
IF OBJECT_ID('dbo.TR_Alerts_Audit', 'TR') IS NOT NULL
    DROP TRIGGER dbo.TR_Alerts_Audit;
GO

CREATE TRIGGER dbo.TR_Alerts_Audit
ON dbo.Alerts
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @changedBy NVARCHAR(128) = TRY_CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'ChangedBy'));

    /* ---------------------------
       INSERT (solo inserted)
       --------------------------- */
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
        SELECT
            N'Alerts' AS EntityName,
            i.AlertId AS EntityId,
            N'INSERT' AS Action,
            @changedBy AS ChangedBy,
            NULL AS OldValues,
            (
                SELECT
                    i.AlertId,
                    i.Title,
                    i.Description,
                    i.Severity,
                    i.OccurredAt,
                    i.CategoryId,
                    i.StatusId,
                    i.LocationId,
                    i.ReportedById,
                    i.IsVerified,
                    i.IsDeleted,
                    i.CreatedAt,
                    i.UpdatedAt
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS NewValues
        FROM inserted i;
    END

    /* ---------------------------
       DELETE (solo deleted)
       --------------------------- */
    IF EXISTS (SELECT 1 FROM deleted) AND NOT EXISTS (SELECT 1 FROM inserted)
    BEGIN
        INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
        SELECT
            N'Alerts' AS EntityName,
            d.AlertId AS EntityId,
            N'DELETE' AS Action,
            @changedBy AS ChangedBy,
            (
                SELECT
                    d.AlertId,
                    d.Title,
                    d.Description,
                    d.Severity,
                    d.OccurredAt,
                    d.CategoryId,
                    d.StatusId,
                    d.LocationId,
                    d.ReportedById,
                    d.IsVerified,
                    d.IsDeleted,
                    d.CreatedAt,
                    d.UpdatedAt
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS OldValues,
            NULL AS NewValues
        FROM deleted d;
    END

    /* ---------------------------
       UPDATE (inserted + deleted)
       --------------------------- */
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
        SELECT
            N'Alerts' AS EntityName,
            i.AlertId AS EntityId,
            N'UPDATE' AS Action,
            @changedBy AS ChangedBy,
            (
                SELECT
                    d.AlertId,
                    d.Title,
                    d.Description,
                    d.Severity,
                    d.OccurredAt,
                    d.CategoryId,
                    d.StatusId,
                    d.LocationId,
                    d.ReportedById,
                    d.IsVerified,
                    d.IsDeleted,
                    d.CreatedAt,
                    d.UpdatedAt
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS OldValues,
            (
                SELECT
                    i.AlertId,
                    i.Title,
                    i.Description,
                    i.Severity,
                    i.OccurredAt,
                    i.CategoryId,
                    i.StatusId,
                    i.LocationId,
                    i.ReportedById,
                    i.IsVerified,
                    i.IsDeleted,
                    i.CreatedAt,
                    i.UpdatedAt
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            ) AS NewValues
        FROM inserted i
        INNER JOIN deleted d ON d.AlertId = i.AlertId;
    END
END
GO

SELECT TOP 50 *
FROM dbo.AuditLog
WHERE EntityName = 'Alerts'
ORDER BY ChangedAt DESC, AuditId DESC;


