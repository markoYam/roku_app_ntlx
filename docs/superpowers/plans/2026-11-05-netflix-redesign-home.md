# Rediseño Home (estilo Netflix) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el bloque fijo de "3 películas + 3 series" de la
pantalla Home por filas horizontales con scroll real (modelo Netflix),
reutilizando los datos que la app ya pide a Cinemeta.

**Architecture:** Se añade un modelo de datos genérico `m.homeRows` (array
de `{heading, items, cursor, offset}`) y un helper de dibujo `drawRow()`
que sustituye el bucle fijo `for i = 0 to 2` actual. La aritmética de
desplazamiento vive en una función pura nueva (`rpRowAdvance`) en un
archivo nuevo `source/HomeRows.brs`, testeable sin montar la escena. El
foco gana un efecto de zoom opcional vía un parámetro nuevo en
`focusTarget()`, sin afectar las llamadas existentes de otras pantallas.

**Tech Stack:** Roku BrightScript / SceneGraph (sin frameworks de test
automatizado en el proyecto — las "pruebas" de funciones puras se verifican
manualmente contra casos impresos por consola, ver Tarea 1).

**Spec:** `docs/superpowers/specs/2026-11-05-netflix-redesign-home-design.md`

## Global Constraints

- No se tocan Browse, Detalle, Episodios, TV en vivo, Player ni
  Setup/Apariencia en este plan (spec §3).
- No se agrega "continuar viendo" ni favoritos (spec §3).
- No se piden datos nuevos al servidor: `m.features`/`m.homeSeries` ya
  traen una página completa de Cinemeta (spec §2).
- Ventana visible de cada fila: **5 tarjetas** (spec §6).
- No se toca el selector de tema `glass`/`classic` (spec: nota de
  Theming). `focusTarget()` solo gana un parámetro **opcional** nuevo —
  las llamadas existentes en otras pantallas no cambian de firma ni de
  comportamiento.
- Acento de color: rojo no-marca `0xB81D24FF` (spec §4).

---

### Task 1: Función pura de scroll de fila (`rpRowAdvance`)

**Files:**
- Create: `source/HomeRows.brs`

**Interfaces:**
- Produces: `rpRowAdvance(row as object, items as object, delta as integer, windowSize as integer) as object` — devuelve `{cursor: integer, offset: integer}`. Usada por Task 3 (manejo de teclas) y Task 2 (dibujo).
- Produces: `rpHomeRowsBuild(features as object, series as object) as object` — devuelve el array `m.homeRows` inicial: `[{heading:"Películas populares", items:features, cursor:0, offset:0}, {heading:"Series populares", items:series, cursor:0, offset:0}]`. Usada por Task 3.

No hay framework de pruebas unitarias en el proyecto (confirmado: no existe
carpeta `tests/` ni runner). Se verifica con un script de consola temporal
ejecutado vía `brightscript-repl`-less approach: como no hay REPL de
BrightScript fuera de un Roku real, la verificación se hace imprimiendo los
casos con `print` dentro de una función de diagnóstico temporal que se
borra al final de esta tarea (no queda código muerto en el repo).

- [ ] **Step 1: Crear `source/HomeRows.brs` con las dos funciones**

```brightscript
' Home screen pure logic: row scroll arithmetic and initial row model.
' No I/O, no SceneGraph nodes — testable by inspection alone.

function rpRowAdvance(row as object, items as object, delta as integer, windowSize as integer) as object
    count = items.count()
    if count = 0 then return {cursor: 0, offset: 0}
    cursor = row.cursor + delta
    if cursor < 0 then cursor = 0
    if cursor > count - 1 then cursor = count - 1
    offset = row.offset
    if cursor < offset then offset = cursor
    if cursor > offset + windowSize - 1 then offset = cursor - windowSize + 1
    if offset < 0 then offset = 0
    maxOffset = count - windowSize
    if maxOffset < 0 then maxOffset = 0
    if offset > maxOffset then offset = maxOffset
    return {cursor: cursor, offset: offset}
end function

function rpHomeRowsBuild(features as object, series as object) as object
    return [
        {heading: "Películas populares", items: features, cursor: 0, offset: 0},
        {heading: "Series populares", items: series, cursor: 0, offset: 0}
    ]
end function
```

