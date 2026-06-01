use master
go

if exists (select name from sys.databases where name = 'TechZone')
begin
    alter database TechZone set single_user with rollback immediate
    drop database TechZone
end
go

create database TechZone
go

use TechZone
go

-- ============================================================
-- SCHEMAS
-- Agrupación lógica de las tablas por dominio funcional:
--
--   geo        → Datos geográficos de referencia (países, estados, ciudades)
--   clientes   → Clientes y sus direcciones
--   catalogo   → Catálogo de productos, variantes e historial de precios
--   inventario → Bodegas y stock de variantes
--   ref        → Catálogos de estados (pedido, pago, envío) — datos de referencia inmutables
--                Nota: se evita el nombre "config" por ser reservado en SQL Server
--   marketing  → Tipos de descuento y cupones
--   ventas     → Pedidos, detalles, historial de estados y devoluciones
--   pagos      → Métodos de pago y transacciones
--   envios     → Transportistas y envíos
--   social     → Reseñas, carrito y sus ítems
-- ============================================================

create schema geo
go
create schema clientes
go
create schema catalogo
go
create schema inventario
go
create schema ref
go
create schema marketing
go
create schema ventas
go
create schema pagos
go
create schema envios
go
create schema social
go

-- ============================================================
-- SCHEMA: geo
-- ============================================================

create table geo.Pais (
    idPais      int            identity(1,1) constraint PK_Pais primary key,
    nombrePais  nvarchar(100)  not null,
    codigoISO   nvarchar(3)    not null constraint UQ_Pais_CodigoISO unique,
    moneda      nvarchar(3)    constraint DF_Pais_Moneda   default 'USD',
    is_active   bit            not null constraint DF_Pais_IsActive  default 1,
    created_at  datetime2      not null constraint DF_Pais_CreatedAt default getdate(),
    updated_at  datetime2      null,
    deleted_at  datetime2      null
)
go

create table geo.Estado (
    idEstado      int            identity(1,1) constraint PK_Estado primary key,
    nombreEstado  nvarchar(100)  not null,
    idPais        int            not null,
    is_active     bit            not null constraint DF_Estado_IsActive  default 1,
    created_at    datetime2      not null constraint DF_Estado_CreatedAt default getdate(),
    updated_at    datetime2      null,
    deleted_at    datetime2      null,
    constraint FK_Estado_Pais foreign key (idPais) references geo.Pais(idPais)
)
go

create table geo.Ciudad (
    idCiudad      int            identity(1,1) constraint PK_Ciudad primary key,
    nombreCiudad  nvarchar(100)  not null,
    codigoPostal  nvarchar(20)   not null,
    zonaHoraria   nvarchar(50)   constraint DF_Ciudad_ZonaHoraria default 'UTC-6',
    idEstado      int            not null,
    is_active     bit            not null constraint DF_Ciudad_IsActive  default 1,
    created_at    datetime2      not null constraint DF_Ciudad_CreatedAt default getdate(),
    updated_at    datetime2      null,
    deleted_at    datetime2      null,
    constraint FK_Ciudad_Estado foreign key (idEstado) references geo.Estado(idEstado)
)
go

-- ============================================================
-- SCHEMA: clientes
-- ============================================================

create table clientes.Cliente (
    idCliente               int            identity(1,1) constraint PK_Cliente primary key,
    primerNombre            nvarchar(80)   not null,
    segundoNombre           nvarchar(80)   null,
    primerApellido          nvarchar(80)   not null,
    segundoApellido         nvarchar(80)   null,
    email                   nvarchar(255)  not null constraint UQ_Cliente_Email unique,
    telefono                nvarchar(20)   null,
    fechaRegistro           date           not null constraint DF_Cliente_FechaRegistro default cast(getdate() as date),
    idCiudadPredeterminada  int            null,
    is_active               bit            not null constraint DF_Cliente_IsActive  default 1,
    created_at              datetime2      not null constraint DF_Cliente_CreatedAt default getdate(),
    updated_at              datetime2      null,
    deleted_at              datetime2      null,
    constraint FK_Cliente_Ciudad foreign key (idCiudadPredeterminada) references geo.Ciudad(idCiudad)
)
go

create table clientes.ClienteDireccion (
    idDireccion      int            identity(1,1) constraint PK_ClienteDireccion primary key,
    idCliente        int            not null,
    alias            nvarchar(50)   not null constraint DF_Direccion_Alias          default 'Principal',
    calle            nvarchar(150)  not null,
    numero           nvarchar(20)   not null,
    apartamento      nvarchar(50)   null,
    puntoReferencia  nvarchar(max)  null,
    idCiudad         int            not null,
    predeterminada   bit            not null constraint DF_Direccion_Predeterminada default 0,
    is_active        bit            not null constraint DF_Direccion_IsActive        default 1,
    created_at       datetime2      not null constraint DF_ClienteDireccion_CreatedAt default getdate(),
    updated_at       datetime2      null,
    deleted_at       datetime2      null,
    constraint FK_Direccion_Cliente foreign key (idCliente) references clientes.Cliente(idCliente),
    constraint FK_Direccion_Ciudad  foreign key (idCiudad)  references geo.Ciudad(idCiudad)
)
go

-- ============================================================
-- SCHEMA: catalogo
-- ============================================================

create table catalogo.Categoria (
    idCategoria      int            identity(1,1) constraint PK_Categoria primary key,
    nombre           nvarchar(100)  not null constraint UQ_Categoria_Nombre unique,
    descripcion      nvarchar(max)  null,
    idCategoriaPadre int            null,
    is_active        bit            not null constraint DF_Categoria_IsActive  default 1,
    created_at       datetime2      not null constraint DF_Categoria_CreatedAt default getdate(),
    updated_at       datetime2      null,
    deleted_at       datetime2      null,
    constraint FK_Categoria_Padre foreign key (idCategoriaPadre) references catalogo.Categoria(idCategoria)
)
go

