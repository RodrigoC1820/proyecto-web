USE SafeZoneDB_Final_2026_Limpia;
GO

IF OBJECT_ID('dbo.vw_AlertsFull', 'V') IS NOT NULL
    DROP VIEW dbo.vw_AlertsFull;
GO

CREATE VIEW dbo.vw_AlertsFull
AS
SELECT
    a.AlertId,
    a.Title,
    a.Description,
    a.Severity,
    CASE 
        WHEN a.Severity BETWEEN 1 AND 2 THEN 'Baja'
        WHEN a.Severity = 3 THEN 'Media'
        WHEN a.Severity BETWEEN 4 AND 5 THEN 'Alta'
        ELSE 'No definida'
    END AS SeverityText,

    a.OccurredAt,
    a.CreatedAt,
    a.UpdatedAt,

    a.IsVerified,
    a.IsDeleted,

    -- Categoria
    a.CategoryId,
    c.CategoryName,

    -- Estado
    a.StatusId,
    s.StatusName,

    -- Ubicación
    a.LocationId,
    l.Sector AS LocationSector,
    l.Description AS LocationDescription,

    -- Reportado por (usuario)
    a.ReportedById,
    u.FullName AS ReportedByName,
    u.Email AS ReportedByEmail

FROM dbo.Alerts a
LEFT JOIN dbo.AlertCategories c ON c.CategoryId = a.CategoryId
LEFT JOIN dbo.AlertStatuses  s ON s.StatusId   = a.StatusId
LEFT JOIN dbo.Locations      l ON l.LocationId = a.LocationId
LEFT JOIN dbo.Users          u ON u.UserId     = a.ReportedById;
GO


--1) Ver todo consolidado
SELECT TOP 50 *
FROM dbo.vw_AlertsFull
ORDER BY CreatedAt DESC;
--2) Ver solo activas (no eliminadas)
SELECT *
FROM dbo.vw_AlertsFull
WHERE ISNULL(IsDeleted, 0) = 0
ORDER BY OccurredAt DESC;
--3) Filtrar por sector (ejemplo “Terminal Terrestre”)
SELECT *
FROM dbo.vw_AlertsFull
WHERE LocationSector LIKE '%Terminal%'
ORDER BY OccurredAt DESC;


-- FKs frecuentes
CREATE INDEX IX_Alerts_CategoryId   ON dbo.Alerts(CategoryId);
CREATE INDEX IX_Alerts_StatusId     ON dbo.Alerts(StatusId);
CREATE INDEX IX_Alerts_LocationId   ON dbo.Alerts(LocationId);
CREATE INDEX IX_Alerts_ReportedById ON dbo.Alerts(ReportedById);

-- Orden/filtrado común
CREATE INDEX IX_Alerts_CreatedAt    ON dbo.Alerts(CreatedAt DESC);
