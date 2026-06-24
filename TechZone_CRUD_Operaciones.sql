-- ============================================================
--  BASE DE DATOS : TechZone
--  ARCHIVO       : TechZone_CRUD_Operaciones.sql
--  DESCRIPCIÓN   : Evidencia de operaciones CRUD
--                  CREATE · READ · UPDATE · DELETE
-- ============================================================

USE TechZone
GO

-- ============================================================
-- SECCIÓN 1 – CREATE (Crear)
-- Creación de tablas nuevas + inserción de registros
-- ============================================================

-- ------------------------------------------------------------
-- 1.A  NUEVA TABLA: Proveedor
--      Almacena los proveedores que abastecen productos.
-- ------------------------------------------------------------
IF OBJECT_ID('Proveedor', 'U') IS NOT NULL
    DROP TABLE Proveedor
GO

CREATE TABLE Proveedor (
    idProveedor      INT           IDENTITY(1,1) CONSTRAINT PK_Proveedor       PRIMARY KEY,
    nombreEmpresa    NVARCHAR(120) NOT NULL       CONSTRAINT UQ_Proveedor_Nombre UNIQUE,
    ruc              NVARCHAR(20)  NOT NULL       CONSTRAINT UQ_Proveedor_RUC    UNIQUE,
    email            NVARCHAR(255) NOT NULL,
    telefono         NVARCHAR(20)  NULL,
    idPais           INT           NOT NULL,
    activo           BIT           NOT NULL       CONSTRAINT DF_Proveedor_Activo  DEFAULT 1,
    CONSTRAINT FK_Proveedor_Pais
        FOREIGN KEY (idPais) REFERENCES Pais(idPais)
)
GO

-- ------------------------------------------------------------
-- 1.B  NUEVA TABLA: ProductoProveedor
--      Relación N:M entre Producto y Proveedor con precio
--      de costo y tiempo de reabastecimiento.
-- ------------------------------------------------------------
IF OBJECT_ID('ProductoProveedor', 'U') IS NOT NULL
    DROP TABLE ProductoProveedor
GO

CREATE TABLE ProductoProveedor (
    idProductoProveedor INT            IDENTITY(1,1) CONSTRAINT PK_ProductoProveedor     PRIMARY KEY,
    idProducto          INT            NOT NULL,
    idProveedor         INT            NOT NULL,
    precioCosto         DECIMAL(12,2)  NOT NULL      CONSTRAINT CHK_PP_PrecioCosto CHECK (precioCosto >= 0),
    tiempoReabasto_dias INT            NOT NULL      CONSTRAINT DF_PP_Reabasto      DEFAULT 7,
    principal           BIT            NOT NULL      CONSTRAINT DF_PP_Principal     DEFAULT 0,
    CONSTRAINT FK_PP_Producto
        FOREIGN KEY (idProducto)  REFERENCES Producto(idProducto),
    CONSTRAINT FK_PP_Proveedor
        FOREIGN KEY (idProveedor) REFERENCES Proveedor(idProveedor),
    CONSTRAINT UQ_PP_Producto_Proveedor
        UNIQUE (idProducto, idProveedor)
)
GO

-- ------------------------------------------------------------
-- 1.C  INSERT – Llenar las nuevas tablas con datos reales
-- ------------------------------------------------------------
INSERT INTO Proveedor (nombreEmpresa, ruc, email, telefono, idPais, activo) VALUES
    ('TechSupply S.A.',      'J0310000001', 'ventas@techsupply.com',    '2270-1000', 1, 1),
    ('GlobalParts Corp.',    'US0000000001','sales@globalparts.com',    '1-800-555', 2, 1),
    ('Importaciones CR Ltda','CR0000000001','compras@importcr.com',     '4000-1234', 3, 1)
GO