create table catalogo.Producto (
    idProducto   int            identity(1,1) constraint PK_Producto primary key,
    nombre       nvarchar(200)  not null,
    descripcion  nvarchar(max)  null,
    marca        nvarchar(100)  not null,
    peso_kg      decimal(8,3)   constraint DF_Producto_Peso     default 0.000,
    idCategoria  int            not null,
    is_active    bit            not null constraint DF_Producto_IsActive  default 1,
    created_at   datetime2      not null constraint DF_Producto_CreatedAt default getdate(),
    updated_at   datetime2      null,
    deleted_at   datetime2      null,
    constraint FK_Producto_Categoria foreign key (idCategoria) references catalogo.Categoria(idCategoria)
)
go

create table catalogo.ProductoVariante (
    idVariante          int            identity(1,1) constraint PK_ProductoVariante primary key,
    idProducto          int            not null,
    codigoSKU           nvarchar(50)   not null constraint UQ_Variante_SKU unique,
    configuracionTexto  nvarchar(max)  not null,
    precioActual        decimal(12,2)  not null constraint CHK_Variante_Precio check (precioActual >= 0),
    moneda              nvarchar(3)    constraint DF_Variante_Moneda          default 'USD',
    is_active           bit            not null constraint DF_ProductoVariante_IsActive  default 1,
    created_at          datetime2      not null constraint DF_ProductoVariante_CreatedAt default getdate(),
    updated_at          datetime2      null,
    deleted_at          datetime2      null,
    constraint FK_Variante_Producto foreign key (idProducto) references catalogo.Producto(idProducto)
)
go

create table catalogo.HistorialPrecio (
    idHistorial    int            identity(1,1) constraint PK_HistorialPrecio primary key,
    idVariante     int            not null,
    precioAnterior decimal(12,2)  not null constraint CHK_Historial_PrecioAnterior check (precioAnterior >= 0),
    precioNuevo    decimal(12,2)  not null constraint CHK_Historial_PrecioNuevo    check (precioNuevo    >= 0),
    fechaCambio    datetime2      not null constraint DF_Historial_FechaCambio     default getdate(),
    motivo         nvarchar(max)  null,
    created_at     datetime2      not null constraint DF_HistorialPrecio_CreatedAt default getdate(),
    updated_at     datetime2      null,
    deleted_at     datetime2      null,
    constraint FK_Historial_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante)
)
go

-- ============================================================
-- SCHEMA: inventario
-- ============================================================

create table inventario.Bodega (
    idBodega      int            identity(1,1) constraint PK_Bodega primary key,
    nombre        nvarchar(100)  not null,
    direccion     nvarchar(max)  not null,
    idCiudad      int            not null,
    capacidad_m3  decimal(10,2)  constraint DF_Bodega_Capacidad default 0.00,
    is_active     bit            not null constraint DF_Bodega_IsActive  default 1,
    created_at    datetime2      not null constraint DF_Bodega_CreatedAt default getdate(),
    updated_at    datetime2      null,
    deleted_at    datetime2      null,
    constraint FK_Bodega_Ciudad foreign key (idCiudad) references geo.Ciudad(idCiudad)
)
go

create table inventario.Inventario (
    idInventario       int           identity(1,1) constraint PK_Inventario primary key,
    idVariante         int           not null,
    idBodega           int           not null,
    cantidadDisponible int           not null constraint DF_Inventario_Disponible default 0  constraint CHK_Inventario_Disponible check (cantidadDisponible >= 0),
    cantidadReservada  int           not null constraint DF_Inventario_Reservada  default 0  constraint CHK_Inventario_Reservada  check (cantidadReservada  >= 0),
    umbralReorden      int           not null constraint DF_Inventario_Umbral     default 10 constraint CHK_Inventario_Umbral     check (umbralReorden      >= 0),
    ubicacionEstante   nvarchar(50)  null,
    created_at         datetime2     not null constraint DF_Inventario_CreatedAt default getdate(),
    updated_at         datetime2     null,
    deleted_at         datetime2     null,
    constraint FK_Inventario_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante),
    constraint FK_Inventario_Bodega   foreign key (idBodega)   references inventario.Bodega(idBodega),
    constraint UQ_Inventario_Variante_Bodega unique (idVariante, idBodega)
)
go

-- ============================================================
-- SCHEMA: ref  (catálogos de estados — referencia inmutable)
-- ============================================================

create table ref.EstadoPedido (
    idEstado       int            constraint PK_EstadoPedido primary key,
    nombre         nvarchar(50)   not null constraint UQ_EstadoPedido_Nombre unique,
    descripcion    nvarchar(max)  null,
    ordenSecuencia int            not null,
    colorUI        nvarchar(7)    constraint DF_EstadoPedido_Color   default '#6C757D',
    created_at     datetime2      not null constraint DF_EstadoPedido_CreatedAt default getdate(),
    updated_at     datetime2      null,
    deleted_at     datetime2      null
)
go

create table ref.EstadoPago (
    idEstadoPago  int            constraint PK_EstadoPago primary key,
    nombre        nvarchar(50)   not null constraint UQ_EstadoPago_Nombre unique,
    descripcion   nvarchar(max)  null,
    created_at    datetime2      not null constraint DF_EstadoPago_CreatedAt default getdate(),
    updated_at    datetime2      null,
    deleted_at    datetime2      null
)
go

create table ref.EstadoEnvio (
    idEstadoEnvio        int            constraint PK_EstadoEnvio primary key,
    nombre               nvarchar(50)   not null constraint UQ_EstadoEnvio_Nombre unique,
    descripcion          nvarchar(max)  null,
    notificacionCliente  bit            constraint DF_EstadoEnvio_Notificacion default 0,
    requiereFirma        bit            constraint DF_EstadoEnvio_Firma        default 0,
    created_at           datetime2      not null constraint DF_EstadoEnvio_CreatedAt default getdate(),
    updated_at           datetime2      null,
    deleted_at           datetime2      null
)
go

