/* =========================================================
   SAFEZONE - BD FINAL LIMPIA (SQL Server)
   - PK, FK, UNIQUE, CHECK, Índices
   - Vistas
   - Stored Procedures CRUD
   - Triggers de Auditoría
   ========================================================= */

-- 0) Crear BD limpia
IF DB_ID('SafeZoneDB_Final_2026_Limpia') IS NOT NULL
BEGIN
    ALTER DATABASE SafeZoneDB_Final_2026_Limpia SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE SafeZoneDB_Final_2026_Limpia;
END
GO

CREATE DATABASE SafeZoneDB_Final_2026_Limpia;
GO
USE SafeZoneDB_Final_2026_Limpia;
GO

/* =========================================================
   1) TABLAS MAESTRAS (Catálogos)
   ========================================================= */

-- Roles
CREATE TABLE dbo.Roles (
    RoleId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    RoleName    NVARCHAR(50) NOT NULL,
    CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_Roles_CreatedAt DEFAULT (SYSDATETIME())
);
GO
ALTER TABLE dbo.Roles
ADD CONSTRAINT UQ_Roles_RoleName UNIQUE (RoleName);
GO

-- Users
CREATE TABLE dbo.Users (
    UserId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
    RoleId      INT NOT NULL,
    FullName    NVARCHAR(120) NOT NULL,
    Email       NVARCHAR(160) NOT NULL,
    Phone       NVARCHAR(30) NULL,
    IsActive    BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
    CreatedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT (SYSDATETIME()),
    UpdatedAt   DATETIME2(0) NULL
);
GO
ALTER TABLE dbo.Users
ADD CONSTRAINT UQ_Users_Email UNIQUE (Email);
GO
ALTER TABLE dbo.Users
ADD CONSTRAINT FK_Users_Roles
FOREIGN KEY (RoleId) REFERENCES dbo.Roles(RoleId);
GO

-- AlertCategories
CREATE TABLE dbo.AlertCategories (
    CategoryId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertCategories PRIMARY KEY,
    CategoryName NVARCHAR(80) NOT NULL,
    IsActive     BIT NOT NULL CONSTRAINT DF_AlertCategories_IsActive DEFAULT (1),
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_AlertCategories_CreatedAt DEFAULT (SYSDATETIME())
);
GO
ALTER TABLE dbo.AlertCategories
ADD CONSTRAINT UQ_AlertCategories_CategoryName UNIQUE (CategoryName);
GO

-- AlertStatuses
CREATE TABLE dbo.AlertStatuses (
    StatusId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertStatuses PRIMARY KEY,
    StatusName   NVARCHAR(60) NOT NULL,
    IsFinal      BIT NOT NULL CONSTRAINT DF_AlertStatuses_IsFinal DEFAULT (0),
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_AlertStatuses_CreatedAt DEFAULT (SYSDATETIME())
);
GO
ALTER TABLE dbo.AlertStatuses
ADD CONSTRAINT UQ_AlertStatuses_StatusName UNIQUE (StatusName);
GO

-- Locations
CREATE TABLE dbo.Locations (
    LocationId   INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Locations PRIMARY KEY,
    Sector       NVARCHAR(120) NOT NULL,
    Description  NVARCHAR(250) NULL,
    AddressLine  NVARCHAR(200) NULL,
    Latitude     DECIMAL(9,6) NULL,
    Longitude    DECIMAL(9,6) NULL,
    IsActive     BIT NOT NULL CONSTRAINT DF_Locations_IsActive DEFAULT (1),
    CreatedAt    DATETIME2(0) NOT NULL CONSTRAINT DF_Locations_CreatedAt DEFAULT (SYSDATETIME())
);
GO
ALTER TABLE dbo.Locations
ADD CONSTRAINT UQ_Locations_Sector UNIQUE (Sector);
GO


/* =========================================================
   2) TABLAS TRANSACCIONALES
   ========================================================= */