INSERT INTO ProductoProveedor (idProducto, idProveedor, precioCosto, tiempoReabasto_dias, principal) VALUES
    (1, 2, 950.00,  10, 1),   -- Dell XPS 15   → GlobalParts (principal)
    (2, 2,  45.00,   7, 1),   -- Mouse Logitech → GlobalParts (principal)
    (2, 1,  48.00,   5, 0),   -- Mouse Logitech → TechSupply  (alternativo)
    (3, 2, 200.00,  14, 1),   -- Monitor Samsung→ GlobalParts (principal)
    (4, 1,  70.00,   3, 1)    -- Teclado TechKey→ TechSupply  (principal)
GO

-- ============================================================
-- SECCIÓN 2 – READ (Consultar)
-- Consultas representativas del sistema
-- ============================================================

-- 2.1  Lista completa de clientes activos con ciudad
SELECT
    c.idCliente,
    c.primerNombre + ' ' + c.primerApellido  AS NombreCompleto,
    c.email,
    c.telefono,
    ci.nombreCiudad                          AS Ciudad,
    c.fechaRegistro
FROM Cliente        c
JOIN Ciudad         ci ON ci.idCiudad = c.idCiudadPredeterminada
WHERE c.activo = 1
ORDER BY c.primerApellido
GO

-- 2.2  Catálogo de productos con precio, stock y categoría
SELECT
    p.nombre                                 AS Producto,
    p.marca,
    cat.nombre                               AS Categoria,
    pv.codigoSKU,
    pv.configuracionTexto                    AS Configuracion,
    pv.precioActual                          AS Precio,
    pv.moneda,
    ISNULL(inv.cantidadDisponible, 0)        AS Stock,
    ISNULL(inv.cantidadReservada, 0)         AS Reservado,
    ISNULL(inv.cantidadDisponible, 0)
        - ISNULL(inv.cantidadReservada, 0)   AS StockNeto
FROM Producto         p
JOIN Categoria        cat ON cat.idCategoria = p.idCategoria
JOIN ProductoVariante pv  ON pv.idProducto   = p.idProducto
LEFT JOIN Inventario  inv ON inv.idVariante   = pv.idVariante
WHERE p.activo = 1 AND pv.activo = 1
ORDER BY cat.nombre, p.nombre
GO

-- 2.3  Pedidos con detalle de estado, cliente y monto
SELECT
    ped.idPedido,
    ped.fechaPedido,
    cl.primerNombre + ' ' + cl.primerApellido AS Cliente,
    ep.nombre                                  AS EstadoPedido,
    ped.montoTotalFacturado,
    pago.monto                                 AS MontoPagado,
    epago.nombre                               AS EstadoPago,
    env.numeroTracking,
    eenv.nombre                                AS EstadoEnvio
FROM  Pedido      ped
JOIN  Cliente     cl    ON cl.idCliente      = ped.idCliente
JOIN  EstadoPedido ep   ON ep.idEstado       = ped.idEstadoPedido
LEFT JOIN Pago    pago  ON pago.idPedido     = ped.idPedido
LEFT JOIN EstadoPago epago ON epago.idEstadoPago = pago.idEstadoPago
LEFT JOIN Envio   env   ON env.idPedido      = ped.idPedido
LEFT JOIN EstadoEnvio eenv ON eenv.idEstadoEnvio = env.idEstadoEnvio
ORDER BY ped.fechaPedido DESC
GO

-- 2.4  Proveedores por producto (nuevas tablas)
SELECT
    p.nombre                                  AS Producto,
    prov.nombreEmpresa                        AS Proveedor,
    pp.precioCosto,
    pp.tiempoReabasto_dias,
    pp.principal
FROM ProductoProveedor pp
JOIN Producto  p    ON p.idProducto  = pp.idProducto
JOIN Proveedor prov ON prov.idProveedor = pp.idProveedor
ORDER BY p.nombre, pp.principal DESC
GO

-- ============================================================
-- SECCIÓN 3 – UPDATE (Actualizar)
-- Modificación de datos y constraints con nombre
-- ============================================================