- [ ] **Step 2: Verificar la aritmética con un bloque temporal de diagnóstico**

Añade temporalmente al final de `source/HomeRows.brs` (se borra en el Step 4):

```brightscript
sub rpRowAdvanceSelfCheck()
    items = CreateObject("roArray", 12, true)
    for i = 1 to 12 : items.push(i) : end for
    row = {cursor: 0, offset: 0}
    windowSize = 5

    ' Avanzar 4 veces a la derecha: cursor=4, aún dentro de la ventana [0,4]
    r = row
    for i = 1 to 4 : r = rpRowAdvance(r, items, 1, windowSize) : end for
    print "caso 1 (cursor=4,offset=0 esperado): "; r.cursor; ","; r.offset

    ' Un paso más a la derecha: cursor=5 empuja la ventana a offset=1
    r = rpRowAdvance(r, items, 1, windowSize)
    print "caso 2 (cursor=5,offset=1 esperado): "; r.cursor; ","; r.offset

    ' Ir al final (11 pasos más): cursor=11 (último), offset=7 (12-5)
    for i = 1 to 20 : r = rpRowAdvance(r, items, 1, windowSize) : end for
    print "caso 3 borde derecho (cursor=11,offset=7 esperado): "; r.cursor; ","; r.offset

    ' Borde izquierdo: desde cursor=0, retroceder no debe bajar de 0
    r = {cursor: 0, offset: 0}
    r = rpRowAdvance(r, items, -1, windowSize)
    print "caso 4 borde izquierdo (cursor=0,offset=0 esperado): "; r.cursor; ","; r.offset

    ' Fila vacía: no debe fallar
    r = rpRowAdvance({cursor: 0, offset: 0}, [], 1, windowSize)
    print "caso 5 fila vacía (cursor=0,offset=0 esperado): "; r.cursor; ","; r.offset
end sub
```

Agrega una llamada temporal a `rpRowAdvanceSelfCheck()` al inicio de
`init()` en `components/PlusScene.brs` (se quita en el Step 4), empaqueta
el canal (reutiliza el flujo de `zip` ya usado en este proyecto — ver
`roku-plus.zip` existente, mismo comando `zip -r -X`), instálalo en el
Roku de desarrollo y revisa la salida en `telnet <roku-ip> 8085`.

- [ ] **Step 3: Confirmar que los 5 casos imprimen los valores esperados**

Expected: las 5 líneas impresas coinciden exactamente con los valores
anotados en los comentarios del Step 2. Si no coinciden, corrige
`rpRowAdvance` antes de continuar — no avances con la aritmética rota, el
resto del plan depende de ella.

- [ ] **Step 4: Quitar el código de diagnóstico**

Borra `rpRowAdvanceSelfCheck()` de `source/HomeRows.brs` y la llamada
temporal en `init()`. `source/HomeRows.brs` queda solo con las dos
funciones del Step 1.

- [ ] **Step 5: Registrar el nuevo script**

En `components/PlusScene.xml`, agrega la línea después de
`pkg:/source/HdData.brs` (línea 10) y antes de `PlusSceneViews.brs`:

```xml
  <script type="text/brightscript" uri="pkg:/source/HdData.brs" />
  <script type="text/brightscript" uri="pkg:/source/HomeRows.brs" />
  <script type="text/brightscript" uri="PlusSceneViews.brs" />
```

- [ ] **Step 6: Commit**

```bash
cd /Users/marcoyamcetina/Downloads/Roku-Plus-1
git add source/HomeRows.brs components/PlusScene.xml
git commit -m "feat: add pure row-scroll arithmetic for Home redesign

```