-- Alerts (Entidad principal)
CREATE TABLE dbo.Alerts (
    AlertId        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Alerts PRIMARY KEY,
    Title          NVARCHAR(120) NOT NULL,
    Description    NVARCHAR(800) NULL,

    Severity       TINYINT NOT NULL,         -- 1..5
    OccurredAt     DATETIME2(0) NOT NULL,    -- Fecha del evento

    CategoryId     INT NOT NULL,
    StatusId       INT NOT NULL,
    LocationId     INT NULL,
    ReportedById   INT NOT NULL,

    IsVerified     BIT NOT NULL CONSTRAINT DF_Alerts_IsVerified DEFAULT (0),

    CreatedAt      DATETIME2(0) NOT NULL CONSTRAINT DF_Alerts_CreatedAt DEFAULT (SYSDATETIME()),
    UpdatedAt      DATETIME2(0) NULL,

    IsDeleted      BIT NOT NULL CONSTRAINT DF_Alerts_IsDeleted DEFAULT (0),
    DeletedAt      DATETIME2(0) NULL
);
GO

ALTER TABLE dbo.Alerts
ADD CONSTRAINT CK_Alerts_Severity CHECK (Severity BETWEEN 1 AND 5);
GO

ALTER TABLE dbo.Alerts
ADD CONSTRAINT FK_Alerts_Category
FOREIGN KEY (CategoryId) REFERENCES dbo.AlertCategories(CategoryId);
GO

ALTER TABLE dbo.Alerts
ADD CONSTRAINT FK_Alerts_Status
FOREIGN KEY (StatusId) REFERENCES dbo.AlertStatuses(StatusId);
GO

ALTER TABLE dbo.Alerts
ADD CONSTRAINT FK_Alerts_Location
FOREIGN KEY (LocationId) REFERENCES dbo.Locations(LocationId);
GO

ALTER TABLE dbo.Alerts
ADD CONSTRAINT FK_Alerts_ReportedBy
FOREIGN KEY (ReportedById) REFERENCES dbo.Users(UserId);
GO

-- Comments (opcional pero útil para “más completo”)
CREATE TABLE dbo.AlertComments (
    CommentId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AlertComments PRIMARY KEY,
    AlertId       INT NOT NULL,
    UserId        INT NOT NULL,
    CommentText   NVARCHAR(600) NOT NULL,
    CreatedAt     DATETIME2(0) NOT NULL CONSTRAINT DF_AlertComments_CreatedAt DEFAULT (SYSDATETIME())
);
GO

ALTER TABLE dbo.AlertComments
ADD CONSTRAINT FK_AlertComments_Alert
FOREIGN KEY (AlertId) REFERENCES dbo.Alerts(AlertId);
GO

ALTER TABLE dbo.AlertComments
ADD CONSTRAINT FK_AlertComments_User
FOREIGN KEY (UserId) REFERENCES dbo.Users(UserId);
GO


/* =========================================================
   3) AUDITORÍA (para Triggers)
   ========================================================= */

CREATE TABLE dbo.AuditLog (
    AuditId     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_AuditLog PRIMARY KEY,
    EntityName  NVARCHAR(60) NOT NULL,
    EntityId    INT NOT NULL,
    Action      NVARCHAR(10) NOT NULL,      -- INSERT/UPDATE/DELETE
    ChangedAt   DATETIME2(0) NOT NULL CONSTRAINT DF_AuditLog_ChangedAt DEFAULT (SYSDATETIME()),
    ChangedBy   NVARCHAR(120) NULL,         -- SUSER_SNAME() o app
    OldValues   NVARCHAR(MAX) NULL,
    NewValues   NVARCHAR(MAX) NULL
);
GO


/* =========================================================
   4) ÍNDICES (para performance)
   ========================================================= */

-- Búsquedas típicas en SafeZone: fecha, estado, severidad, ubicación
CREATE INDEX IX_Alerts_OccurredAt   ON dbo.Alerts(OccurredAt DESC);
CREATE INDEX IX_Alerts_StatusId     ON dbo.Alerts(StatusId);
CREATE INDEX IX_Alerts_CategoryId   ON dbo.Alerts(CategoryId);
CREATE INDEX IX_Alerts_LocationId   ON dbo.Alerts(LocationId);
CREATE INDEX IX_Alerts_Severity     ON dbo.Alerts(Severity);