-- ------------------------------------------------------------
-- 3.A  Actualizar datos de un cliente
-- ------------------------------------------------------------
UPDATE Cliente
SET    telefono = '555-9999',
       activo   = 1
WHERE  email = 'ana.garcia@email.com'
GO

-- 3.B  Actualizar precio de una variante (registra en historial)
-- Paso 1: insertar en historial antes de cambiar precio
INSERT INTO HistorialPrecio (idVariante, precioAnterior, precioNuevo, motivo)
SELECT idVariante, precioActual, 1199.99, 'Promoción temporada'
FROM   ProductoVariante
WHERE  codigoSKU = 'DELL-XPS15-001'
GO

-- Paso 2: aplicar el nuevo precio
UPDATE ProductoVariante
SET    precioActual = 1199.99
WHERE  codigoSKU = 'DELL-XPS15-001'
GO

-- ------------------------------------------------------------
-- 3.C  Renombrar constraint UQ_Categoria_Nombre
--      (SQL Server requiere DROP + ADD para renombrar constraints)
-- ------------------------------------------------------------

-- Eliminar el constraint antiguo
ALTER TABLE Categoria
    DROP CONSTRAINT UQ_Categoria_Nombre
GO

-- Agregar el constraint con el nombre nuevo
ALTER TABLE Categoria
    ADD CONSTRAINT UQ_Cat_NombreCategoria UNIQUE (nombre)
GO

-- ------------------------------------------------------------
-- 3.D  Agregar columna y constraint CHECK a tabla Proveedor
-- ------------------------------------------------------------
ALTER TABLE Proveedor
    ADD sitioWeb NVARCHAR(255) NULL
GO

-- Actualizar la nueva columna con datos de ejemplo
UPDATE Proveedor SET sitioWeb = 'https://www.techsupply.com'  WHERE nombreEmpresa = 'TechSupply S.A.'
UPDATE Proveedor SET sitioWeb = 'https://www.globalparts.com' WHERE nombreEmpresa = 'GlobalParts Corp.'
GO

-- ------------------------------------------------------------
-- 3.E  Actualizar stock tras una recepción de mercancía
-- ------------------------------------------------------------
UPDATE Inventario
SET    cantidadDisponible = cantidadDisponible + 50,
       ubicacionEstante   = 'A-12-3'
WHERE  idVariante = (SELECT idVariante FROM ProductoVariante WHERE codigoSKU = 'DELL-XPS15-001')
  AND  idBodega   = 1
GO

-- ============================================================
-- SECCIÓN 4 – DELETE (Eliminar)
-- Eliminación controlada respetando integridad referencial
-- ============================================================

-- ------------------------------------------------------------
-- 4.A  Eliminar un ítem del carrito
-- ------------------------------------------------------------
DELETE FROM CarritoItem
WHERE  idCarrito = 1
  AND  idVariante = (SELECT idVariante FROM ProductoVariante WHERE codigoSKU = 'TKB-RGB-004')
GO

-- ------------------------------------------------------------
-- 4.B  Eliminar proveedor alternativo de un producto
--      (relación en ProductoProveedor, no el proveedor mismo)
-- ------------------------------------------------------------
DELETE FROM ProductoProveedor
WHERE  idProducto  = (SELECT idProducto FROM Producto WHERE nombre = 'Mouse Logitech MX Master')
  AND  idProveedor = (SELECT idProveedor FROM Proveedor WHERE nombreEmpresa = 'TechSupply S.A.')
  AND  principal   = 0
GO

-- ------------------------------------------------------------
-- 4.C  Desactivar (soft-delete) un producto en lugar de
--      borrarlo físicamente, para mantener historial
-- ------------------------------------------------------------
UPDATE Producto
SET    activo = 0
WHERE  nombre = 'Teclado Mecánico RGB'
GO

