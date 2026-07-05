#Requires AutoHotkey v2.0
#SingleInstance Force

; ════════════════════════════════════════════════════════════════
;  CORRECTOR ORTOGRÁFICO Y GRAMATICAL CON IA
;  ───────────────────────────────────────────────────────────────
;  Atajo:    Alt+G
;  Servicio: Ollama local (http://localhost:11434)
;  Modelo:   Configurable (ver más abajo)
;
;  USO:
;    1. Selecciona texto en cualquier aplicación (o deja el cursor
;       en un input/textarea sin seleccionar nada para corregir todo).
;    2. Pulsa Alt+G.
;    3. El texto corregido se pega automáticamente reemplazando la
;       selección (o todo el contenido si no había selección), y se
;       añade al portapapeles como entrada nueva.
;       El texto original se guarda en un historial interno.
;
;  CONTEXTO OPCIONAL:
;    Escribe [instrucciones] al inicio del texto seleccionado.
;    Solo se aplica si está al principio; corchetes en otra
;    posición se ignoran y se mantienen intactos.
;    Ejemplo:  [Tono formal] hola, te escribo por lo del presupuesto...
;
;  HISTORIAL DE PORTAPAPELES:
;    Cada corrección guarda el texto original en un historial.
;    Atajo Ctrl+Win+V muestra el historial para recuperar texto
;    original si lo necesitas.
; ════════════════════════════════════════════════════════════════


; ─────────────────────────────────────────────────────────────────
;  CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────

; Modelo a usar. Debe aparecer en tu `ollama list`.
; Recomendados para corrección de texto:
;   gemma4            — generalista equilibrado (recomendado)
;   qwen3.5           — excelente multilingüe (ideal para español)
;   deepseek-v4-flash — rápido y eficiente
global OLLAMA_MODEL := "gemma4:cloud"

; Endpoint local de Ollama (sin API key).
global OLLAMA_ENDPOINT := "http://localhost:11434/api/generate"

; Número máximo de entradas en el historial de portapapeles.
global HISTORIAL_MAX := 50

; ─────────────────────────────────────────────────────────────────
;  FIN CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────


; ════════════════════════════════════════════════════════════════
;  ESTADO GLOBAL
; ════════════════════════════════════════════════════════════════

; Historial de textos originales (los que seleccionaste antes de corregir).
; Cada entrada: { original: "...", corregido: "...", fecha: "..." }
global Historial := []


; ════════════════════════════════════════════════════════════════
;  HOTKEYS
; ════════════════════════════════════════════════════════════════

; Corregir texto seleccionado
!g:: CorregirSeleccion()

; Mostrar historial de textos originales
^#v:: MostrarHistorial()


; ════════════════════════════════════════════════════════════════
;  LÓGICA PRINCIPAL
; ════════════════════════════════════════════════════════════════

CorregirSeleccion() {
    ; Guardar clipboard original para restaurarlo después
    oldClip := A_Clipboard
    A_Clipboard := ""

    ; ── Fase 1: intentar copiar selección actual ──
    Send "^c"
    Sleep(150)  ; dar tiempo a que la app actualice el clipboard
    texto := A_Clipboard

    ; ── Fase 2: si no hay texto, intentar Ctrl+A (todo el input) ──
    if (Trim(texto) = "") {
        A_Clipboard := oldClip  ; restaurar por si acaso
        Send "^a"
        Sleep(100)
        A_Clipboard := ""
        Send "^c"
        Sleep(150)
        texto := A_Clipboard

        if (Trim(texto) = "") {
            MostrarTooltip("No hay texto para corregir.")
            A_Clipboard := oldClip
            return
        }

        ; Seguridad: si Ctrl+A seleccionó demasiado (ej: todo un panel
        ; de chat), pedir selección manual para evitar corregir el historial
        if (StrLen(texto) > 3000) {
            MostrarTooltip("Texto muy largo. Selecciona manualmente lo que quieres corregir.")
            A_Clipboard := oldClip
            return
        }
    }

    ; Restaurar el portapapeles al texto original inmediatamente
    ; (no queremos perder lo que el usuario tenía copiado antes)
    A_Clipboard := oldClip

    ; Extraer contexto entre corchetes SOLO al inicio
    contexto := ""
    textoLimpio := texto

    if RegExMatch(texto, "^\s*\[([^\]]*)\]", &m) {
        contexto := Trim(m[1])
        textoLimpio := SubStr(texto, m.Len + 1)
        textoLimpio := RegExReplace(textoLimpio, "^\s+", "")
    }

    ; Construir prompt del sistema
    sysPrompt := "Eres un corrector ortográfico y gramatical experto."
        . " Corrige la ortografía, la gramática y la puntuación del texto."
        . " Mantén SIEMPRE el estilo, el tono, el formato y el idioma original."
        . " Auto-detecta el idioma (principalmente español, pero puede ser cualquier otro)."
        . " NO añadas explicaciones, comentarios ni markdown."
        . " Devuelve ÚNICAMENTE el texto corregido, nada más."

    if (contexto != "")
        sysPrompt .= "`n`nCONTEXTO OBLIGATORIO que debes seguir: " contexto

    ; Llamar a la API
    etiqueta := "Corrigiendo" . (contexto != "" ? " (con contexto)" : "") . "..."
    MostrarTooltip(etiqueta)

    resultado := LlamarOllama(sysPrompt, textoLimpio)

    OcultarTooltip()

    if (resultado = "") {
        return
    }

    ; Guardar en historial antes de modificar el portapapeles
    GuardarEnHistorial(texto, resultado)

    ; Poner el resultado en el portapapeles y pegarlo
    A_Clipboard := resultado
    if !ClipWait(1) {
        MsgBox("Error al preparar el resultado para pegar.", "Corrector IA", "Iconx")
        return
    }
    Sleep(50)  ; pequeño delay para que la app receptora esté lista
    Send "^v"

    ; El portapapeles queda con el texto corregido (no se restaura al original)
    ; para que el usuario pueda pegarlo en otro lugar si lo desea.
}


; ════════════════════════════════════════════════════════════════
;  HISTORIAL
; ════════════════════════════════════════════════════════════════

GuardarEnHistorial(original, corregido) {
    global Historial, HISTORIAL_MAX

    entrada := {
        original: original,
        corregido: corregido,
        fecha: FormatTime(A_Now, "dd/MM HH:mm:ss")
    }

    Historial.InsertAt(1, entrada)

    ; Limitar el tamaño del historial
    while (Historial.Length > HISTORIAL_MAX)
        Historial.Pop()
}

MostrarHistorial() {
    global Historial

    if (Historial.Length = 0) {
        MsgBox("El historial está vacío.", "Corrector IA — Historial", "Iconi")
        return
    }

    ; Construir lista numerada con vista previa de cada entrada
    lista := ""
    for i, entrada in Historial {
        ; Vista previa truncada a 60 caracteres
        preview := entrada.original
        if (StrLen(preview) > 60)
            preview := SubStr(preview, 1, 60) . "..."
        ; Limpiar saltos de línea para mostrar en una sola línea
        preview := StrReplace(preview, "`n", " ⏎ ")
        preview := StrReplace(preview, "`r", "")

        lista .= "[" . i . "] " . entrada.fecha . " — " . preview . "`n"
    }

    lista .= "`nEscribe el número para copiar el ORIGINAL al portapapeles."
    lista .= "`n(Esc para cancelar)"

    resultado := InputBox(lista, "Corrector IA — Historial (" . Historial.Length . " entradas)", "w600 h400")

    if (resultado.Result = "Cancel" || resultado.Value = "")
        return

    ; Validar que el input sea un número entero válido
    try {
        num := Integer(resultado.Value)
    } catch {
        MsgBox("Debes escribir un número.", "Corrector IA", "Iconx")
        return
    }

    if (num < 1 || num > Historial.Length) {
        MsgBox("Número fuera de rango.", "Corrector IA", "Iconx")
        return
    }

    A_Clipboard := Historial[num].original
    if !ClipWait(1) {
        MsgBox("Error al copiar al portapapeles.", "Corrector IA", "Iconx")
        return
    }

    MostrarTooltip("Original #" . num . " copiado al portapapeles.")
    SetTimer(() => OcultarTooltip(), -2000)
}


; ════════════════════════════════════════════════════════════════
;  LLAMADA A LA API DE OLLAMA
; ════════════════════════════════════════════════════════════════

LlamarOllama(sysPrompt, userText) {
    global OLLAMA_ENDPOINT, OLLAMA_MODEL

    ; /api/generate soporta "system" y "prompt" por separado.
    body := "{"
        . '"model":"' . OLLAMA_MODEL . '",'
        . '"system":"' . EscaparJSON(sysPrompt) . '",'
        . '"prompt":"' . EscaparJSON(userText) . '",'
        . '"stream":false'
        . "}"

    ; Convertir el body a bytes UTF-8 (para que los acentos se envíen bien)
    ; ADODB.Stream añade un BOM de 3 bytes al inicio; hay que saltarlo.
    stream := ComObject("ADODB.Stream")
    stream.Type := 2          ; adTypeText
    stream.Charset := "utf-8"
    stream.Open()
    stream.WriteText(body)
    stream.Position := 0
    stream.Type := 1          ; adTypeBinary
    if (stream.Size >= 3)
        stream.Position := 3  ; saltar BOM UTF-8 (EF BB BF)
    bodyBytes := stream.Read()
    stream.Close()

    http := ComObject("WinHttp.WinHttpRequest.5.1")
    ; Aumentar timeouts: 60s para resolver, conectar, enviar y recibir
    ; (por defecto WinHttp usa 30s, que puede ser corto al cargar el modelo)
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
            "Corrector IA — Error de conexión",
            "Iconx"
        )
        return ""
    }

    if (http.Status != 200) {
        MsgBox(
            "Error HTTP " . http.Status . "`n`n" . http.ResponseText,
            "Corrector IA — Error",
            "Iconx"
        )
        return ""
    }

    ; Decodificar la respuesta como UTF-8 (WinHttp por defecto usa Windows-1252)
    stream := ComObject("ADODB.Stream")
    stream.Type := 1          ; adTypeBinary
    stream.Open()
    stream.Write(http.ResponseBody)
    stream.Position := 0
    stream.Type := 2          ; adTypeText
    stream.Charset := "utf-8"
    responseText := stream.ReadText()
    stream.Close()

    ; Eliminar BOM UTF-8 si está presente al inicio de la respuesta
    if (SubStr(responseText, 1, 1) = Chr(0xFEFF))
        responseText := SubStr(responseText, 2)

    return ExtraerRespuesta(responseText)
}