-- Índice compuesto para listados con filtro
CREATE INDEX IX_Alerts_Status_Severity_Date ON dbo.Alerts(StatusId, Severity, OccurredAt DESC);

-- Email usuario es UNIQUE ya, pero índice adicional no hace falta


/* =========================================================
   5) VISTAS (para reportes y MVC)
   ========================================================= */

-- Vista consolidada principal
CREATE VIEW dbo.vw_AlertsFull
AS
SELECT
    a.AlertId,
    a.Title,
    a.Description,
    a.Severity,
    a.OccurredAt,
    a.IsVerified,
    a.CreatedAt,
    a.UpdatedAt,
    a.IsDeleted,
    a.DeletedAt,

    c.CategoryName,
    s.StatusName,
    l.Sector AS LocationSector,

    u.FullName AS ReportedByName,
    u.Email    AS ReportedByEmail
FROM dbo.Alerts a
INNER JOIN dbo.AlertCategories c ON c.CategoryId = a.CategoryId
INNER JOIN dbo.AlertStatuses   s ON s.StatusId   = a.StatusId
LEFT  JOIN dbo.Locations       l ON l.LocationId = a.LocationId
INNER JOIN dbo.Users           u ON u.UserId     = a.ReportedById;
GO

-- Vista para dashboard: conteo por estado (solo no eliminadas)
CREATE VIEW dbo.vw_Dashboard_StatusCount
AS
SELECT
    s.StatusName,
    COUNT(*) AS Total
FROM dbo.Alerts a
INNER JOIN dbo.AlertStatuses s ON s.StatusId = a.StatusId
WHERE a.IsDeleted = 0
GROUP BY s.StatusName;
GO


/* =========================================================
   6) STORED PROCEDURES (CRUD)
   ========================================================= */