-- ============================================================
-- SCHEMA: marketing
-- ============================================================

create table marketing.TipoDescuento (
    idTipoDescuento    int            identity(1,1) constraint PK_TipoDescuento primary key,
    nombre             nvarchar(50)   not null constraint UQ_TipoDescuento_Nombre unique,
    formulaAplicacion  nvarchar(max)  not null,
    ejemplo            nvarchar(max)  null,
    created_at         datetime2      not null constraint DF_TipoDescuento_CreatedAt default getdate(),
    updated_at         datetime2      null,
    deleted_at         datetime2      null
)
go

create table marketing.Cupon (
    idCupon               int            identity(1,1) constraint PK_Cupon primary key,
    codigo                nvarchar(50)   not null constraint UQ_Cupon_Codigo unique,
    idTipoDescuento       int            not null,
    valor                 decimal(10,2)  not null constraint DF_Cupon_Valor  default 0.00,
    fechaInicio           date           not null,
    fechaExpiracion       date           not null,
    usosMaximos           int            not null constraint DF_Cupon_UsosMax default 1,
    usosActuales          int            not null constraint DF_Cupon_UsosAct default 0,
    montoMinimoPedido     decimal(12,2)  constraint DF_Cupon_Minimo          default 0.00,
    restriccionCategoria  int            null,
    restriccionProducto   int            null,
    is_active             bit            not null constraint DF_Cupon_IsActive  default 1,
    created_at            datetime2      not null constraint DF_Cupon_CreatedAt default getdate(),
    updated_at            datetime2      null,
    deleted_at            datetime2      null,
    constraint FK_Cupon_TipoDescuento foreign key (idTipoDescuento)     references marketing.TipoDescuento(idTipoDescuento),
    constraint FK_Cupon_Categoria     foreign key (restriccionCategoria) references catalogo.Categoria(idCategoria),
    constraint FK_Cupon_Producto      foreign key (restriccionProducto)  references catalogo.Producto(idProducto)
)
go

-- ============================================================
-- SCHEMA: pagos
-- ============================================================

create table pagos.MetodoPago (
    idMetodo              int            identity(1,1) constraint PK_MetodoPago primary key,
    nombre                nvarchar(50)   not null constraint UQ_MetodoPago_Nombre unique,
    tipo                  nvarchar(50)   not null constraint CHK_MetodoPago_Tipo check (tipo in ('tarjeta','billetera_digital','transferencia','contra_entrega')),
    comisionPorcentaje    decimal(5,2)   constraint DF_MetodoPago_Comision      default 0.00,
    requiereVerificacion  bit            constraint DF_MetodoPago_Verificacion   default 1,
    is_active             bit            not null constraint DF_MetodoPago_IsActive  default 1,
    created_at            datetime2      not null constraint DF_MetodoPago_CreatedAt default getdate(),
    updated_at            datetime2      null,
    deleted_at            datetime2      null
)
go

-- ============================================================
-- SCHEMA: envios
-- ============================================================

create table envios.Transportista (
    idTransportista             int            identity(1,1) constraint PK_Transportista primary key,
    nombreEmpresa               nvarchar(100)  not null constraint UQ_Transportista_Nombre unique,
    contacto                    nvarchar(max)  null,
    tarifaBase                  decimal(8,2)   constraint DF_Transportista_Tarifa  default 0.00,
    tiempoEntregaPromedio_dias  int            constraint DF_Transportista_Tiempo   default 1,
    is_active                   bit            not null constraint DF_Transportista_IsActive  default 1,
    created_at                  datetime2      not null constraint DF_Transportista_CreatedAt default getdate(),
    updated_at                  datetime2      null,
    deleted_at                  datetime2      null
)
go

-- ============================================================
-- SCHEMA: ventas
-- (depende de: clientes, catalogo, ref, marketing, pagos, envios)
-- ============================================================

create table ventas.Pedido (
    idPedido             int            identity(1,1) constraint PK_Pedido primary key,
    fechaPedido          datetime2      not null constraint DF_Pedido_Fecha   default getdate(),
    idCliente            int            not null,
    idDireccionEnvio     int            not null,
    idEstadoPedido       int            not null constraint DF_Pedido_Estado  default 1,
    montoTotalFacturado  decimal(12,2)  null,
    notas                nvarchar(max)  null,
    created_at           datetime2      not null constraint DF_Pedido_CreatedAt default getdate(),
    updated_at           datetime2      null,
    deleted_at           datetime2      null,
    constraint FK_Pedido_Cliente   foreign key (idCliente)        references clientes.Cliente(idCliente),
    constraint FK_Pedido_Direccion foreign key (idDireccionEnvio) references clientes.ClienteDireccion(idDireccion),
    constraint FK_Pedido_Estado    foreign key (idEstadoPedido)   references ref.EstadoPedido(idEstado)
)
go

create table ventas.DetallePedido (
    idPedido        int            not null,
    idVariante      int            not null,
    cantidad        int            not null constraint CHK_Detalle_Cantidad check (cantidad > 0),
    precioSnapshot  decimal(12,2)  not null constraint CHK_Detalle_Precio   check (precioSnapshot >= 0),
    created_at      datetime2      not null constraint DF_DetallePedido_CreatedAt default getdate(),
    updated_at      datetime2      null,
    deleted_at      datetime2      null,
    constraint PK_DetallePedido    primary key (idPedido, idVariante),
    constraint FK_Detalle_Pedido   foreign key (idPedido)   references ventas.Pedido(idPedido),
    constraint FK_Detalle_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante)
)
go

