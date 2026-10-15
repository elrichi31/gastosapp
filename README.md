# Zenlor

App de gastos personales para iOS. Registro de gastos, gastos recurrentes y
suscripciones, presupuestos mensuales por categoría y análisis de gasto.

Escrita en SwiftUI, con un backend REST propio.

## Requisitos

- Xcode 16 o superior
- iOS 18.5 como destino mínimo

## Puesta en marcha

El proyecto no compila recién clonado: falta el archivo de configuración local,
que está fuera del repositorio a propósito.

```bash
cp LocalAPIConfig.example.swift gastosapp/Configuration/LocalAPIConfig.swift
```

El backend de producción es `https://spend.zenlorlabs.com`. Para otro entorno,
reemplaza `baseURL` en ese archivo. Las URLs antiguas guardadas de producción
se migran al backend configurado al iniciar la app, conservando la sesión y los
gastos pendientes. Después,
`gastosapp.xcodeproj` compila y corre normalmente.

## Estructura

```
gastosapp/
├── App/            Punto de entrada y contenedor de pestañas
├── Auth/           Login y sesión
├── Configuration/  Configuración local (ignorada por git)
├── Core/
│   ├── Design/     Sistema de diseño: tokens, componentes compartidos
│   ├── Models/     Modelos de dominio
│   ├── Stores/     Estado observable y cliente del API
│   └── ...
└── Features/
    ├── Home/           Inicio: estado del mes y accesos rápidos
    ├── Gastos/         Movimientos, recurrentes y calendario
    ├── Presupuestos/   Presupuesto mensual y por categoría
    ├── Estadisticas/   Análisis anual y por mes
    └── Profile/        Preferencias y objetivo de ahorro
```

### Sistema de diseño

Los colores, radios y tipografías salen todos de `Core/Design/AppTheme.swift`.
El verde de marca (`#37965C`) es el mismo del ícono de la app y no cambia entre
modo claro y oscuro. Si vas a tocar estilos, empieza por ahí antes que por las
vistas.

`Core/Design/FloatingTabBarInset.swift` resuelve un detalle no obvio: SwiftUI no
propaga el `safeAreaInset` del contenedor a las vistas que un `NavigationStack`
empuja, sólo a su raíz. Las pantallas empujadas usan `.floatingTabBarInset()`
para que su contenido no quede debajo de la barra de pestañas.

## Funciones compartidas con la web

La app incluye etiquetas, compras en el exterior, recurrentes anuales y omisión de
cobros, importación de correo, proyecciones y administración de conexiones.
Consulta [la guía de paridad móvil](docs/MOBILE_WEB_PARITY.md) para los accesos,
requisitos de backend y verificación.
