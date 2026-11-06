# Rediseño "estilo Netflix" — Sub-proyecto 1: Home

**Fecha:** 2026-11-05
**Alcance de este documento:** solo la pantalla Home (`homeScreen()` en
`components/PlusSceneViews.brs` + estado relacionado en
`components/PlusScene.brs`). El resto del rediseño (Browse, Detalle, TV en
vivo, Player, Setup/Apariencia) son sub-proyectos futuros, listados al final
de este documento para mantener el orden ya acordado.

## 1. Contexto y restricción del motor

La app no usa componentes estándar de Roku (`RowList`, `MarkupGrid`). Dibuja
todo con `Group`/`Rectangle`/`Label`/`Poster` creados a mano cada vez que se
redibuja la pantalla (`eraseScreen()` + reconstrucción completa de nodos).
Este diseño se apoya en ese mismo mecanismo — no introduce SceneGraph
estándar ni un sistema de layout nuevo — para minimizar el riesgo de romper
la navegación por mando que ya funciona en el resto de la app.

## 2. Objetivo

Reemplazar el bloque fijo de "3 películas + 3 series" del Home por filas
horizontales con scroll real, usando los datos que la app **ya pide** a
Cinemeta (`m.features`, `m.homeSeries` — páginas completas, hoy truncadas a
3 ítems en pantalla). Sin pedir datos nuevos al servidor. Sin agregar
funciones nuevas (favoritos, continuar viendo): es un rediseño visual y de
navegación, no una función nueva.

## 3. No-objetivos (explícitamente fuera de este sub-proyecto)

- Pantalla Browse: sigue siendo grilla paginada; solo su repintado visual
  (colores/tipografía/tarjetas) se hace en un sub-proyecto posterior.
- Pantallas de Detalle, TV en vivo, Player, Setup/Apariencia, Créditos: sin
  cambios en este documento.
- "Continuar viendo" / favoritos / cualquier persistencia nueva.
- Filas por género/categoría (Cinemeta no da esa segmentación hoy sin
  llamadas adicionales): el Home tendrá exactamente 2 filas de catálogo
  (Películas, Series) más el hero.
- Replicar la marca de Netflix (logo, rojo de marca exacto): ya acordado
  como "inspirado en", no réplica.

## 4. Lenguaje visual

- Fondo: casi negro (`0x0B0B0DFF`) en lugar del tratamiento "glass"
  azulado actual.
- Texto: blanco/gris claro sobre fondo oscuro (igual que hoy en su mayoría,
  se ajustan tonos de gris secundario).
- Acento: rojo oscuro no-marca (a definir un valor concreto, ej.
  `0xB81D24FF`) solo en: botón primario del hero, indicador de foco activo.
- Tarjetas: se mantiene la proporción panorámica actual. El foco pasa de
  solo mostrar el borde `focus-landscape` a también un **zoom leve**
  (escala 1.08 sobre un `Group` que envuelve la tarjeta). Implementación:
  las tarjetas de fila se dibujan dentro de un `Group` propio (no
  directamente en `m.canvas` como hoy); `focusTarget()` recibe un
  parámetro opcional nuevo `scaleNode` (por defecto `invalid`, así que las
  llamadas existentes en otras pantallas no cambian); `paintFocus()` anima
  `scaleNode.scale` entre `[1,1]` y `[1.08,1.08]` cuando corresponde.
- **Theming (fuera de este sub-proyecto):** el selector `glass`/`classic`
  (`rpLoadTheme`/`rpSaveTheme`/`themeAsset()`, pantalla de Apariencia) **no
  se toca aquí** — se retira en el sub-proyecto 4 (§10), para no dejar a
  medio camino un control que el usuario todavía puede pulsar. Los
  elementos nuevos del Home (`hero-mask`, `card-landscape-mask`,
  `focus-landscape`) ya están fuera de la lista de assets que
  `themeAsset()` intercambia por tema (confirmado en
  `components/PlusSceneViews.brs:44`), así que no cambian con el tema
  actual. Las piezas compartidas que sí cambian por tema
  (`app-background`, `rail-glass`) pueden verse inconsistentes si el
  usuario tiene "Classic" seleccionado — limitación conocida y aceptada
  hasta el sub-proyecto 4.
- Assets: se reutilizan los PNG actuales donde sirven (máscaras de tarjeta,
  logos de canal, pósters remotos). Se generan nuevos PNG simples
  (gradientes/formas planas) donde el estilo "glass" no encaje — concretamente:
  nuevo `hero-shade` con degradado más oscuro/alto-contraste, nuevo
  indicador de foco de fila.

## 5. Modelo de datos — filas

```
m.homeRows = [
  {heading: "Películas populares", items: m.features,   cursor: 0, offset: 0},
  {heading: "Series populares",    items: m.homeSeries, cursor: 0, offset: 0}
]
m.rowFocus = 0   ' índice de fila activa (reemplaza el actual m.zone para Home)
```

- `items` apunta a los mismos arrays que ya mantiene `refreshHome()`
  (`m.features`, `m.homeSeries`) — no se duplican datos.