create table ventas.PedidoHistorialEstado (
    idHistorialEstado  int            identity(1,1) constraint PK_PedidoHistorialEstado primary key,
    idPedido           int            not null,
    idEstadoAnterior   int            null,
    idEstadoNuevo      int            not null,
    fechaCambio        datetime2      not null constraint DF_PedidoHistorialEstado_FechaCambio default getdate(),
    observacion        nvarchar(max)  null,
    created_at         datetime2      not null constraint DF_PedidoHistorialEstado_CreatedAt   default getdate(),
    updated_at         datetime2      null,
    deleted_at         datetime2      null,
    constraint FK_HistEstado_Pedido   foreign key (idPedido)         references ventas.Pedido(idPedido),
    constraint FK_HistEstado_Anterior foreign key (idEstadoAnterior) references ref.EstadoPedido(idEstado),
    constraint FK_HistEstado_Nuevo    foreign key (idEstadoNuevo)    references ref.EstadoPedido(idEstado)
)
go

create table ventas.Pedido_Cupon (
    idPedidoCupon  int            identity(1,1) constraint PK_PedidoCupon primary key,
    idPedido       int            not null,
    idCupon        int            not null,
    montoAplicado  decimal(12,2)  not null constraint DF_PedidoCupon_Monto default 0.00,
    created_at     datetime2      not null constraint DF_PedidoCupon_CreatedAt default getdate(),
    updated_at     datetime2      null,
    deleted_at     datetime2      null,
    constraint FK_PedidoCupon_Pedido foreign key (idPedido) references ventas.Pedido(idPedido),
    constraint FK_PedidoCupon_Cupon  foreign key (idCupon)  references marketing.Cupon(idCupon),
    constraint UQ_PedidoCupon_Pedido_Cupon unique (idPedido, idCupon)
)
go

create table ventas.Devolucion (
    idDevolucion     int            identity(1,1) constraint PK_Devolucion primary key,
    idPedido         int            not null,
    idVariante       int            not null,
    cantidad         int            not null constraint CHK_Devolucion_Cantidad check (cantidad > 0),
    motivo           nvarchar(max)  not null,
    estado           nvarchar(50)   not null constraint DF_Devolucion_Estado default 'Solicitada'
                                    constraint CHK_Devolucion_Estado check (estado in ('Solicitada','Aprobada','Rechazada','Completada')),
    montoReembolso   decimal(12,2)  null constraint CHK_Devolucion_Monto check (montoReembolso >= 0),
    fechaSolicitud   datetime2      not null constraint DF_Devolucion_FechaSolicitud default getdate(),
    fechaResolucion  datetime2      null,
    created_at       datetime2      not null constraint DF_Devolucion_CreatedAt default getdate(),
    updated_at       datetime2      null,
    deleted_at       datetime2      null,
    constraint FK_Devolucion_Pedido   foreign key (idPedido)   references ventas.Pedido(idPedido),
    constraint FK_Devolucion_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante)
)
go

create table pagos.Pago (
    idPago             int            identity(1,1) constraint PK_Pago primary key,
    idPedido           int            not null constraint UQ_Pago_Pedido unique,
    monto              decimal(12,2)  not null constraint CHK_Pago_Monto check (monto >= 0),
    idMetodoPago       int            not null,
    idEstadoPago       int            not null constraint DF_Pago_Estado default 1,
    fechaTransaccion   datetime2      null,
    referenciaGateway  nvarchar(100)  null,
    created_at         datetime2      not null constraint DF_Pago_CreatedAt default getdate(),
    updated_at         datetime2      null,
    deleted_at         datetime2      null,
    constraint FK_Pago_Pedido  foreign key (idPedido)     references ventas.Pedido(idPedido),
    constraint FK_Pago_Metodo  foreign key (idMetodoPago) references pagos.MetodoPago(idMetodo),
    constraint FK_Pago_Estado  foreign key (idEstadoPago) references ref.EstadoPago(idEstadoPago)
)
go

create table envios.Envio (
    idEnvio               int            identity(1,1) constraint PK_Envio primary key,
    idPedido              int            not null constraint UQ_Envio_Pedido unique,
    idEstadoEnvio         int            not null constraint DF_Envio_Estado default 1,
    fechaEnvio            date           null,
    fechaEntregaEstimada  date           null,
    idTransportista       int            not null,
    numeroTracking        nvarchar(100)  null,
    created_at            datetime2      not null constraint DF_Envio_CreatedAt default getdate(),
    updated_at            datetime2      null,
    deleted_at            datetime2      null,
    constraint FK_Envio_Pedido        foreign key (idPedido)           references ventas.Pedido(idPedido),
    constraint FK_Envio_Estado        foreign key (idEstadoEnvio)      references ref.EstadoEnvio(idEstadoEnvio),
    constraint FK_Envio_Transportista foreign key (idTransportista)    references envios.Transportista(idTransportista)
)
go

-- ============================================================
-- SCHEMA: social
-- ============================================================

create table social.Resena (
    idResena     int            identity(1,1) constraint PK_Resena primary key,
    idVariante   int            not null,
    idCliente    int            not null,
    calificacion int            not null constraint CHK_Resena_Calificacion check (calificacion between 1 and 5),
    comentario   nvarchar(max)  null,
    fechaResena  datetime2      not null constraint DF_Resena_Fecha      default getdate(),
    verificada   bit            constraint DF_Resena_Verificada          default 0,
    created_at   datetime2      not null constraint DF_Resena_CreatedAt  default getdate(),
    updated_at   datetime2      null,
    deleted_at   datetime2      null,
    constraint FK_Resena_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante),
    constraint FK_Resena_Cliente  foreign key (idCliente)  references clientes.Cliente(idCliente)
)
go

