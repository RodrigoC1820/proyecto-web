USE SafeZoneDB_Final_2026_Limpia;
GO

IF OBJECT_ID('dbo.sp_Alerts_CRUD', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Alerts_CRUD;
GO

CREATE PROCEDURE dbo.sp_Alerts_CRUD
(
    @Action        NVARCHAR(10),      -- CREATE | READ | UPDATE | DELETE
    @AlertId       INT = NULL,

    -- Datos
    @Title         NVARCHAR(200) = NULL,
    @Description   NVARCHAR(MAX) = NULL,
    @Severity      INT = NULL,
    @OccurredAt    DATETIME = NULL,

    @CategoryId    INT = NULL,
    @StatusId      INT = NULL,
    @LocationId    INT = NULL,
    @ReportedById  INT = NULL,

    @IsVerified    BIT = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Act NVARCHAR(10) = UPPER(LTRIM(RTRIM(@Action)));

    /* =========================
       VALIDACIONES GENERALES
    ==========================*/
    IF @Act NOT IN ('CREATE','READ','UPDATE','DELETE')
    BEGIN
        RAISERROR('Acción inválida. Use: CREATE, READ, UPDATE o DELETE.', 16, 1);
        RETURN;
    END

    /* =========================
       CREATE
    ==========================*/
    IF @Act = 'CREATE'
    BEGIN
        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
        BEGIN
            RAISERROR('Title es obligatorio.', 16, 1);
            RETURN;
        END

        IF @CategoryId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.AlertCategories WHERE CategoryId = @CategoryId)
        BEGIN
            RAISERROR('CategoryId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @StatusId IS NULL OR NOT EXISTS (SELECT 1 FROM dbo.AlertStatuses WHERE StatusId = @StatusId)
        BEGIN
            RAISERROR('StatusId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @LocationId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Locations WHERE LocationId = @LocationId)
        BEGIN
            RAISERROR('LocationId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @ReportedById IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @ReportedById)
        BEGIN
            RAISERROR('ReportedById no existe (FK).', 16, 1);
            RETURN;
        END

        IF @Severity IS NULL SET @Severity = 3;
        IF @OccurredAt IS NULL SET @OccurredAt = GETDATE();
        IF @IsVerified IS NULL SET @IsVerified = 0;

        INSERT INTO dbo.Alerts
        (
            Title, Description, Severity, OccurredAt,
            CategoryId, StatusId, LocationId, ReportedById,
            IsVerified, IsDeleted,
            CreatedAt, UpdatedAt
        )
        VALUES
        (
            @Title, @Description, @Severity, @OccurredAt,
            @CategoryId, @StatusId, @LocationId, @ReportedById,
            @IsVerified, 0,
            GETDATE(), GETDATE()
        );

        DECLARE @NewId INT = SCOPE_IDENTITY();

        -- Devuelve el registro creado consolidado (vista)
        SELECT *
        FROM dbo.vw_AlertsFull
        WHERE AlertId = @NewId;

        RETURN;
    END

    /* =========================
       READ
       - Si @AlertId viene -> 1 registro
       - Si @AlertId NULL -> lista (no eliminadas)
    ==========================*/
    IF @Act = 'READ'
    BEGIN
        IF @AlertId IS NOT NULL
        BEGIN
            SELECT *
            FROM dbo.vw_AlertsFull
            WHERE AlertId = @AlertId;
        END
        ELSE
        BEGIN
            SELECT *
            FROM dbo.vw_AlertsFull
            WHERE ISNULL(IsDeleted, 0) = 0
            ORDER BY CreatedAt DESC;
        END

        RETURN;
    END

    /* =========================
       UPDATE
    ==========================*/
    IF @Act = 'UPDATE'
    BEGIN
        IF @AlertId IS NULL
        BEGIN
            RAISERROR('AlertId es obligatorio para UPDATE.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Alerts WHERE AlertId = @AlertId)
        BEGIN
            RAISERROR('AlertId no existe.', 16, 1);
            RETURN;
        END

        -- Validar FKs solo si llegan
        IF @CategoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.AlertCategories WHERE CategoryId = @CategoryId)
        BEGIN
            RAISERROR('CategoryId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @StatusId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.AlertStatuses WHERE StatusId = @StatusId)
        BEGIN
            RAISERROR('StatusId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @LocationId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Locations WHERE LocationId = @LocationId)
        BEGIN
            RAISERROR('LocationId no existe (FK).', 16, 1);
            RETURN;
        END

        IF @ReportedById IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserId = @ReportedById)
        BEGIN
            RAISERROR('ReportedById no existe (FK).', 16, 1);
            RETURN;
        END

        UPDATE dbo.Alerts
        SET
            Title        = COALESCE(@Title, Title),
            Description  = COALESCE(@Description, Description),
            Severity     = COALESCE(@Severity, Severity),
            OccurredAt   = COALESCE(@OccurredAt, OccurredAt),

            CategoryId   = COALESCE(@CategoryId, CategoryId),
            StatusId     = COALESCE(@StatusId, StatusId),
            LocationId   = COALESCE(@LocationId, LocationId),
            ReportedById = COALESCE(@ReportedById, ReportedById),

            IsVerified   = COALESCE(@IsVerified, IsVerified),

            UpdatedAt    = GETDATE()
        WHERE AlertId = @AlertId;

        SELECT *
        FROM dbo.vw_AlertsFull
        WHERE AlertId = @AlertId;

        RETURN;
    END

    /* =========================
       DELETE (lógico)
    ==========================*/
    IF @Act = 'DELETE'
    BEGIN
        IF @AlertId IS NULL
        BEGIN
            RAISERROR('AlertId es obligatorio para DELETE.', 16, 1);
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.Alerts WHERE AlertId = @AlertId)
        BEGIN
            RAISERROR('AlertId no existe.', 16, 1);
            RETURN;
        END

        UPDATE dbo.Alerts
        SET
            IsDeleted = 1,
            UpdatedAt = GETDATE()
        WHERE AlertId = @AlertId;

        SELECT
            'OK' AS Result,
            'Alerta marcada como eliminada (soft delete).' AS Message,
            @AlertId AS AlertId;

        RETURN;
    END
END
GO


EXEC dbo.sp_Alerts_CRUD
    @Action = 'CREATE',
    @Title = 'Robo en el Parque',
    @Description = 'Robo reportado a las 9 pm',
    @Severity = 4,
    @OccurredAt = '2026-01-10 21:00:00',
    @CategoryId = 1,
    @StatusId = 1,
    @LocationId = 1,
    @ReportedById = 1,
    @IsVerified = 0;




EXEC dbo.sp_Alerts_CRUD @Action = 'READ';


EXEC dbo.sp_Alerts_CRUD @Action = 'READ', @AlertId = 1;


EXEC dbo.sp_Alerts_CRUD
    @Action = 'UPDATE',
    @AlertId = 1,
    @StatusId = 2,
    @IsVerified = 1,
    @Severity = 3;



EXEC dbo.sp_Alerts_CRUD
    @Action = 'DELETE',
    @AlertId = 1;