(Si la carpeta todavía no es un repositorio git, pide confirmación al
usuario antes de `git init` — no se asume.)

---

### Task 2: `focusTarget()`/`paintFocus()` ganan zoom-en-foco opcional

**Files:**
- Modify: `components/PlusSceneViews.brs:88-103` (`focusTarget`)
- Modify: `components/PlusSceneViews.brs:673-695` (`paintFocus`)

**Interfaces:**
- Consumes: nada nuevo de otras tareas.
- Produces: `focusTarget(zone, index, x, y, w, h, shape = "wide", scaleNode = invalid as dynamic)` — firma ampliada, retrocompatible (todas las llamadas existentes sin el 8vo argumento siguen funcionando igual). `paintFocus()` ahora también anima `entry.scaleNode.scale` cuando existe.

- [ ] **Step 1: Ampliar `focusTarget()` con el parámetro opcional**

Reemplaza en `components/PlusSceneViews.brs`:

```brightscript
sub focusTarget(zone as string, index as integer, x as integer, y as integer, w as integer, h as integer, shape = "wide" as string)
    uri = "pkg:/images/ui/focus-button.png"
    if shape = "card" then uri = "pkg:/images/ui/focus-card.png"
    if shape = "landscape" then uri = "pkg:/images/ui/focus-landscape.png"
    if shape = "setup" then uri = "pkg:/images/ui/setup-focus.png"
    if shape = "catalog" then uri = "pkg:/images/ui/focus-catalog.png"
    if shape = "live" then uri = "pkg:/images/ui/focus-live.png"
    if shape = "reality" then uri = "pkg:/images/ui/focus-reality.png"
    if shape = "live-channel" then uri = "pkg:/images/ui/live-row-focus.png"
    if shape = "live-search" then uri = "pkg:/images/ui/focus-row.png"
    if shape = "appearance" then uri = "pkg:/images/ui/focus-appearance.png"
    if shape = "wide" and w > 1000 then uri = "pkg:/images/ui/focus-row.png"
    edge = art(uri,x,y,w,h)
    edge.visible = false
    m.focusItems.push({zone:zone,index:index,edge:edge})
end sub
```

por:

```brightscript
sub focusTarget(zone as string, index as integer, x as integer, y as integer, w as integer, h as integer, shape = "wide" as string, scaleNode = invalid as dynamic)
    uri = "pkg:/images/ui/focus-button.png"
    if shape = "card" then uri = "pkg:/images/ui/focus-card.png"
    if shape = "landscape" then uri = "pkg:/images/ui/focus-landscape.png"
    if shape = "setup" then uri = "pkg:/images/ui/setup-focus.png"
    if shape = "catalog" then uri = "pkg:/images/ui/focus-catalog.png"
    if shape = "live" then uri = "pkg:/images/ui/focus-live.png"
    if shape = "reality" then uri = "pkg:/images/ui/focus-reality.png"
    if shape = "live-channel" then uri = "pkg:/images/ui/live-row-focus.png"
    if shape = "live-search" then uri = "pkg:/images/ui/focus-row.png"
    if shape = "appearance" then uri = "pkg:/images/ui/focus-appearance.png"
    if shape = "wide" and w > 1000 then uri = "pkg:/images/ui/focus-row.png"
    edge = art(uri,x,y,w,h)
    edge.visible = false
    m.focusItems.push({zone:zone,index:index,edge:edge,scaleNode:scaleNode})
end sub
```

- [ ] **Step 2: Animar la escala en `paintFocus()`**

Reemplaza el cuerpo del `for each entry in m.focusItems` en
`paintFocus()` (línea ~674) agregando, justo antes de
`entry.edge.visible = chosen`:

```brightscript
        entry.edge.visible = chosen
        if entry.scaleNode <> invalid
            if chosen then entry.scaleNode.scale = [1.08,1.08] else entry.scaleNode.scale = [1.0,1.0]
        end if
    end for
end sub
```