create table social.Carrito (
    idCarrito        int        identity(1,1) constraint PK_Carrito primary key,
    idCliente        int        not null constraint UQ_Carrito_Cliente unique,
    fechaCreacion    datetime2  not null constraint DF_Carrito_Creacion    default getdate(),
    fechaExpiracion  datetime2  null,
    created_at       datetime2  not null constraint DF_Carrito_CreatedAt   default getdate(),
    updated_at       datetime2  null,
    deleted_at       datetime2  null,
    constraint FK_Carrito_Cliente foreign key (idCliente) references clientes.Cliente(idCliente)
)
go

create table social.CarritoItem (
    idCarritoItem  int        identity(1,1) constraint PK_CarritoItem primary key,
    idCarrito      int        not null,
    idVariante     int        not null,
    cantidad       int        not null constraint CHK_Item_Cantidad check (cantidad > 0),
    fechaAgregado  datetime2  not null constraint DF_Item_Agregado     default getdate(),
    created_at     datetime2  not null constraint DF_CarritoItem_CreatedAt default getdate(),
    updated_at     datetime2  null,
    deleted_at     datetime2  null,
    constraint FK_Item_Carrito  foreign key (idCarrito)  references social.Carrito(idCarrito),
    constraint FK_Item_Variante foreign key (idVariante) references catalogo.ProductoVariante(idVariante),
    constraint UQ_CarritoItem_Carrito_Variante unique (idCarrito, idVariante)
)
go

-- ============================================================
-- DATOS DE PRUEBA
-- ============================================================

insert into geo.Pais (nombrePais, codigoISO, moneda) values
('Nicaragua',      'NIC', 'NIO'),
('Estados Unidos', 'USA', 'USD'),
('Costa Rica',     'CRI', 'CRC')
go

insert into geo.Estado (nombreEstado, idPais) values
('Managua',    1),
('León',       1),
('California', 2),
('San José',   3)
go

insert into geo.Ciudad (nombreCiudad, codigoPostal, zonaHoraria, idEstado) values
('Managua',       '11001', 'UTC-6', 1),
('León',          '21001', 'UTC-6', 2),
('San Francisco', '94102', 'UTC-8', 3),
('San José',      '10101', 'UTC-6', 4)
go

insert into clientes.Cliente (primerNombre, segundoNombre, primerApellido, segundoApellido, email, telefono, fechaRegistro, idCiudadPredeterminada) values
('Ana',    'María',  'García',    'López',    'ana.garcia@email.com',   '555-0101', '2026-01-15', 1),
('Carlos', 'Andrés', 'López',     'Martínez', 'carlos.lopez@email.com', '555-0202', '2026-03-20', 2),
('María',  null,     'Rodríguez', 'Santos',   'maria.r@email.com',      '555-0303', '2026-04-10', 2)
go

-- Direcciones:
--   idDireccion=1  → idCliente=1 (Ana),    ciudad Managua
--   idDireccion=2  → idCliente=1 (Ana),    ciudad Managua
--   idDireccion=3  → idCliente=2 (Carlos), ciudad León
--   idDireccion=4  → idCliente=3 (María),  ciudad San José
insert into clientes.ClienteDireccion (idCliente, alias, calle, numero, apartamento, puntoReferencia, idCiudad, predeterminada) values
(1, 'Casa',    'Av. Principal',   '123', 'Apto 4B', 'Frente al parque',       1, 1),
(1, 'Oficina', 'Calle Negocios',  '456', 'Piso 3',  'Edificio Torre A',       1, 0),
(2, 'Casa',    'Calle Secundaria','456', null,       'Cerca del mercado',      2, 1),
(3, 'Casa',    'Calle Principal', '789', null,       'Frente al supermercado', 4, 1)
go

insert into catalogo.Categoria (nombre, descripcion, idCategoriaPadre) values
('Computadoras', 'Equipos de cómputo',         null),
('Accesorios',   'Periféricos y complementos', null),
('Monitores',    'Pantallas y displays',        1),
('Laptops',      'Computadoras portátiles',     1),
('Mouses',       'Dispositivos apuntadores',    2),
('Teclados',     'Dispositivos de entrada',     2)
go

insert into catalogo.Producto (nombre, descripcion, marca, peso_kg, idCategoria) values
('Laptop Dell XPS 15',       'Línea premium de Dell',     'Dell',     2.100, 4),
('Mouse Logitech MX Master', 'Línea Master de Logitech',  'Logitech', 0.150, 5),
('Monitor Samsung 27 pulg',  'Línea profesional Samsung', 'Samsung',  5.800, 3),
('Teclado Mecánico RGB',     'Línea gaming TechKey',      'TechKey',  1.200, 6)
go

-- Variantes:
--   idVariante=1 → Dell XPS i7   $1,299.99
--   idVariante=2 → Dell XPS i9   $1,899.99
--   idVariante=3 → Mouse Logitech  $79.99
--   idVariante=4 → Monitor Samsung $349.99
--   idVariante=5 → Teclado RGB     $129.99
insert into catalogo.ProductoVariante (idProducto, codigoSKU, configuracionTexto, precioActual, moneda) values
(1, 'DELL-XPS15-001', 'Intel i7, 16GB RAM, 512GB SSD',     1299.99, 'USD'),
(1, 'DELL-XPS15-002', 'Intel i9, 32GB RAM, 1TB SSD',       1899.99, 'USD'),
(2, 'LOG-MX-002',     'Ergonómico, inalámbrico, 4000 DPI',   79.99, 'USD'),
(3, 'SAM-27-003',     '4K UHD, IPS, 144Hz',                 349.99, 'USD'),
(4, 'TKB-RGB-004',    'Switches Cherry MX Red',              129.99, 'USD')
go

insert into inventario.Bodega (nombre, direccion, idCiudad, capacidad_m3) values
('Bodega Central', 'Zona Industrial Norte', 1, 5000.00),
('Bodega Sur',     'Parque Logístico Sur',  1, 3000.00)
go

