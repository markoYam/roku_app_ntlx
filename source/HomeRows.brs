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