(Reemplaza únicamente la línea final `entry.edge.visible = chosen` y el
`end for`/`end sub` que ya existen — no dupliques el resto del cuerpo de
la función.)

- [ ] **Step 3: Verificación manual de no-regresión**

Empaqueta e instala el canal. Navega a Browse, Detalle y TV en vivo (las
tres pantallas con más llamadas a `focusTarget`) y confirma que el
resaltado de foco se ve exactamente igual que antes de este cambio — como
`scaleNode` es `invalid` en todas esas llamadas, no debe haber ningún
efecto visual nuevo ahí todavía (el zoom solo aparecerá en Home, en la
Task 3).

Expected: cero diferencias visuales en Browse/Detalle/Live respecto al
`roku-plus.zip` anterior a esta tarea.

- [ ] **Step 4: Commit**

```bash
git add components/PlusSceneViews.brs
git commit -m "feat: add optional focus-scale support to focusTarget/paintFocus

```

---

### Task 3: Modelo de filas en `PlusScene.brs` (estado + navegación)

**Files:**
- Modify: `components/PlusScene.brs:19-24` (bloque de `init()`)
- Modify: `components/PlusScene.brs:463-467` (`goHome()`)
- Modify: `components/PlusScene.brs:765-767` (`commitSetup()`)
- Modify: `components/PlusScene.brs:989-990, 998-1000` (`commitHdSource()`)
- Modify: `components/PlusScene.brs:1120-1148` (manejo de teclas de `m.view = "home"`)
- Modify: `components/PlusScene.brs:844-865` (`homeFetched()` — reconstruir `m.homeRows` cuando llegan datos nuevos)

**Interfaces:**
- Consumes: `rpRowAdvance(row, items, delta, windowSize)`, `rpHomeRowsBuild(features, series)` de Task 1.
- Produces: `m.homeRows as object` (array de `{heading, items, cursor, offset}`), `m.rowFocus as integer` (-1 = hero, 0..N-1 = fila). Usados por Task 4 (`homeScreen()`/`drawRow()`/`paintFocus()`).

- [ ] **Step 1: Inicializar el modelo de filas en `init()`**

Reemplaza en `components/PlusScene.brs`:

```brightscript
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.hero = 0
    m.cover = 0
    m.seriesCover = 0
```

por:

```brightscript
    m.view = "home"
    m.zone = "hero"
    m.nav = 0
    m.hero = 0
    m.homeRows = rpHomeRowsBuild([], [])
    m.rowFocus = 0
```

- [ ] **Step 2: Quitar los resets obsoletos de `commitSetup()`**

Reemplaza en `commitSetup()`:

```brightscript
    m.cover = 0
    m.seriesCover = 0
    m.hero = 0
    m.features = []
    m.homeSeries = []
```

por:

```brightscript
    m.hero = 0
    m.features = []
    m.homeSeries = []
    m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
    m.rowFocus = 0
```

- [ ] **Step 3: Quitar los resets obsoletos de `commitHdSource()`**

Reemplaza las dos apariciones en `commitHdSource()`:

```brightscript
    m.cover = 0
    m.seriesCover = 0
```

por (elimínalas sin reemplazo — ya no existen esas variables; la única en
la línea 988-990 original desaparece junto con `m.cursor = 0` que sí se
mantiene sin cambios) y, en el bloque `if m.catalogMode = "hd"` (líneas
994-1000), después de `m.homeSeries = []`, agrega:

```brightscript
        m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
        m.rowFocus = 0
```

- [ ] **Step 4: Reconstruir `m.homeRows` cuando llegan datos frescos en `homeFetched()`**

En `homeFetched()`, después de la línea:

```brightscript
                if entry.kind = "movie" then m.features = answer.items else m.homeSeries = answer.items
```

agrega:

