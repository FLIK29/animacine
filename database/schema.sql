-- ============================================================
--  AnimaCine — Esquema de Base de Datos
--  SQL Server Express
--  Versión 1.0
-- ============================================================

USE master;
GO

-- Crear base de datos si no existe
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'AnimaCine')
    CREATE DATABASE AnimaCine;
GO

USE AnimaCine;
GO

-- ============================================================
--  TABLA: Roles
--  Valores base: 1=Usuario, 2=Administrador
-- ============================================================
CREATE TABLE Roles (
    RolID       INT           PRIMARY KEY IDENTITY(1,1),
    Nombre      NVARCHAR(50)  NOT NULL UNIQUE,
    Descripcion NVARCHAR(200) NULL
);

INSERT INTO Roles (Nombre, Descripcion) VALUES
    ('Usuario',        'Puede consultar películas, calificar y guardar favoritas'),
    ('Administrador',  'Gestión completa del catálogo de películas');
GO

-- ============================================================
--  TABLA: Usuarios
-- ============================================================
CREATE TABLE Usuarios (
    UsuarioID      INT            PRIMARY KEY IDENTITY(1,1),
    Nombre         NVARCHAR(100)  NOT NULL,
    Email          NVARCHAR(150)  NOT NULL UNIQUE,
    PasswordHash   NVARCHAR(255)  NOT NULL,   -- bcrypt hash
    RolID          INT            NOT NULL DEFAULT 1,
    Activo         BIT            NOT NULL DEFAULT 1,
    FechaRegistro  DATETIME2      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Usuarios_Rol FOREIGN KEY (RolID) REFERENCES Roles(RolID)
);

CREATE INDEX IX_Usuarios_Email ON Usuarios(Email);
GO

-- ============================================================
--  TABLA: Géneros
-- ============================================================
CREATE TABLE Generos (
    GeneroID INT           PRIMARY KEY IDENTITY(1,1),
    Nombre   NVARCHAR(80)  NOT NULL UNIQUE
);

INSERT INTO Generos (Nombre) VALUES
    ('Fantasía'), ('Aventura'), ('Comedia'), ('Drama'),
    ('Musical'), ('Acción'), ('Ciencia ficción'), ('Terror');
GO

-- ============================================================
--  TABLA: Estudios
-- ============================================================
CREATE TABLE Estudios (
    EstudioID INT           PRIMARY KEY IDENTITY(1,1),
    Nombre    NVARCHAR(150) NOT NULL UNIQUE,
    Pais      NVARCHAR(80)  NULL
);

INSERT INTO Estudios (Nombre, Pais) VALUES
    ('Studio Ghibli',    'Japón'),
    ('Pixar',            'Estados Unidos'),
    ('Walt Disney',      'Estados Unidos'),
    ('Sony Pictures',    'Estados Unidos'),
    ('ufotable',         'Japón'),
    ('TMS Entertainment','Japón');
GO

-- ============================================================
--  TABLA: Películas
-- ============================================================
CREATE TABLE Peliculas (
    PeliculaID    INT            PRIMARY KEY IDENTITY(1,1),
    Titulo        NVARCHAR(200)  NOT NULL,
    Sinopsis      NVARCHAR(MAX)  NULL,
    Anio          SMALLINT       NOT NULL,
    Duracion      SMALLINT       NULL,           -- en minutos
    PosterURL     NVARCHAR(500)  NULL,
    GeneroID      INT            NOT NULL,
    EstudioID     INT            NOT NULL,
    Activa        BIT            NOT NULL DEFAULT 1,
    FechaAgregada DATETIME2      NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_Peliculas_Genero  FOREIGN KEY (GeneroID)  REFERENCES Generos(GeneroID),
    CONSTRAINT FK_Peliculas_Estudio FOREIGN KEY (EstudioID) REFERENCES Estudios(EstudioID)
);

CREATE INDEX IX_Peliculas_Genero ON Peliculas(GeneroID);
CREATE INDEX IX_Peliculas_Anio   ON Peliculas(Anio);
GO

-- ============================================================
--  TABLA: Calificaciones
--  Un usuario califica una película una sola vez (upsert)
-- ============================================================
CREATE TABLE Calificaciones (
    CalificacionID INT       PRIMARY KEY IDENTITY(1,1),
    UsuarioID      INT       NOT NULL,
    PeliculaID     INT       NOT NULL,
    Puntaje        TINYINT   NOT NULL CHECK (Puntaje BETWEEN 1 AND 5),
    Fecha          DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT UQ_Calificacion UNIQUE (UsuarioID, PeliculaID),
    CONSTRAINT FK_Cal_Usuario  FOREIGN KEY (UsuarioID)  REFERENCES Usuarios(UsuarioID),
    CONSTRAINT FK_Cal_Pelicula FOREIGN KEY (PeliculaID) REFERENCES Peliculas(PeliculaID)
);
GO

-- ============================================================
--  TABLA: Favoritos
-- ============================================================
CREATE TABLE Favoritos (
    FavoritoID INT       PRIMARY KEY IDENTITY(1,1),
    UsuarioID  INT       NOT NULL,
    PeliculaID INT       NOT NULL,
    Fecha      DATETIME2 NOT NULL DEFAULT GETDATE(),

    CONSTRAINT UQ_Favorito     UNIQUE (UsuarioID, PeliculaID),
    CONSTRAINT FK_Fav_Usuario  FOREIGN KEY (UsuarioID)  REFERENCES Usuarios(UsuarioID),
    CONSTRAINT FK_Fav_Pelicula FOREIGN KEY (PeliculaID) REFERENCES Peliculas(PeliculaID)
);
GO