-- ------------------------------------------------------------
-- 4.D  Eliminar la tabla ProductoProveedor (ya vacía de ese
--      registro), luego recrearla con un CHECK nuevo
--      que garantice que precioCosto > 0
-- ------------------------------------------------------------

-- Quitar datos de prueba residuales para poder hacer DROP limpio
DELETE FROM ProductoProveedor   -- limpiamos para demo
GO

DROP TABLE ProductoProveedor
GO

CREATE TABLE ProductoProveedor (
    idProductoProveedor INT            IDENTITY(1,1) CONSTRAINT PK_ProductoProveedor      PRIMARY KEY,
    idProducto          INT            NOT NULL,
    idProveedor         INT            NOT NULL,
    precioCosto         DECIMAL(12,2)  NOT NULL
        CONSTRAINT CHK_PP_PrecioCostoPositivo CHECK (precioCosto > 0),   -- ahora > 0
    tiempoReabasto_dias INT            NOT NULL
        CONSTRAINT DF_PP_ReabastoNew DEFAULT 7,
    principal           BIT            NOT NULL
        CONSTRAINT DF_PP_PrincipalNew DEFAULT 0,
    CONSTRAINT FK_PP_ProductoNew  FOREIGN KEY (idProducto)  REFERENCES Producto(idProducto),
    CONSTRAINT FK_PP_ProveedorNew FOREIGN KEY (idProveedor) REFERENCES Proveedor(idProveedor),
    CONSTRAINT UQ_PP_Producto_ProveedorNew UNIQUE (idProducto, idProveedor)
)
GO

-- Re-insertar los datos (sin el proveedor alternativo ya eliminado)
INSERT INTO ProductoProveedor (idProducto, idProveedor, precioCosto, tiempoReabasto_dias, principal) VALUES
    (1, 2, 950.00, 10, 1),
    (2, 2,  45.00,  7, 1),
    (3, 2, 200.00, 14, 1),
    (4, 1,  70.00,  3, 1)
GO

-- ============================================================
-- VERIFICACIÓN FINAL – Consultas de comprobación
-- ============================================================

-- Verificar clientes actualizados
SELECT idCliente, primerNombre, primerApellido, telefono, activo
FROM   Cliente
WHERE  email = 'ana.garcia@email.com'
GO

-- Verificar historial de precios registrado
SELECT hp.idHistorial, pv.codigoSKU, hp.precioAnterior, hp.precioNuevo,
       hp.fechaCambio, hp.motivo
FROM   HistorialPrecio hp
JOIN   ProductoVariante pv ON pv.idVariante = hp.idVariante
GO

-- Verificar nuevo constraint en Categoria
SELECT name AS NombreConstraint, type_desc
FROM   sys.objects
WHERE  parent_object_id = OBJECT_ID('Categoria')
  AND  type IN ('UQ','C')
GO

-- Verificar proveedores activos
SELECT p.idProveedor, p.nombreEmpresa, p.ruc, p.email,
       p.sitioWeb, pais.nombrePais, p.activo
FROM   Proveedor p
JOIN   Pais      pais ON pais.idPais = p.idPais
GO

-- Verificar stock actualizado de la variante
SELECT pv.codigoSKU, inv.cantidadDisponible, inv.cantidadReservada,
       inv.ubicacionEstante
FROM   Inventario inv
JOIN   ProductoVariante pv ON pv.idVariante = inv.idVariante
WHERE  pv.codigoSKU = 'DELL-XPS15-001'
GO

-- Verificar producto desactivado
SELECT idProducto, nombre, activo
FROM   Producto
WHERE  nombre = 'Teclado Mecánico RGB'
GO

-- Verificar tabla ProductoProveedor recreada con constraints nuevos
SELECT name AS NombreConstraint, type_desc
FROM   sys.objects
WHERE  parent_object_id = OBJECT_ID('ProductoProveedor')
GO