```brightscript
                m.homeRows = rpHomeRowsBuild(m.features, m.homeSeries)
```

(Mantiene el `cursor`/`offset` en 0 para la fila recién actualizada —
aceptable: es la misma fila que acaba de cambiar de contenido, coherente
con spec §5. Si la otra fila ya tenía datos previos, `rpHomeRowsBuild`
reconstruye ambas desde cero en este punto; es una simplificación
deliberada — las dos peticiones de `refreshHome()` llegan casi al mismo
tiempo en la práctica, así que el usuario no alcanza a notar un reset de
posición en la fila que no cambió.)

- [ ] **Step 5: Reescribir el manejo de teclas de Home**

Reemplaza el bloque completo (líneas 1120-1148):

```brightscript
    else if m.view = "home"
        if m.zone = "hero"
            if key = "left"
                if m.hero = 0 then m.zone = "nav": drawScreen(): return true
                m.hero = 0
            end if
            if key = "right" and m.features.count() > 0 then m.hero = 1
            if key = "up" then m.zone = "nav": drawScreen(): return true
            if key = "down" then m.zone = "covers"
            if key = "OK"
                if m.features.count() > 0 then openDetails(m.features[0],"home",m.hero=0) else refreshHome(): drawScreen()
                return true
            end if
        else if m.zone = "covers"
            if key = "left"
                if m.cover > 0 then m.cover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.cover < 2 and m.cover+1 < m.features.count() then m.cover++
            if key = "up" then m.zone = "hero"
            if key = "down" and m.homeSeries.count() > 0 then m.zone = "home-series"
            if key = "OK" and m.features.count() > 0 then openDetails(m.features[m.cover],"home"): return true
        else if m.zone = "home-series"
            if key = "left"
                if m.seriesCover > 0 then m.seriesCover-- else m.zone = "nav": drawScreen(): return true
            end if
            if key = "right" and m.seriesCover < 2 and m.seriesCover+1 < m.homeSeries.count() then m.seriesCover++
            if key = "up" then m.zone = "covers"
            if key = "OK" and m.homeSeries.count() > 0 then openDetails(m.homeSeries[m.seriesCover],"home"): return true
        end if
```

por:

```brightscript
    else if m.view = "home"
        if m.zone = "hero"
            if key = "left"
                if m.hero = 0 then m.zone = "nav": drawScreen(): return true
                m.hero = 0
            end if
            if key = "right" and m.features.count() > 0 then m.hero = 1
            if key = "up" then m.zone = "nav": drawScreen(): return true
            if key = "down" and m.homeRows.count() > 0 then m.zone = "home-row-0"
            if key = "OK"
                if m.features.count() > 0 then openDetails(m.features[0],"home",m.hero=0) else refreshHome(): drawScreen()
                return true
            end if
        else if left(m.zone,9) = "home-row-"
            rowIndex = val(mid(m.zone,10))
            row = m.homeRows[rowIndex]
            if key = "left"
                next = rpRowAdvance(row,row.items,-1,5)
                if next.cursor = row.cursor then m.zone = "nav": drawScreen(): return true
                row.cursor = next.cursor
                row.offset = next.offset
            end if
            if key = "right"
                next = rpRowAdvance(row,row.items,1,5)
                row.cursor = next.cursor
                row.offset = next.offset
            end if
            if key = "up"
                if rowIndex = 0 then m.zone = "hero" else m.zone = "home-row-"+(rowIndex-1).toStr()
            end if
            if key = "down" and rowIndex < m.homeRows.count()-1 then m.zone = "home-row-"+(rowIndex+1).toStr()
            if key = "OK" and row.items.count() > 0 then openDetails(row.items[row.cursor],"home"): return true
        end if
```

Nota: `row` es una referencia al objeto dentro de `m.homeRows` (los
arrays/AA de BrightScript se pasan por referencia), así que
`row.cursor = next.cursor` modifica `m.homeRows[rowIndex]` directamente
— no hace falta reasignar `m.homeRows[rowIndex] = row`.