- `cursor`/`offset` viven en el objeto de la fila, no en variables sueltas de
  `m`, para que cada fila recuerde su posición de forma independiente.
- Cuando `refreshHome()` reemplaza `m.features`/`m.homeSeries` (recarga), se
  resetea `cursor`/`offset` de esa fila a 0 (contenido nuevo = posición
  nueva); si falla la recarga, la fila existente y su posición se
  conservan (ver §7).

## 6. Navegación

- **Arriba/Abajo:** `m.rowFocus += 1 / -= 1`, con límites en el hero (fila
  -1 conceptual) y la última fila. Redibuja con el nuevo foco.
- **Izquierda/Derecha:** operan sobre `m.homeRows[m.rowFocus]`:
  - `cursor += 1 / -= 1`, saturando en `0` y `items.count()-1` (sin wrap:
    en el borde no pasa nada, igual que Netflix).
  - Ventana visible fija de **5 tarjetas**. Si `cursor` sale de
    `[offset, offset+4]`, `offset` se ajusta para volver a encuadrarlo
    (desplazamiento de a una tarjeta, no salto completo de ventana — scroll
    suave).
- **OK:** abre detalle del ítem en `items[cursor]` de la fila activa (misma
  función `openDetails()` ya existente).
- El hero (`m.rowFocus = -1` conceptual, o se reutiliza la zona "hero" ya
  existente con sus 2 botones) no cambia de comportamiento: sigue siendo
  "Reproducir"/"Ver detalles" como hoy.

## 7. Dibujo y estados vacíos/errores

- `drawRow(row, y, focused)` reemplaza el bloque `for i = 0 to 2` actual:
  itera `row.items[row.offset .. min(row.offset+4, items.count()-1)]`,
  llamando a `thumbnail()`/`focusTarget()` igual que hoy, con `x` calculado
  por posición relativa dentro de la ventana (no por índice absoluto).
- Si `row.items.count() = 0` (aún cargando o falló): la fila muestra su
  encabezado con un texto secundario ("Cargando…" / el mensaje de error que
  ya pone `homeFetched()` en `m.note`), sin tarjetas — mismo patrón de
  mensajes que ya usa el resto de la app, no se inventa un nuevo sistema de
  errores.
- Si `homeFetched()` falla para una fila, esa fila conserva su contenido
  previo (si lo había) en vez de vaciarse — pequeña mejora sobre el
  comportamiento actual, que ya deja `m.note` con el aviso pero no protege
  el array previo explícitamente; se confirma que `homeFetched()` solo
  reasigna `m.features`/`m.homeSeries` cuando `answer.ok`, así que esto ya
  se cumple sin cambios adicionales.

## 8. Impacto en código existente

| Archivo | Cambio |
|---|---|
| `components/PlusSceneViews.brs` | `homeScreen()` reescrita para iterar `m.homeRows` vía `drawRow()`. Nuevo helper `drawRow()`. `focusTarget()`/`paintFocus()` ganan soporte opcional de escala-en-foco (párrafo nuevo abajo), sin romper sus llamadas actuales en otras pantallas. |
| `components/PlusScene.brs` | Inicializar `m.homeRows`/`m.rowFocus` en `init()`. Reemplazar `m.cover`/`m.seriesCover` por el modelo de filas en el bloque de manejo de teclas de `m.view = "home"`, en `commitSetup()` y en `commitHdSource()`. `goHome()` no cambia (ya no reseteaba cover/seriesCover, conserva el mismo comportamiento con filas). |
| `source/HomeRows.brs` (nuevo) | Funciones puras: `rpRowAdvance(row, items, delta, windowSize)` y `rpHomeRowsBuild(features, series)`. |
| `components/PlusScene.xml` | Registrar el nuevo script `pkg:/source/HomeRows.brs`. |
| Selector de tema (`rpLoadTheme`/Apariencia) | **Sin cambios** en este sub-proyecto (ver nota de Theming arriba). |

## 9. Pruebas

Dado el estándar "ponytail" del proyecto (lógica nueva no trivial = un
chequeo pequeño): se añaden pruebas puras, sin E/S, para las funciones
nuevas que son lógica de navegación (el patrón que ya usa el proyecto en
`PlaybackWatchdog.brs`/`SeekClock.brs`, que sí son testeables por ser
funciones puras):

- Función pura `rpRowAdvance(row, items, delta, windowSize)` → nuevo
  `cursor`/`offset`, extraída de la lógica de navegación de §6 para poder
  probarla sin montar la escena completa. Casos: cursor en el centro, en el
  borde izquierdo, en el borde derecho, fila vacía.
- No se prueba el dibujo en sí (como el resto del proyecto, que no testea
  `art()`/`words()`): solo la aritmética de navegación.

## 10. Orden del resto del rediseño (fuera de este documento)

1. **Home** (este documento).
2. Detalle de título.
3. TV en vivo.
4. Player, Setup/Apariencia (incluye retirar el selector de tema) y
   Créditos — ajustes de color/tipografía, sin cambios estructurales
   grandes esperados.

Cada uno recibe su propio diseño corto antes de implementarse, siguiendo el
mismo proceso.