-- Inventario refleja estado POST-venta de los pedidos de prueba:
--
--   Pedido 1 (pagado): 1x variante-1 (Dell i7) + 2x variante-3 (Mouse)
--   Pedido 2 (pagado): 1x variante-4 (Monitor)
--   Pedido 3 (pendiente): 1x variante-5 (Teclado) — aún reservado, no descontado
--
--   Variante 1 (Dell i7):   inicial=6  → vendida 1  → disponible=5,  reservada=0
--   Variante 2 (Dell i9):   sin ventas → disponible=12, reservada=0
--   Variante 3 (Mouse):     inicial=142 → vendidas 2 → disponible=140, reservada=0
--   Variante 4 (Monitor):   inicial=36  → vendida 1  → disponible=35, reservada=0
--   Variante 5 (Teclado):   pedido pendiente → disponible=75, reservada=1
insert into inventario.Inventario (idVariante, idBodega, cantidadDisponible, cantidadReservada, umbralReorden, ubicacionEstante) values
(1, 1,   5,  0, 20, 'A-12-3'),
(2, 1,  12,  0,  3, 'A-12-4'),
(3, 1, 140,  0, 30, 'B-05-1'),
(4, 2,  35,  0, 10, 'C-08-2'),
(5, 1,  75,  1, 20, 'B-03-4')
go

insert into ref.EstadoPedido (idEstado, nombre, descripcion, ordenSecuencia, colorUI) values
(1, 'Pendiente',   'Pedido creado, esperando pago', 1, '#FFC107'),
(2, 'Pagado',      'Pago confirmado',               2, '#28A745'),
(3, 'Enviado',     'Pedido despachado',             3, '#17A2B8'),
(4, 'Entregado',   'Pedido entregado al cliente',   4, '#6C757D'),
(5, 'Cancelado',   'Pedido cancelado',              5, '#DC3545'),
(6, 'Reembolsado', 'Pago devuelto al cliente',      6, '#6F42C1')
go

insert into ref.EstadoPago (idEstadoPago, nombre, descripcion) values
(1, 'Pendiente',   'Transacción iniciada, esperando confirmación'),
(2, 'En Proceso',  'Procesando en gateway'),
(3, 'Completado',  'Pago confirmado exitosamente'),
(4, 'Fallido',     'Transacción rechazada o con error'),
(5, 'Reembolsado', 'Dinero devuelto al cliente')
go

insert into ref.EstadoEnvio (idEstadoEnvio, nombre, descripcion, notificacionCliente, requiereFirma) values
(1, 'Pendiente',                 'Esperando despacho',            0, 0),
(2, 'Recolección',               'Recolectado por transportista', 1, 0),
(3, 'En Tránsito',               'En ruta hacia destino',         1, 0),
(4, 'En Centro de Distribución', 'Llegó a centro logístico',      1, 0),
(5, 'En Ruta de Entrega',        'En camino a dirección final',   1, 0),
(6, 'Entregado',                 'Entregado al cliente',          1, 1),
(7, 'Devuelto',                  'Devuelto a origen',             1, 1),
(8, 'Cancelado',                 'Envío cancelado',               0, 0)
go

insert into pagos.MetodoPago (nombre, tipo, comisionPorcentaje, requiereVerificacion) values
('Tarjeta de Crédito',    'tarjeta',          2.50, 1),
('PayPal',                'billetera_digital', 3.00, 1),
('Transferencia Bancaria','transferencia',     0.00, 1),
('Contra Entrega',        'contra_entrega',    0.00, 0)
go

insert into envios.Transportista (nombreEmpresa, contacto, tarifaBase, tiempoEntregaPromedio_dias) values
('FedEx', 'contacto@fedex.com', 5.00, 2),
('DHL',   'contacto@dhl.com',   7.50, 3)
go

insert into marketing.TipoDescuento (nombre, formulaAplicacion, ejemplo) values
('Porcentaje',      'precio * (1 - valor/100)',      '10% de descuento'),
('Monto Fijo',      'precio - valor',                '$20 de descuento'),
('Envío Gratis',    'envio = 0',                     'Envío sin costo'),
('Compra X paga Y', 'aplicar descuento por volumen', 'Compra 3 paga 2')
go

insert into marketing.Cupon (codigo, idTipoDescuento, valor, fechaInicio, fechaExpiracion, usosMaximos, usosActuales, montoMinimoPedido, restriccionCategoria, restriccionProducto) values
('DESC10',       1, 10.00, '2026-05-01', '2026-06-01', 100, 45,  50.00, null, null),
('ENVIOFREE',    3,  0.00, '2026-05-10', '2026-05-31', 500, 230,  0.00, null, null),
('WELCOME20',    1, 20.00, '2026-01-01', '2026-12-31', 200, 89,  30.00,    2, null),
('ACCESORIOS15', 1, 15.00, '2026-05-01', '2026-05-31', 150, 34,   0.00,    2, null),
('MOUSELOGI10',  1, 10.00, '2026-05-15', '2026-06-15', 100, 34,   0.00, null,    2)
go

-- Pedidos:
--   Pedido 1: Ana (cliente 1), dirección 1 (suya), estado Pagado
--             bruto: 1×$1,299.99 + 2×$79.99 = $1,459.97
--             cupón DESC10 (10%): $1,459.97 × 10% = $145.997 → redondeado $146.00
--             total neto: $1,459.97 − $146.00 = $1,313.97
--   Pedido 2: María (cliente 3), dirección 4 (suya), estado Pagado
--             bruto: 1×$349.99 = $349.99, sin cupón
--   Pedido 3: Ana (cliente 1), dirección 1, estado Pendiente
--             bruto: 1×$129.99 = $129.99, sin cupón
insert into ventas.Pedido (fechaPedido, idCliente, idDireccionEnvio, idEstadoPedido, montoTotalFacturado, notas) values
('2026-05-15 10:30:00', 1, 1, 2, 1313.97, 'Dejar en portería'),
('2026-05-18 14:00:00', 3, 4, 2,  349.99, null),
('2026-05-19 09:15:00', 1, 1, 1,  129.99, null)
go