-- ============================================================
--  VISTA: Catálogo con promedio de calificaciones
-- ============================================================
CREATE VIEW vw_Catalogo AS
SELECT
    p.PeliculaID,
    p.Titulo,
    p.Anio,
    p.Duracion,
    p.Sinopsis,
    p.PosterURL,
    g.Nombre        AS Genero,
    e.Nombre        AS Estudio,
    COUNT(c.CalificacionID)          AS TotalCalificaciones,
    ROUND(AVG(CAST(c.Puntaje AS FLOAT)), 1) AS PromedioCalificacion
FROM Peliculas p
JOIN Generos   g ON p.GeneroID  = g.GeneroID
JOIN Estudios  e ON p.EstudioID = e.EstudioID
LEFT JOIN Calificaciones c ON p.PeliculaID = c.PeliculaID
WHERE p.Activa = 1
GROUP BY
    p.PeliculaID, p.Titulo, p.Anio, p.Duracion,
    p.Sinopsis, p.PosterURL, g.Nombre, e.Nombre;
GO

-- ============================================================
--  STORED PROCEDURES
-- ============================================================

-- SP: Obtener catálogo completo (con filtros opcionales)
CREATE PROCEDURE sp_ObtenerCatalogo
    @Genero    NVARCHAR(80) = NULL,
    @Busqueda  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM vw_Catalogo
    WHERE
        (@Genero   IS NULL OR Genero = @Genero)
        AND
        (@Busqueda IS NULL OR Titulo LIKE '%' + @Busqueda + '%'
                           OR Estudio LIKE '%' + @Busqueda + '%')
    ORDER BY Titulo;
END;
GO

-- SP: Calificar película (insert o update)
CREATE PROCEDURE sp_CalificarPelicula
    @UsuarioID  INT,
    @PeliculaID INT,
    @Puntaje    TINYINT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Calificaciones WHERE UsuarioID = @UsuarioID AND PeliculaID = @PeliculaID)
        UPDATE Calificaciones
        SET Puntaje = @Puntaje, Fecha = GETDATE()
        WHERE UsuarioID = @UsuarioID AND PeliculaID = @PeliculaID;
    ELSE
        INSERT INTO Calificaciones (UsuarioID, PeliculaID, Puntaje)
        VALUES (@UsuarioID, @PeliculaID, @Puntaje);
END;
GO

-- SP: Agregar o quitar favorito (toggle)
CREATE PROCEDURE sp_ToggleFavorito
    @UsuarioID  INT,
    @PeliculaID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM Favoritos WHERE UsuarioID = @UsuarioID AND PeliculaID = @PeliculaID)
    BEGIN
        DELETE FROM Favoritos WHERE UsuarioID = @UsuarioID AND PeliculaID = @PeliculaID;
        SELECT 'eliminado' AS Estado;
    END
    ELSE
    BEGIN
        INSERT INTO Favoritos (UsuarioID, PeliculaID) VALUES (@UsuarioID, @PeliculaID);
        SELECT 'agregado' AS Estado;
    END
END;
GO

-- SP: Favoritos de un usuario
CREATE PROCEDURE sp_ObtenerFavoritos
    @UsuarioID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.*
    FROM vw_Catalogo c
    JOIN Favoritos f ON c.PeliculaID = f.PeliculaID
    WHERE f.UsuarioID = @UsuarioID
    ORDER BY f.Fecha DESC;
END;
GO

-- ============================================================
--  DATOS DE EJEMPLO — Películas
-- ============================================================
INSERT INTO Peliculas (Titulo, Sinopsis, Anio, Duracion, GeneroID, EstudioID) VALUES
('El viaje de Chihiro',
 'Una niña de diez años queda atrapada en un mundo mágico de espíritus.',
 2001, 125,
 (SELECT GeneroID FROM Generos WHERE Nombre='Fantasía'),
 (SELECT EstudioID FROM Estudios WHERE Nombre='Studio Ghibli')),

('Coco',
 'Miguel cruza al mundo de los muertos durante el Día de Muertos.',
 2017, 105,
 (SELECT GeneroID FROM Generos WHERE Nombre='Musical'),
 (SELECT EstudioID FROM Estudios WHERE Nombre='Pixar')),

('Toy Story',
 'Woody ve amenazada su posición cuando llega Buzz Lightyear.',
 1995, 81,
 (SELECT GeneroID FROM Generos WHERE Nombre='Aventura'),
 (SELECT EstudioID FROM Estudios WHERE Nombre='Pixar')),

('Spider-Man: Un Nuevo Universo',
 'Miles Morales se convierte en Spider-Man y debe salvar el multiverso.',
 2018, 117,
 (SELECT GeneroID FROM Generos WHERE Nombre='Acción'),
 (SELECT EstudioID FROM Estudios WHERE Nombre='Sony Pictures')),

('Mi vecino Totoro',
 'Dos niñas descubren a Totoro, un guardián del bosque.',
 1988, 86,
 (SELECT GeneroID FROM Generos WHERE Nombre='Fantasía'),
 (SELECT EstudioID FROM Estudios WHERE Nombre='Studio Ghibli'));
GO

-- ============================================================
--  USUARIO ADMINISTRADOR INICIAL
--  (password: Admin123! — reemplazar hash con bcrypt real)
-- ============================================================
INSERT INTO Usuarios (Nombre, Email, PasswordHash, RolID) VALUES
('Administrador', 'admin@animacine.com',
 '$2b$12$HASH_PLACEHOLDER_reemplazar_con_bcrypt', 2);
GO

PRINT '✅ Base de datos AnimaCine creada exitosamente.';