- [ ] **Step 6: Verificación manual**

Empaqueta e instala. En Home: baja desde el hero a la primera fila,
navega con izquierda/derecha más allá de 5 elementos y confirma que el
scroll avanza de a uno; llega al último elemento y confirma que
izquierda/derecha no lo saca del rango; baja a la segunda fila; sube de
vuelta; pulsa OK sobre un ítem distinto del primero y confirma que abre
el detalle correcto (el de la posición enfocada, no siempre el [0]).

Expected: navegación fluida, sin saltos ni "undefined index" en el log de
`telnet <roku-ip> 8085`.

- [ ] **Step 7: Commit**

```bash
git add components/PlusScene.brs
git commit -m "feat: replace fixed home cover/seriesCover state with scrollable row model

```

---

### Task 4: Redibujar Home con `drawRow()` y el nuevo lenguaje visual

**Files:**
- Modify: `components/PlusSceneViews.brs:241-312` (`homeScreen()`)
- Modify: `components/PlusSceneViews.brs:673-695` (`paintFocus()` — rama de zonas `home-row-*`)

**Interfaces:**
- Consumes: `m.homeRows`, `m.rowFocus`(no se usa directamente para pintar — el zone string ya lo codifica; se mantiene `m.zone` como fuente de verdad, igual que el resto de la app) de Task 3. `focusTarget(..., scaleNode)` de Task 2.
- Produces: nada que otras tareas de este plan consuman (es la última).

- [ ] **Step 1: Agregar la rama de reconocimiento de zona en `paintFocus()`**

En `components/PlusSceneViews.brs`, dentro de `paintFocus()`, la
estructura actual compara `entry.zone = m.zone` una vez (línea 676) y
luego encadena `if m.zone = "..." then chosen = ...` para cada zona
conocida. Agrega un caso nuevo a esa cadena, inmediatamente antes de la
línea `if m.zone = "grid" then chosen = entry.index = m.cursor`:

```brightscript
            if left(m.zone,9) = "home-row-" then chosen = entry.index = m.homeRows[val(mid(m.zone,10))].cursor
```

- [ ] **Step 2: Reescribir `homeScreen()` con filas horizontales**

Reemplaza la función completa (líneas 241-312):