insert into ventas.DetallePedido (idPedido, idVariante, cantidad, precioSnapshot) values
(1, 1, 1, 1299.99),  -- Dell XPS i7
(1, 3, 2,   79.99),  -- Mouse Logitech × 2
(2, 4, 1,  349.99),  -- Monitor Samsung
(3, 5, 1,  129.99)   -- Teclado RGB
go

insert into ventas.PedidoHistorialEstado (idPedido, idEstadoAnterior, idEstadoNuevo, observacion) values
(1, null, 1, 'Pedido creado'),
(1,    1, 2, 'Pago confirmado vía gateway'),
(2, null, 1, 'Pedido creado'),
(2,    1, 2, 'Pago confirmado vía PayPal'),
(3, null, 1, 'Pedido creado')
go

-- montoAplicado = 10% de $1,459.97 = $145.997 → $146.00
insert into ventas.Pedido_Cupon (idPedido, idCupon, montoAplicado) values
(1, 1, 146.00)
go

insert into pagos.Pago (idPedido, monto, idMetodoPago, idEstadoPago, fechaTransaccion, referenciaGateway) values
(1, 1313.97, 1, 3, '2026-05-15 14:30:00', 'TXN-789456123'),
(2,  349.99, 2, 3, '2026-05-18 10:15:00', 'PPN-321654987'),
(3,  129.99, 2, 1,  null,                  null)
go

insert into envios.Envio (idPedido, idEstadoEnvio, fechaEnvio, fechaEntregaEstimada, idTransportista, numeroTracking) values
(1, 5, '2026-05-16', '2026-05-17', 1, 'FX123456789'),
(2, 5, '2026-05-19', '2026-05-22', 2, 'DHL987654321'),
(3, 1,  null,        '2026-05-23', 2,  null)
go

insert into social.Resena (idVariante, idCliente, calificacion, comentario, fechaResena, verificada) values
(1, 1, 5, 'Excelente producto, muy rápido y silencioso. La pantalla es espectacular.', '2026-05-20 16:45:00', 1)
go

insert into social.Carrito (idCliente, fechaCreacion, fechaExpiracion) values
(1, '2026-05-20 09:00:00', '2026-05-21 09:00:00')
go

insert into social.CarritoItem (idCarrito, idVariante, cantidad, fechaAgregado) values
(1, 4, 1, '2026-05-20 09:15:00'),
(1, 5, 2, '2026-05-20 09:20:00')
go

-- ============================================================
-- QUERIES DE EJEMPLO
-- ============================================================

-- ------------------------------------------------------------
-- BÁSICOS
-- ------------------------------------------------------------

-- 1. Todos los clientes activos con su ciudad
select
    c.idCliente,
    c.primerNombre + ' ' + c.primerApellido  as nombreCompleto,
    c.email,
    ci.nombreCiudad
from clientes.Cliente c
    inner join geo.Ciudad ci on ci.idCiudad = c.idCiudadPredeterminada
where c.is_active = 1
go

-- 2. Variantes de un producto con su stock total en todas las bodegas
select
    pv.codigoSKU,
    pv.configuracionTexto,
    pv.precioActual,
    sum(i.cantidadDisponible) as stockTotal,
    sum(i.cantidadReservada)  as reservadoTotal
from catalogo.ProductoVariante pv
    inner join inventario.Inventario i on i.idVariante = pv.idVariante
where pv.idProducto = 1
  and pv.is_active  = 1
group by pv.idVariante, pv.codigoSKU, pv.configuracionTexto, pv.precioActual
go

-- 3. Cupones vigentes con usos disponibles a la fecha de hoy
select
    c.codigo,
    td.nombre                              as tipoDescuento,
    c.valor,
    c.usosMaximos - c.usosActuales         as usosDisponibles,
    c.fechaExpiracion
from marketing.Cupon c
    inner join marketing.TipoDescuento td on td.idTipoDescuento = c.idTipoDescuento
where c.is_active       = 1
  and c.fechaInicio    <= cast(getdate() as date)
  and c.fechaExpiracion >= cast(getdate() as date)
  and c.usosActuales    < c.usosMaximos
go

-- 4. Detalle completo de un pedido específico
select
    p.idPedido,
    p.fechaPedido,
    ep.nombre                               as estadoPedido,
    pr.nombre                               as producto,
    pv.configuracionTexto                   as variante,
    dp.cantidad,
    dp.precioSnapshot,
    dp.cantidad * dp.precioSnapshot         as subtotal
from ventas.Pedido p
    inner join ref.EstadoPedido              ep on ep.idEstado    = p.idEstadoPedido
    inner join ventas.DetallePedido          dp on dp.idPedido    = p.idPedido
    inner join catalogo.ProductoVariante     pv on pv.idVariante  = dp.idVariante
    inner join catalogo.Producto             pr on pr.idProducto  = pv.idProducto
where p.idPedido = 1
go

-- ------------------------------------------------------------
-- INTERMEDIOS
-- ------------------------------------------------------------

-- 5. Resumen de pedidos por cliente: total gastado y cantidad de pedidos
select
    c.idCliente,
    c.primerNombre + ' ' + c.primerApellido  as cliente,
    count(p.idPedido)                        as totalPedidos,
    sum(p.montoTotalFacturado)               as totalGastado,
    max(p.fechaPedido)                       as ultimoPedido
from clientes.Cliente c
    inner join ventas.Pedido       p  on p.idCliente   = c.idCliente
    inner join ref.EstadoPedido    ep on ep.idEstado   = p.idEstadoPedido
where ep.nombre  != 'Cancelado'
  and c.is_active = 1
group by c.idCliente, c.primerNombre, c.primerApellido
order by totalGastado desc
go