-- CRUD para Users (con acción tipo "CREATE/READ/UPDATE/DELETE")
CREATE OR ALTER PROCEDURE dbo.sp_Users_CRUD
(
    @Action   NVARCHAR(10),
    @UserId   INT = NULL,
    @RoleId   INT = NULL,
    @FullName NVARCHAR(120) = NULL,
    @Email    NVARCHAR(160) = NULL,
    @Phone    NVARCHAR(30)  = NULL,
    @IsActive BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'CREATE'
    BEGIN
        INSERT INTO dbo.Users(RoleId, FullName, Email, Phone, IsActive)
        VALUES (@RoleId, @FullName, @Email, @Phone, COALESCE(@IsActive, 1));

        SELECT SCOPE_IDENTITY() AS NewUserId;
        RETURN;
    END

    IF @Action = 'READ'
    BEGIN
        SELECT * FROM dbo.Users
        WHERE (@UserId IS NULL OR UserId = @UserId);
        RETURN;
    END

    IF @Action = 'UPDATE'
    BEGIN
        UPDATE dbo.Users
        SET
            RoleId   = COALESCE(@RoleId, RoleId),
            FullName = COALESCE(@FullName, FullName),
            Email    = COALESCE(@Email, Email),
            Phone    = COALESCE(@Phone, Phone),
            IsActive = COALESCE(@IsActive, IsActive),
            UpdatedAt = SYSDATETIME()
        WHERE UserId = @UserId;

        SELECT * FROM dbo.Users WHERE UserId = @UserId;
        RETURN;
    END

    IF @Action = 'DELETE'
    BEGIN
        DELETE FROM dbo.Users WHERE UserId = @UserId;
        RETURN;
    END

    RAISERROR('Acción inválida. Use CREATE, READ, UPDATE o DELETE.', 16, 1);
END
GO


-- CRUD básico para Alerts (Create / Read / Update / SoftDelete)
CREATE OR ALTER PROCEDURE dbo.sp_Alerts_CRUD
(
    @Action        NVARCHAR(12),
    @AlertId       INT = NULL,

    @Title         NVARCHAR(120) = NULL,
    @Description   NVARCHAR(800) = NULL,
    @Severity      TINYINT = NULL,
    @OccurredAt    DATETIME2(0) = NULL,

    @CategoryId    INT = NULL,
    @StatusId      INT = NULL,
    @LocationId    INT = NULL,
    @ReportedById  INT = NULL,

    @IsVerified    BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action = 'CREATE'
    BEGIN
        INSERT INTO dbo.Alerts
        (
            Title, Description, Severity, OccurredAt,
            CategoryId, StatusId, LocationId, ReportedById, IsVerified
        )
        VALUES
        (
            @Title, @Description, @Severity, @OccurredAt,
            @CategoryId, @StatusId, @LocationId, @ReportedById, COALESCE(@IsVerified, 0)
        );

        SELECT SCOPE_IDENTITY() AS NewAlertId;
        RETURN;
    END

    IF @Action = 'READ'
    BEGIN
        SELECT * FROM dbo.vw_AlertsFull
        WHERE IsDeleted = 0
          AND (@AlertId IS NULL OR AlertId = @AlertId)
        ORDER BY OccurredAt DESC;
        RETURN;
    END

    IF @Action = 'UPDATE'
    BEGIN
        UPDATE dbo.Alerts
        SET
            Title        = COALESCE(@Title, Title),
            Description  = COALESCE(@Description, Description),
            Severity     = COALESCE(@Severity, Severity),
            OccurredAt   = COALESCE(@OccurredAt, OccurredAt),
            CategoryId   = COALESCE(@CategoryId, CategoryId),
            StatusId     = COALESCE(@StatusId, StatusId),
            LocationId   = @LocationId, -- permite setear null intencional
            ReportedById = COALESCE(@ReportedById, ReportedById),
            IsVerified   = COALESCE(@IsVerified, IsVerified),
            UpdatedAt    = SYSDATETIME()
        WHERE AlertId = @AlertId;

        SELECT * FROM dbo.vw_AlertsFull WHERE AlertId = @AlertId;
        RETURN;
    END

    IF @Action = 'SOFTDELETE'
    BEGIN
        UPDATE dbo.Alerts
        SET IsDeleted = 1,
            DeletedAt = SYSDATETIME(),
            UpdatedAt = SYSDATETIME()
        WHERE AlertId = @AlertId;

        SELECT 'OK' AS Result;
        RETURN;
    END

    RAISERROR('Acción inválida. Use CREATE, READ, UPDATE o SOFTDELETE.', 16, 1);
END
GO


/* =========================================================
   7) TRIGGERS DE AUDITORÍA (Alerts)
   ========================================================= */

-- INSERT
CREATE OR ALTER TRIGGER dbo.tr_Alerts_Audit_Insert
ON dbo.Alerts
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
    SELECT
        'Alerts' AS EntityName,
        i.AlertId AS EntityId,
        'INSERT' AS Action,
        SUSER_SNAME() AS ChangedBy,
        NULL AS OldValues,
        (
            SELECT
                i.Title, i.Description, i.Severity, i.OccurredAt,
                i.CategoryId, i.StatusId, i.LocationId, i.ReportedById,
                i.IsVerified, i.IsDeleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS NewValues
    FROM inserted i;
END
GO

-- UPDATE
CREATE OR ALTER TRIGGER dbo.tr_Alerts_Audit_Update
ON dbo.Alerts
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
    SELECT
        'Alerts',
        i.AlertId,
        'UPDATE',
        SUSER_SNAME(),
        (
            SELECT
                d.Title, d.Description, d.Severity, d.OccurredAt,
                d.CategoryId, d.StatusId, d.LocationId, d.ReportedById,
                d.IsVerified, d.IsDeleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        (
            SELECT
                i.Title, i.Description, i.Severity, i.OccurredAt,
                i.CategoryId, i.StatusId, i.LocationId, i.ReportedById,
                i.IsVerified, i.IsDeleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        )
    FROM inserted i
    INNER JOIN deleted d ON d.AlertId = i.AlertId;
END
GO

-- DELETE (si algún día borras físico)
CREATE OR ALTER TRIGGER dbo.tr_Alerts_Audit_Delete
ON dbo.Alerts
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.AuditLog(EntityName, EntityId, Action, ChangedBy, OldValues, NewValues)
    SELECT
        'Alerts',
        d.AlertId,
        'DELETE',
        SUSER_SNAME(),
        (
            SELECT
                d.Title, d.Description, d.Severity, d.OccurredAt,
                d.CategoryId, d.StatusId, d.LocationId, d.ReportedById,
                d.IsVerified, d.IsDeleted
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ),
        NULL
    FROM deleted d;
END
GO


/* =========================================================
   8) DATOS FICTICIOS (Seeds)
   ========================================================= */

-- Roles
INSERT INTO dbo.Roles(RoleName) VALUES
('Administrador'),
('Operador'),
('Ciudadano');
GO

-- Users
INSERT INTO dbo.Users(RoleId, FullName, Email, Phone, IsActive) VALUES
(1, 'Admin SafeZone', 'admin@safezone.local', '0999999999', 1),
(3, 'María Gómez', 'maria.gomez@correo.com', '0987654321', 1),
(3, 'Juan Pérez', 'juan.perez@correo.com', '0971234567', 1);
GO

-- Categorías
INSERT INTO dbo.AlertCategories(CategoryName, IsActive) VALUES
('Robo', 1),
('Accidente', 1),
('Incendio', 1),
('Persona sospechosa', 1);
GO

-- Estados
INSERT INTO dbo.AlertStatuses(StatusName, IsFinal) VALUES
('En Proceso', 0),
('Atendido', 1),
('Cerrado', 1);
GO

-- Ubicaciones
INSERT INTO dbo.Locations(Sector, Description, AddressLine, Latitude, Longitude, IsActive) VALUES
('Parque Central', 'Zona recreativa principal del barrio', NULL, NULL, NULL, 1),
('Terminal Terrestre', 'Alta afluencia de personas', NULL, NULL, NULL, 1),
('Barrio San José', 'Sector residencial', NULL, NULL, NULL, 1);
GO

-- Alertas demo (usando SP para demostrar)
DECLARE @CatRobo INT = (SELECT TOP 1 CategoryId FROM dbo.AlertCategories WHERE CategoryName='Robo');
DECLARE @StProc  INT = (SELECT TOP 1 StatusId FROM dbo.AlertStatuses WHERE StatusName='En Proceso');
DECLARE @LocParq INT = (SELECT TOP 1 LocationId FROM dbo.Locations WHERE Sector='Parque Central');
DECLARE @UserMar INT = (SELECT TOP 1 UserId FROM dbo.Users WHERE Email='maria.gomez@correo.com');

EXEC dbo.sp_Alerts_CRUD
    @Action='CREATE',
    @Title='Robo de celular',
    @Description='Se reporta robo en zona concurrida.',
    @Severity=3,
    @OccurredAt=SYSDATETIME(),
    @CategoryId=@CatRobo,
    @StatusId=@StProc,
    @LocationId=@LocParq,
    @ReportedById=@UserMar,
    @IsVerified=0;
GO


/* =========================================================
   9) PRUEBAS RÁPIDAS (para exponer)
   ========================================================= */

-- Ver alertas consolidadas
SELECT TOP 50 * FROM dbo.vw_AlertsFull ORDER BY OccurredAt DESC;

-- Dashboard por estado
SELECT * FROM dbo.vw_Dashboard_StatusCount;

-- Auditoría: debería tener INSERT/UPDATE si haces cambios
SELECT TOP 50 * FROM dbo.AuditLog ORDER BY ChangedAt DESC;

-- Probar Users CRUD
-- READ
EXEC dbo.sp_Users_CRUD @Action='READ';
GO

SELECT * FROM dbo.AlertCategories;
SELECT * FROM dbo.AlertStatuses;
SELECT * FROM dbo.Users;
SELECT * FROM dbo.Locations;


-- Categorías
IF NOT EXISTS (SELECT 1 FROM dbo.AlertCategories)
INSERT INTO dbo.AlertCategories (CategoryName, IsActive, CreatedAt)
VALUES ('Robo', 1, GETDATE()), ('Accidente', 1, GETDATE()), ('Emergencia', 1, GETDATE());

-- Estados
IF NOT EXISTS (SELECT 1 FROM dbo.AlertStatuses)
INSERT INTO dbo.AlertStatuses (StatusName, CreatedAt)
VALUES ('En Proceso', GETDATE()), ('Atendida', GETDATE()), ('Cerrada', GETDATE());

-- Ubicaciones
IF NOT EXISTS (SELECT 1 FROM dbo.Locations)
INSERT INTO dbo.Locations (Sector, CreatedAt)
VALUES ('Parque Central', GETDATE()), ('Terminal Terrestre', GETDATE()), ('Barrio San José', GETDATE());

-- Usuarios
IF NOT EXISTS (SELECT 1 FROM dbo.Users)
INSERT INTO dbo.Users (RoleId, FullName, Email, Phone, IsActive, CreatedAt)
VALUES (1, 'María Gómez', 'maria@safezone.com', '0999999999', 1, GETDATE());


SELECT TOP 10 * FROM AlertCategories;
SELECT TOP 10 * FROM AlertStatuses;
SELECT TOP 10 * FROM Locations;
SELECT TOP 10 * FROM Users;


-- Agrega campos al usuario (si no existen)
IF COL_LENGTH('dbo.Users', 'Cedula') IS NULL
    ALTER TABLE dbo.Users ADD Cedula VARCHAR(20) NULL;

IF COL_LENGTH('dbo.Users', 'Phone') IS NULL
    ALTER TABLE dbo.Users ADD Phone VARCHAR(20) NULL;

IF COL_LENGTH('dbo.Users', 'Barrio') IS NULL
    ALTER TABLE dbo.Users ADD Barrio VARCHAR(120) NULL;

IF COL_LENGTH('dbo.Users', 'DireccionCasa') IS NULL
    ALTER TABLE dbo.Users ADD DireccionCasa VARCHAR(200) NULL;

-- Opcional: que Email y Cedula sean únicos (recomendado)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Users_Email' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE UNIQUE INDEX UX_Users_Email ON dbo.Users(Email);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Users_Cedula' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE UNIQUE INDEX UX_Users_Cedula ON dbo.Users(Cedula);


/* ==== Campos para autenticación ==== */
IF COL_LENGTH('dbo.Users','PasswordHash') IS NULL
    ALTER TABLE dbo.Users ADD PasswordHash NVARCHAR(256) NULL;

IF COL_LENGTH('dbo.Users','PasswordSalt') IS NULL
    ALTER TABLE dbo.Users ADD PasswordSalt NVARCHAR(256) NULL;

/* ==== Campos extra solicitados para Registro ==== */
IF COL_LENGTH('dbo.Users','Cedula') IS NULL
    ALTER TABLE dbo.Users ADD Cedula NVARCHAR(20) NULL;

IF COL_LENGTH('dbo.Users','Barrio') IS NULL
    ALTER TABLE dbo.Users ADD Barrio NVARCHAR(120) NULL;

IF COL_LENGTH('dbo.Users','DireccionCasa') IS NULL
    ALTER TABLE dbo.Users ADD DireccionCasa NVARCHAR(200) NULL;

/* (Opcional) Asegurar Email único */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'UX_Users_Email' AND object_id = OBJECT_ID('dbo.Users')
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_Email ON dbo.Users(Email);
END

/* (Opcional) Asegurar Cedula única si la usas */
IF NOT EXISTS (
    SELECT 1 FROM sys.indexes 
    WHERE name = 'UX_Users_Cedula' AND object_id = OBJECT_ID('dbo.Users')
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_Cedula ON dbo.Users(Cedula);
END