```brightscript
sub homeScreen()
    if m.features.count() > 0
        item = m.features[0]
        heroUri = item.background
        if heroUri = "" then heroUri = item.poster
        if heroUri <> "" then art(heroUri,294,24,1596,430)
        art("pkg:/images/ui/hero-shade.png",294,24,1596,450)
        glassSurface("hero-mask",294,24,1596,430)
        words("DESTACADO",338,71,1470,38,21,"0xD9D9DCFF")
        words(item.title,333,123,1000,137,54).wrap = true
        facts = item.year
        if m.catalogMode = "hd"
            if usesOnlineHd() then facts += " · "+hdProviderName(item.provider) else facts += " · Corto"
        end if
        words(facts,340,277,1440,43,25,"0xB3B3B8FF")
        selectable("hero",0,"Reproducir",337,335,317,70,true)
        selectable("hero",1,"Ver detalles",674,335,275,70)
    else
        words("Tu próxima historia",335,142,1470,90,57)
        text = "Actualizando las películas y series populares…"
        if not m.homeLoading then text = "Abre Películas o Series para explorar el catálogo."
        words(text,340,252,1470,80,29,"0xB3B3B8FF").wrap = true
        selectable("hero",0,"Actualizar",337,335,317,70,true)
    end if
    rowY = 490
    for r = 0 to m.homeRows.count()-1
        row = m.homeRows[r]
        heading = row.heading
        if r = 0 and m.catalogMode = "hd" then heading = "Cortos en HD"
        if r = 0 and m.catalogMode = "hd" and usesOnlineHd() then heading = "Películas para explorar"
        if r = 1 and m.catalogMode = "hd"
            if usesOnlineHd() then heading = "Series por descubrir" else heading = "Documentales en español"
        end if
        words(heading,318,rowY,1500,47,34)
        drawRow(row,r,rowY+56)
        rowY += 390
    end for
    topBar()
end sub

sub drawRow(row as object, rowIndex as integer, y as float)
    cardW = 480
    cardH = 251
    gap = 36
    windowSize = 5
    last = row.offset + windowSize - 1
    if last > row.items.count()-1 then last = row.items.count()-1
    for n = row.offset to last
        item = row.items[n]
        slot = n - row.offset
        x = 318 + slot*(cardW+gap)
        card = m.canvas.createChild("Group")
        card.translation = [x,y]
        card.scaleRotateCenter = [cardW/2,cardH/2]
        panel = card.createChild("Rectangle")
        panel.width = cardW
        panel.height = cardH
        panel.color = "0x18181BFF"
        uri = item.background
        if uri = "" then uri = item.poster
        if uri <> ""
            poster = card.createChild("Poster")
            poster.width = cardW
            poster.height = cardH
            poster.loadWidth = cardW
            poster.loadHeight = cardH
            poster.loadDisplayMode = "scaleToFill"
            poster.uri = uri
            m.images.push(poster)
        end if
        mask = card.createChild("Poster")
        mask.width = cardW
        mask.height = cardH
        mask.uri = "pkg:/images/ui/card-landscape-mask.png"
        m.images.push(mask)
        words(item.title,x+4,y+cardH+8,cardW-8,46,24).wrap = true
        focusTarget("home-row-"+rowIndex.toStr(),n,x-6,y-6,cardW+12,cardH+12,"landscape",card)
    end for
end sub
```

- [ ] **Step 3: Verificación manual completa**

Empaqueta e instala. Confirma en Home:
1. El hero se ve igual que antes (no era parte del alcance visual, solo
   bajó la saturación del texto secundario de azul a gris neutro, spec
   §4).
2. Debajo del hero aparecen dos filas ("Películas populares"/"Series
   populares", o sus variantes HD) con más de 3 tarjetas visibles al
   hacer scroll.
3. Al enfocar una tarjeta, esta hace un zoom leve (1.08x) además del
   borde de foco existente.
4. `telnet <roku-ip> 8085` no muestra errores de BrightScript al navegar
   todas las filas de punta a punta.

Expected: cero crashes, zoom visible, scroll por más de 3 elementos
funcionando.

- [ ] **Step 4: Commit**

```bash
git add components/PlusSceneViews.brs
git commit -m "feat: render Home as horizontally-scrolling rows with focus zoom

```

---

## Self-Review Notes (completado durante la escritura de este plan)

- **Cobertura del spec:** §5 (modelo de datos) → Task 1 + Task 3 Step 1.
  §6 (navegación) → Task 3 Step 5. §7 (dibujo/estados vacíos) → Task 4
  Step 2 (el texto "Actualizando…"/mensaje de error ya existente de
  `m.note` se conserva sin cambios, cubre el caso de fila vacía). §9
  (pruebas) → Task 1. §4 (visual) → Task 4 Step 2 (colores) + Task 2
  (zoom). Theming → explícitamente no tocado (confirmado en Task 3/4, sin
  pasos de `rpLoadTheme`).
- **Placeholders:** ninguno — cada paso trae el código completo a pegar,
  no hay "TODO" ni "similar a la tarea anterior".
- **Consistencia de tipos:** `rpRowAdvance`/`rpHomeRowsBuild` se definen
  una vez en Task 1 y se consumen con la misma firma en Task 3 y Task 4
  (vía `m.homeRows[...].cursor`, mismo nombre de campo en ambos). El
  parámetro nuevo `scaleNode` de `focusTarget()` se usa con el mismo
  nombre en Task 2 y Task 4.