-- 6. Variantes con stock igual o por debajo del umbral de reorden
select
    pr.nombre                                     as producto,
    pv.codigoSKU,
    b.nombre                                      as bodega,
    i.cantidadDisponible,
    i.umbralReorden,
    i.cantidadDisponible - i.umbralReorden        as diferencia
from inventario.Inventario i
    inner join catalogo.ProductoVariante pv on pv.idVariante = i.idVariante
    inner join catalogo.Producto         pr on pr.idProducto = pv.idProducto
    inner join inventario.Bodega          b on b.idBodega    = i.idBodega
where i.cantidadDisponible <= i.umbralReorden
  and pv.is_active = 1
  and b.is_active  = 1
order by diferencia asc
go

-- 7. Historial de cambios de precio del último mes
select
    pr.nombre             as producto,
    pv.codigoSKU,
    hp.precioAnterior,
    hp.precioNuevo,
    hp.precioNuevo - hp.precioAnterior  as variacion,
    hp.motivo,
    hp.fechaCambio
from catalogo.HistorialPrecio hp
    inner join catalogo.ProductoVariante pv on pv.idVariante = hp.idVariante
    inner join catalogo.Producto         pr on pr.idProducto = pv.idProducto
where hp.fechaCambio >= dateadd(month, -1, getdate())
order by hp.fechaCambio desc
go

-- ------------------------------------------------------------
-- AVANZADOS
-- ------------------------------------------------------------

-- 8. Dashboard de ventas: ingresos por día en el último mes
select
    cast(p.fechaPedido as date)       as fecha,
    count(p.idPedido)                 as cantidadPedidos,
    sum(p.montoTotalFacturado)        as ingresosBrutos,
    sum(case when ep.nombre = 'Completado' then pg.monto else 0 end) as ingresosConfirmados
from ventas.Pedido p
    left join pagos.Pago       pg  on pg.idPedido      = p.idPedido
    left join ref.EstadoPago   ep  on ep.idEstadoPago  = pg.idEstadoPago
where p.fechaPedido >= dateadd(month, -1, getdate())
group by cast(p.fechaPedido as date)
order by fecha desc
go

-- 9. Productos más vendidos con calificación promedio y total recaudado
select
    pr.nombre                                         as producto,
    pr.marca,
    cat.nombre                                        as categoria,
    sum(dp.cantidad)                                  as unidadesVendidas,
    sum(dp.cantidad * dp.precioSnapshot)              as totalRecaudado,
    avg(cast(r.calificacion as decimal(3,1)))         as calificacionPromedio,
    count(distinct r.idResena)                        as totalResenas
from catalogo.Producto pr
    inner join catalogo.Categoria        cat on cat.idCategoria = pr.idCategoria
    inner join catalogo.ProductoVariante pv  on pv.idProducto  = pr.idProducto
    inner join ventas.DetallePedido      dp  on dp.idVariante  = pv.idVariante
    inner join ventas.Pedido             p   on p.idPedido     = dp.idPedido
    inner join ref.EstadoPedido          ep  on ep.idEstado    = p.idEstadoPedido
    left  join social.Resena             r   on r.idVariante   = pv.idVariante
where ep.nombre not in ('Cancelado', 'Reembolsado')
  and pr.is_active = 1
group by pr.idProducto, pr.nombre, pr.marca, cat.nombre
order by unidadesVendidas desc
go

-- 10. Trazabilidad completa de un pedido
select
    p.idPedido,
    cl.primerNombre + ' ' + cl.primerApellido  as cliente,
    p.fechaPedido,
    p.montoTotalFacturado,
    mp.nombre                                  as metodoPago,
    epg.nombre                                 as estadoPago,
    pg.referenciaGateway,
    tr.nombreEmpresa                           as transportista,
    e.numeroTracking,
    ee.nombre                                  as estadoEnvio,
    e.fechaEnvio,
    e.fechaEntregaEstimada,
    phe.fechaCambio                            as fechaCambioEstado,
    ep.nombre                                  as estadoPedidoHistorico,
    phe.observacion
from ventas.Pedido p
    inner join clientes.Cliente                cl  on cl.idCliente       = p.idCliente
    inner join pagos.Pago                      pg  on pg.idPedido        = p.idPedido
    inner join pagos.MetodoPago                mp  on mp.idMetodo        = pg.idMetodoPago
    inner join ref.EstadoPago                  epg on epg.idEstadoPago   = pg.idEstadoPago
    inner join envios.Envio                    e   on e.idPedido         = p.idPedido
    inner join envios.Transportista            tr  on tr.idTransportista = e.idTransportista
    inner join ref.EstadoEnvio                 ee  on ee.idEstadoEnvio   = e.idEstadoEnvio
    inner join ventas.PedidoHistorialEstado    phe on phe.idPedido       = p.idPedido
    inner join ref.EstadoPedido                ep  on ep.idEstado        = phe.idEstadoNuevo
where p.idPedido = 1
order by phe.fechaCambio asc
go

-- 11. Clientes con carrito activo y valor estimado del carrito
select
    cl.primerNombre + ' ' + cl.primerApellido  as cliente,
    cl.email,
    ca.fechaExpiracion,
    count(ci.idCarritoItem)                    as itemsEnCarrito,
    sum(ci.cantidad * pv.precioActual)         as valorEstimadoCarrito
from social.Carrito ca
    inner join clientes.Cliente          cl on cl.idCliente  = ca.idCliente
    inner join social.CarritoItem        ci on ci.idCarrito  = ca.idCarrito
    inner join catalogo.ProductoVariante pv on pv.idVariante = ci.idVariante
where (ca.fechaExpiracion is null or ca.fechaExpiracion > getdate())
  and cl.is_active = 1
  and pv.is_active = 1
group by cl.idCliente, cl.primerNombre, cl.primerApellido, cl.email, ca.fechaExpiracion
order by valorEstimadoCarrito desc
go