; ════════════════════════════════════════════════════════════════
;  UTILIDADES JSON
; ════════════════════════════════════════════════════════════════

EscaparJSON(s) {
    ; El orden importa: escapar la barra invertida PRIMERO,
    ; antes que las demás secuencias, para no doble-escapar.
    s := StrReplace(s, "\",  "\\")
    s := StrReplace(s, '"',  '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return s
}

DesescaparJSON(s) {
    ; El orden importa: primero decodificar \uXXXX (Unicode), luego \\ por un
    ; placeholder, luego las demás secuencias, y finalmente el placeholder.
    ; Esto evita que \\n se convierta en \ + newline en lugar de \n literal.
    placeholder := Chr(0)  ; carácter nulo como marcador temporal
    dq := Chr(34)           ; comilla doble "

    ; Decodificar escapes Unicode \uXXXX → carácter real (bucle manual compatible)
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
    ; /api/generate con stream:false devuelve:
    ; {"model":"...","response":"...texto...","done":true,...}
    ; El regex captura el valor de "response" respetando secuencias escapadas.
    if RegExMatch(jsonRespuesta, '"response"\s*:\s*"((?:[^"\\]|\\.)*)"', &m) {
        return DesescaparJSON(m[1])
    }
    MsgBox(
        "No se pudo extraer el texto corregido.`n`nRespuesta:`n" . jsonRespuesta,
        "Corrector IA — Error de parseo",
        "Iconx"
    )
    return ""
}


; ════════════════════════════════════════════════════════════════
;  UTILIDADES DE UI
; ════════════════════════════════════════════════════════════════

MostrarTooltip(texto) {
    ToolTip(texto)
    SetTimer(() => ToolTip(), -15000)  ; ocultar tras 15 s por seguridad
}

OcultarTooltip() {
    ToolTip()
    SetTimer(() => ToolTip(), -1)  ; cancelar el timer de seguridad
}
