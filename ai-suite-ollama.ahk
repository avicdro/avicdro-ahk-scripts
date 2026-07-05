#Requires AutoHotkey v2.0
#SingleInstance Force

; ════════════════════════════════════════════════════════════════
;  AI SUITE — Asistente de IA con Ollama
;  ───────────────────────────────────────────────────────────────
;  Tecla base: CapsLock (modificador nativo AHK)
;  Servicio:  Ollama local (http://localhost:11434)
;  Modelo:    Configurable (ver más abajo)
;
;  ATAJOS (todos con CapsLock + tecla):
;    CapsLock + G      → Corregir ortografía (pega el resultado)
;    CapsLock + T      → Traducir (muestra ventana)
;    CapsLock + R      → Resumir (muestra ventana)
;    CapsLock + Enter  → Generar respuesta (muestra ventana)
;    CapsLock + V      → Ver historial de correcciones
;    CapsLock + H      → Mostrar esta ayuda
;
;  DOS MODOS DE FUNCIONAMIENTO:
;    • Corregir (G): reemplaza el texto seleccionado pegando el
;      resultado directamente. Si no hay selección, intenta
;      Ctrl+A (todo el input). Guarda el original en historial.
;    • Traducir/Resumir/Generar (T/R/Enter): muestra el resultado
;      en una ventana sin modificar el texto original. Pensado
;      para leer texto de webs, PDFs, etc.
;
;  CONTEXTO OPCIONAL:
;    Escribe [instrucciones] al inicio del texto seleccionado.
;    Ej: [francés] hola mundo  →  traduce al francés
;    Ej: [5 viñetas] texto...  →  resume en 5 viñetas
;    Ej: [Tono formal] hola... →  corrige con ese tono
;
;  NOTA SOBRE CAPSLOCK:
;    Al definir CapsLock como hotkey, AHK suprime la función nativa
;    de Windows. Las mayúsculas NO se activan al pulsar CapsLock.
; ════════════════════════════════════════════════════════════════


; ─────────────────────────────────────────────────────────────────
;  CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────

; Modelo a usar. Debe aparecer en tu `ollama list`.
global OLLAMA_MODEL := "gemma4:cloud"

; Endpoint local de Ollama (sin API key).
global OLLAMA_ENDPOINT := "http://localhost:11434/api/generate"

; Número máximo de entradas en el historial de correcciones.
global HISTORIAL_MAX := 50

; Tamaño de fuente para las ventanas emergentes (Traducir/Resumir/Generar).
; Si los textos se ven demasiado pequeños, sube este valor.
; Valores típicos: s10 (por defecto), s12, s14, s16...
global GUI_FUENTE_TAMANO := "s16"

; ─────────────────────────────────────────────────────────────────
;  FIN CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────


; ════════════════════════════════════════════════════════════════
;  ESTADO GLOBAL
; ════════════════════════════════════════════════════════════════

; Historial de textos originales (de la función Corregir).
; Cada entrada: { original: "...", corregido: "...", fecha: "..." }
global Historial := []


; ════════════════════════════════════════════════════════════════
;  CAPSLOCK COMO TECLA MODIFICADORA
;  ════════════════════════════════════════════════════════════════
;  Usamos la sintaxis nativa "CapsLock & tecla" de AHK.
;  Al usar CapsLock como modificador con &, AHK suprime
;  automáticamente la función nativa de mayúsculas.
;  La definición "CapsLock::" sola suprime el toggle cuando
;  se pulsa CapsLock sin ninguna otra tecla.
; ════════════════════════════════════════════════════════════════

; CapsLock pulsado solo = no hace nada (suprime mayúsculas)
CapsLock:: return


; ════════════════════════════════════════════════════════════════
;  HOTKEYS DE IA — todos con CapsLock + tecla
; ════════════════════════════════════════════════════════════════

; CapsLock + G → Corregir ortografía (pega el resultado)
CapsLock & g:: CorregirSeleccion()

; CapsLock + T → Traducir
CapsLock & t:: TraducirSeleccion()

; CapsLock + R → Resumir
CapsLock & r:: ResumirSeleccion()

; CapsLock + Enter → Generar respuesta
CapsLock & Enter:: GenerarRespuesta()

; CapsLock + V → Ver historial de correcciones
CapsLock & v:: MostrarHistorial()

; CapsLock + H → Mostrar ayuda
CapsLock & h:: MostrarAyuda()


; ════════════════════════════════════════════════════════════════
;  FUNCIÓN: CORREGIR ORTOGRAFÍA
;  ───────────────────────────────────────────────────────────────
;  Comportamiento distinto al resto: pega el resultado
;  reemplazando la selección. Si no hay selección, intenta
;  Ctrl+A (todo el input). Guarda el original en historial.
; ════════════════════════════════════════════════════════════════

CorregirSeleccion() {
    texto := ObtenerTextoParaCorregir()
    if (texto = "")
        return

    ; Extraer contexto entre corchetes SOLO al inicio
    contexto := ""
    textoLimpio := texto

    if RegExMatch(texto, "^\s*\[([^\]]*)\]", &m) {
        contexto := Trim(m[1])
        textoLimpio := SubStr(texto, m.Len + 1)
        textoLimpio := RegExReplace(textoLimpio, "^\s+", "")
    }

    sysPrompt := "Eres un corrector ortográfico y gramatical experto."
        . " Tu ÚNICA tarea es corregir la ortografía, la gramática y la puntuación del texto que te proporciono."
        . " Mantén SIEMPRE el estilo, el tono, el formato y el idioma original del autor."
        . " Auto-detecta el idioma (principalmente español, pero puede ser cualquier otro)."
        . " NO añadas explicaciones, comentarios, introducciones, despedidas ni markdown."
        . " NO respondas con frases como 'Aquí tienes el texto corregido' ni nada similar."
        . " Devuelve ÚNICAMENTE el texto corregido, sin ningún texto adicional antes o después."
        . " Si el texto ya está correcto, devuélvelo exactamente igual."
        . " Si el texto está vacío o no es texto, devuelve una cadena vacía."

    if (contexto != "")
        sysPrompt .= "`n`nCONTEXTO OBLIGATORIO que debes seguir: " contexto

    etiqueta := "Corrigiendo" . (contexto != "" ? " (con contexto)" : "") . "..."
    MostrarTooltip(etiqueta)

    resultado := LlamarOllama(sysPrompt, textoLimpio)
    OcultarTooltip()

    if (resultado = "")
        return

    ; Guardar en historial antes de modificar el portapapeles
    GuardarEnHistorial(texto, resultado)

    ; Poner el resultado en el portapapeles y pegarlo
    A_Clipboard := resultado
    if !ClipWait(1) {
        MsgBox("Error al preparar el resultado para pegar.", "AI Suite", "Iconx")
        return
    }
    Sleep(50)
    Send "^v"
}


; ════════════════════════════════════════════════════════════════
;  OBTENER TEXTO PARA CORREGIR
;  ───────────────────────────────────────────────────────────────
;  Versión con fallback Ctrl+A para el corrector.
;  Intenta copiar la selección; si no hay, hace Ctrl+A
;  (todo el input). Si es demasiado largo, intenta la
;  última línea con End+Shift+Home.
; ════════════════════════════════════════════════════════════════

ObtenerTextoParaCorregir() {
    oldClip := A_Clipboard
    A_Clipboard := ""

    ; ── Fase 1: intentar copiar selección actual ──
    Send "^c"
    Sleep(150)
    texto := A_Clipboard

    ; ── Fase 2: si no hay texto, intentar Ctrl+A (todo el input) ──
    if (Trim(texto) = "") {
        A_Clipboard := oldClip
        Send "^a"
        Sleep(100)
        A_Clipboard := ""
        Send "^c"
        Sleep(150)
        texto := A_Clipboard

        if (Trim(texto) = "") {
            MostrarTooltip("No hay texto para corregir.")
            A_Clipboard := oldClip
            return ""
        }

        ; Si Ctrl+A seleccionó demasiado, intentar solo la última línea
        if (StrLen(texto) > 3000) {
            A_Clipboard := oldClip
            Send "{End}"
            Sleep(50)
            Send "+{Home}"
            Sleep(100)
            A_Clipboard := ""
            Send "^c"
            Sleep(150)
            texto := A_Clipboard

            if (Trim(texto) = "" || StrLen(texto) > 1000) {
                MostrarTooltip("Texto muy largo. Selecciona manualmente lo que quieres corregir.")
                A_Clipboard := oldClip
                return ""
            }
        }
    }

    A_Clipboard := oldClip
    return texto
}


; ════════════════════════════════════════════════════════════════
;  HISTORIAL (solo para Corregir)
; ════════════════════════════════════════════════════════════════

GuardarEnHistorial(original, corregido) {
    global Historial, HISTORIAL_MAX

    entrada := {
        original: original,
        corregido: corregido,
        fecha: FormatTime(A_Now, "dd/MM HH:mm:ss")
    }

    Historial.InsertAt(1, entrada)

    while (Historial.Length > HISTORIAL_MAX)
        Historial.Pop()
}

MostrarHistorial() {
    global Historial

    if (Historial.Length = 0) {
        MsgBox("El historial está vacío.", "AI Suite — Historial", "Iconi")
        return
    }

    lista := ""
    for i, entrada in Historial {
        preview := entrada.original
        if (StrLen(preview) > 60)
            preview := SubStr(preview, 1, 60) . "..."
        preview := StrReplace(preview, "`n", " ⏎ ")
        preview := StrReplace(preview, "`r", "")

        lista .= "[" . i . "] " . entrada.fecha . " — " . preview . "`n"
    }

    lista .= "`nEscribe el número para copiar el ORIGINAL al portapapeles."
    lista .= "`n(Esc para cancelar)"

    resultado := InputBox(lista, "AI Suite — Historial (" . Historial.Length . " entradas)", "w600 h400")

    if (resultado.Result = "Cancel" || resultado.Value = "")
        return

    try {
        num := Integer(resultado.Value)
    } catch {
        MsgBox("Debes escribir un número.", "AI Suite", "Iconx")
        return
    }

    if (num < 1 || num > Historial.Length) {
        MsgBox("Número fuera de rango.", "AI Suite", "Iconx")
        return
    }

    A_Clipboard := Historial[num].original
    if !ClipWait(1) {
        MsgBox("Error al copiar al portapapeles.", "AI Suite", "Iconx")
        return
    }

    MostrarTooltip("Original #" . num . " copiado al portapapeles.")
    SetTimer(() => OcultarTooltip(), -2000)
}


; ════════════════════════════════════════════════════════════════
;  FUNCIÓN: TRADUCIR
; ════════════════════════════════════════════════════════════════

TraducirSeleccion() {
    texto := ObtenerTextoSeleccionado()
    if (texto = "")
        return

    ; Extraer idioma destino entre corchetes (opcional)
    ; Ejemplo: [francés] hola mundo  →  traduce al francés
    ; Si no hay corchetes, auto-detectar: español → inglés, inglés → español
    idiomaDestino := ""
    textoLimpio := texto

    if RegExMatch(texto, "^\s*\[([^\]]*)\]", &m) {
        idiomaDestino := Trim(m[1])
        textoLimpio := SubStr(texto, m.Len + 1)
        textoLimpio := RegExReplace(textoLimpio, "^\s+", "")
    }

    if (idiomaDestino != "") {
        instruccion := "Traduce el siguiente texto al " . idiomaDestino . "."
    } else {
        instruccion := "Detecta el idioma del texto. Si está en español, tradúcelo al inglés."
            . " Si está en inglés (o cualquier otro idioma), tradúcelo al español."
    }

    sysPrompt := "Eres un traductor profesional."
        . " " . instruccion
        . " Mantén el tono, el formato y el significado original."
        . " NO añadas explicaciones, notas ni comentarios."
        . " Devuelve ÚNICAMENTE la traducción, sin texto adicional."

    MostrarTooltip("Traduciendo" . (idiomaDestino != "" ? " al " . idiomaDestino : "") . "...")

    resultado := LlamarOllama(sysPrompt, textoLimpio)
    OcultarTooltip()

    if (resultado = "")
        return

    titulo := "Traducción" . (idiomaDestino != "" ? " al " . idiomaDestino : "")
    MostrarVentanaResultado(titulo, textoLimpio, resultado)
}


; ════════════════════════════════════════════════════════════════
;  FUNCIÓN: RESUMIR
; ════════════════════════════════════════════════════════════════

ResumirSeleccion() {
    texto := ObtenerTextoSeleccionado()
    if (texto = "")
        return

    ; Extraer formato deseado entre corchetes (opcional)
    ; Ejemplo: [5 viñetas] texto largo...  →  resume en 5 viñetas
    ; Por defecto: 3 viñetas concisas
    formato := ""
    textoLimpio := texto

    if RegExMatch(texto, "^\s*\[([^\]]*)\]", &m) {
        formato := Trim(m[1])
        textoLimpio := SubStr(texto, m.Len + 1)
        textoLimpio := RegExReplace(textoLimpio, "^\s+", "")
    }

    if (formato != "") {
        instruccion := "Resume el siguiente texto en " . formato . "."
    } else {
        instruccion := "Resume el siguiente texto en un máximo de 3 viñetas concisas."
            . " Usa el formato: • viñeta 1`n• viñeta 2`n• viñeta 3"
    }

    sysPrompt := "Eres un experto en síntesis de información."
        . " " . instruccion
        . " Captura las ideas principales y descarta los detalles secundarios."
        . " Mantén el idioma original del texto."
        . " NO añadas introducciones ni conclusiones."
        . " Devuelve ÚNICAMENTE el resumen."

    MostrarTooltip("Resumiendo...")

    resultado := LlamarOllama(sysPrompt, textoLimpio)
    OcultarTooltip()

    if (resultado = "")
        return

    MostrarVentanaResultado("Resumen", textoLimpio, resultado)
}


; ════════════════════════════════════════════════════════════════
;  FUNCIÓN: GENERAR RESPUESTA
; ════════════════════════════════════════════════════════════════

GenerarRespuesta() {
    texto := ObtenerTextoSeleccionado()
    if (texto = "")
        return

    ; El texto seleccionado ES el prompt. Si hay [instrucciones] al
    ; inicio, se usan como contexto del sistema.
    contexto := ""
    prompt := texto

    if RegExMatch(texto, "^\s*\[([^\]]*)\]", &m) {
        contexto := Trim(m[1])
        prompt := SubStr(texto, m.Len + 1)
        prompt := RegExReplace(prompt, "^\s+", "")
    }

    sysPrompt := "Eres un asistente útil y conciso."
        . " Responde al prompt del usuario de forma directa y clara."
        . " Mantén el idioma del prompt."
        . " NO añadas introducciones innecesarias."

    if (contexto != "")
        sysPrompt .= "`n`nCONTEXTO: " contexto

    MostrarTooltip("Generando respuesta...")

    resultado := LlamarOllama(sysPrompt, prompt)
    OcultarTooltip()

    if (resultado = "")
        return

    MostrarVentanaResultado("Respuesta", prompt, resultado)
}


; ════════════════════════════════════════════════════════════════
;  OBTENER TEXTO SELECCIONADO
;  ───────────────────────────────────────────────────────────────
;  Intenta copiar la selección actual. Si no hay selección,
;  avisa al usuario. No intenta Ctrl+A (no queremos seleccionar
;  todo el contenido de una web accidentalmente).
;  Devuelve el texto o "" si no hay nada válido.
; ════════════════════════════════════════════════════════════════

ObtenerTextoSeleccionado() {
    oldClip := A_Clipboard
    A_Clipboard := ""

    Send "^c"
    Sleep(150)
    texto := A_Clipboard

    if (Trim(texto) = "") {
        MostrarTooltip("No hay texto seleccionado.")
        A_Clipboard := oldClip
        return ""
    }

    A_Clipboard := oldClip
    return texto
}


; ════════════════════════════════════════════════════════════════
;  VENTANA DE RESULTADO
;  ───────────────────────────────────────────────────────────────
;  Muestra el resultado en una ventana GUI con:
;    - El texto original (para referencia)
;    - El resultado (seleccionable y copiable)
;    - Botón "Copiar" y botón "Cerrar"
;    - Esc para cerrar
; ════════════════════════════════════════════════════════════════

MostrarVentanaResultado(titulo, textoOriginal, resultado) {
    global GUI_FUENTE_TAMANO
    g := Gui("+AlwaysOnTop +Resize +MinSize800x600", "AI Suite — " . titulo)
    g.SetFont(GUI_FUENTE_TAMANO, "Segoe UI")

    ; ── Panel original ──
    g.AddText("xm cGray vLblOriginal", "Texto original:")
    g.AddEdit("xm w760 h140 ReadOnly vOriginal", textoOriginal)

    ; ── Separador ──
    g.AddText("xm w760 h2 0x10 vSeparador BackgroundCCCCCC")

    ; ── Panel resultado ──
    g.AddText("xm cNavy vLblResultado", "Resultado:")
    editResultado := g.AddEdit("xm w760 h420 vResultado", resultado)

    ; ── Botones ──
    g.AddButton("xm w140 h35 vBtnCopiar", "Copiar").OnEvent("Click", (*) => CopiarResultado(editResultado))
    g.AddButton("x+10 w140 h35 vBtnCerrar", "Cerrar").OnEvent("Click", (*) => g.Destroy())

    ; ── Redimensionado ──
    g.OnEvent("Size", RedimensionarVentanaResultado)

    ; ── Atajo Esc para cerrar ──
    g.OnEvent("Escape", (*) => g.Destroy())

    ; ── Mostrar ──
    g.Show("AutoSize Center")
}

RedimensionarVentanaResultado(guiObj, minMax, width, height) {
    if (minMax = -1)  ; minimizada
        return

    margen := 20
    gap := 12
    altoEtiqueta := 26
    altoOriginal := 140
    altoSeparador := 2
    altoBotones := 35
    ancho := width - (margen * 2)

    ; Calcular alto disponible para el resultado
    altoResultado := height - margen
        - altoEtiqueta - gap - altoOriginal
        - gap - altoSeparador
        - gap - altoEtiqueta - gap
        - altoBotones - margen

    if (altoResultado < 150)
        altoResultado := 150

    y := margen

    ; Etiqueta "Texto original:"
    guiObj["LblOriginal"].Move(margen, y, ancho, altoEtiqueta)
    y += altoEtiqueta + gap

    ; Caja texto original
    guiObj["Original"].Move(margen, y, ancho, altoOriginal)
    y += altoOriginal + gap

    ; Separador
    guiObj["Separador"].Move(margen, y, ancho, altoSeparador)
    y += altoSeparador + gap

    ; Etiqueta "Resultado:"
    guiObj["LblResultado"].Move(margen, y, ancho, altoEtiqueta)
    y += altoEtiqueta + gap

    ; Caja resultado
    guiObj["Resultado"].Move(margen, y, ancho, altoResultado)

    ; Botones abajo centrados
    anchoBotones := 140 * 2 + 10
    xBotones := (width - anchoBotones) // 2
    yBotones := height - altoBotones - margen
    guiObj["BtnCopiar"].Move(xBotones, yBotones, 140, altoBotones)
    guiObj["BtnCerrar"].Move(xBotones + 150, yBotones, 140, altoBotones)
}

CopiarResultado(editCtrl) {
    A_Clipboard := editCtrl.Value
    if !ClipWait(1) {
        MsgBox("Error al copiar.", "AI Suite", "Iconx")
        return
    }
    MostrarTooltip("Resultado copiado al portapapeles.")
    SetTimer(() => OcultarTooltip(), -2000)
}


; ════════════════════════════════════════════════════════════════
;  AYUDA
; ════════════════════════════════════════════════════════════════

MostrarAyuda() {
    ayuda := "AI SUITE — Asistente de IA`n"
        . "═══════════════════════════════════════`n`n"
        . "Selecciona texto en cualquier app y pulsa:`n`n"
        . "CapsLock + G      → Corregir ortografía (pega el resultado)`n"
        . "CapsLock + T      → Traducir (auto o [idioma])`n"
        . "CapsLock + R      → Resumir (o [formato])`n"
        . "CapsLock + Enter  → Generar respuesta`n"
        . "CapsLock + V      → Ver historial de correcciones`n"
        . "CapsLock + H      → Mostrar esta ayuda`n`n"
        . "═══════════════════════════════════════`n`n"
        . "DOS MODOS:`n"
        . "  • Corregir (G): reemplaza el texto pegando el resultado.`n"
        . "    Si no hay selección, intenta Ctrl+A (todo el input).`n"
        . "  • Traducir/Resumir/Generar (T/R/Enter): muestra el`n"
        . "    resultado en una ventana sin modificar el texto.`n"
        . "    Pulsa Copiar o Esc para cerrar.`n`n"
        . "═══════════════════════════════════════`n`n"
        . "CONTEXTO OPCIONAL:`n"
        . "  Escribe [instrucciones] al inicio del texto.`n"
        . "  Ej: [francés] hola mundo`n"
        . "  Ej: [5 viñetas] texto largo...`n`n"
        . "Modelo: " . OLLAMA_MODEL . "`n"
        . "Endpoint: " . OLLAMA_ENDPOINT

    MsgBox(ayuda, "AI Suite — Ayuda", "Iconi")
}


; ════════════════════════════════════════════════════════════════
;  LLAMADA A LA API DE OLLAMA
; ════════════════════════════════════════════════════════════════

LlamarOllama(sysPrompt, userText) {
    global OLLAMA_ENDPOINT, OLLAMA_MODEL

    body := "{"
        . '"model":"' . OLLAMA_MODEL . '",'
        . '"system":"' . EscaparJSON(sysPrompt) . '",'
        . '"prompt":"' . EscaparJSON(userText) . '",'
        . '"stream":false'
        . "}"

    ; Convertir el body a bytes UTF-8 (saltando el BOM)
    stream := ComObject("ADODB.Stream")
    stream.Type := 2
    stream.Charset := "utf-8"
    stream.Open()
    stream.WriteText(body)
    stream.Position := 0
    stream.Type := 1
    if (stream.Size >= 3)
        stream.Position := 3
    bodyBytes := stream.Read()
    stream.Close()

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.SetTimeouts(60000, 60000, 60000, 60000)
    http.Open("POST", OLLAMA_ENDPOINT, false)
    http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")

    try {
        http.Send(bodyBytes)
    } catch as err {
        MsgBox(
            "No se pudo conectar con Ollama.`n`n"
            . "Error: " . err.Message . "`n`n"
            . "Asegúrate de que Ollama está corriendo:`n"
            . "  ollama serve",
            "AI Suite — Error de conexión",
            "Iconx"
        )
        return ""
    }

    if (http.Status != 200) {
        MsgBox(
            "Error HTTP " . http.Status . "`n`n" . http.ResponseText,
            "AI Suite — Error",
            "Iconx"
        )
        return ""
    }

    ; Decodificar la respuesta como UTF-8
    stream := ComObject("ADODB.Stream")
    stream.Type := 1
    stream.Open()
    stream.Write(http.ResponseBody)
    stream.Position := 0
    stream.Type := 2
    stream.Charset := "utf-8"
    responseText := stream.ReadText()
    stream.Close()

    if (SubStr(responseText, 1, 1) = Chr(0xFEFF))
        responseText := SubStr(responseText, 2)

    return ExtraerRespuesta(responseText)
}


; ════════════════════════════════════════════════════════════════
;  UTILIDADES JSON
; ════════════════════════════════════════════════════════════════

EscaparJSON(s) {
    s := StrReplace(s, "\",  "\\")
    s := StrReplace(s, '"',  '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return s
}

DesescaparJSON(s) {
    placeholder := Chr(0)
    dq := Chr(34)

    pos := 1
    while (pos := RegExMatch(s, "\\u([0-9a-fA-F]{4})", &m, pos)) {
        code := Integer("0x" . m[1])
        char := Chr(code)
        s := SubStr(s, 1, m.Pos - 1) . char . SubStr(s, m.Pos + m.Len)
        pos := m.Pos + StrLen(char)
    }

    s := StrReplace(s, "\\", placeholder)
    s := StrReplace(s, "\" . dq, dq)
    s := StrReplace(s, "\n", "`n")
    s := StrReplace(s, "\r", "`r")
    s := StrReplace(s, "\t", "`t")
    s := StrReplace(s, placeholder, "\")

    return s
}

ExtraerRespuesta(jsonRespuesta) {
    if RegExMatch(jsonRespuesta, '"response"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        return DesescaparJSON(m[1])
    }
    MsgBox(
        "No se pudo extraer la respuesta.`n`nRespuesta:`n" . jsonRespuesta,
        "AI Suite — Error de parseo",
        "Iconx"
    )
    return ""
}


; ════════════════════════════════════════════════════════════════
;  UTILIDADES DE UI
; ════════════════════════════════════════════════════════════════

MostrarTooltip(texto) {
    ToolTip(texto)
    SetTimer(() => ToolTip(), -15000)
}

OcultarTooltip() {
    ToolTip()
    SetTimer(() => ToolTip(), -1)
}