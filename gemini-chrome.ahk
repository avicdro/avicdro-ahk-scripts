#Requires AutoHotkey v2.0
#SingleInstance Force

; ════════════════════════════════════════════════════════════════
;  GEMINI QUICK OPEN
;  ───────────────────────────────────────────────────────────────
;  Tecla base: CapsLock (modificador nativo AHK)
;  Objetivo:   Abrir una ventana nueva de Gemini en Chrome
;
;  ATAJOS:
;    CapsLock + N  → Abrir https://gemini.google.com/app en una
;                    ventana nueva de Chrome (no pestaña)
;    CapsLock + E  → Abrir Gemini en una pestaña nueva de la
;                    ventana de Chrome que ya tengas abierta
;
;  Ambos atajos enfocan la ventana de Chrome al frente.
;
;  NOTA SOBRE CAPSLOCK:
;    Al definir CapsLock como hotkey, AHK suprime la función nativa
;    de Windows. Las mayúsculas NO se activan al pulsar CapsLock.
; ════════════════════════════════════════════════════════════════


; ─────────────────────────────────────────────────────────────────
;  CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────

; URL de Gemini
global GEMINI_URL := "https://gemini.google.com/app"

; Ruta al ejecutable de Chrome.
; Si Chrome no está en el PATH, pon la ruta completa, por ejemplo:
;   global CHROME_PATH := "C:\Program Files\Google\Chrome\Application\chrome.exe"
global CHROME_PATH := "chrome.exe"

; ─────────────────────────────────────────────────────────────────
;  FIN CONFIGURACIÓN
; ─────────────────────────────────────────────────────────────────


; ════════════════════════════════════════════════════════════════
;  CAPSLOCK COMO TECLA MODIFICADORA
; ════════════════════════════════════════════════════════════════

; CapsLock pulsado solo = no hace nada (suprime mayúsculas)
CapsLock:: return


; ════════════════════════════════════════════════════════════════
;  HOTKEYS
; ════════════════════════════════════════════════════════════════

; CapsLock + N → Abrir Gemini en ventana nueva de Chrome
CapsLock & n:: AbrirGeminiVentanaNueva()

; CapsLock + E → Abrir Gemini en pestaña nueva de Chrome
CapsLock & e:: AbrirGeminiPestanaNueva()


; ════════════════════════════════════════════════════════════════
;  FUNCIONES
; ════════════════════════════════════════════════════════════════

; Abrir Gemini en una ventana NUEVA de Chrome.
; Usa el flag --new-window para forzar una ventana independiente.
AbrirGeminiVentanaNueva() {
    MostrarTooltip("Abriendo Gemini (ventana nueva)...")

    try {
        Run(CHROME_PATH " --new-window " GEMINI_URL)
    } catch {
        MsgBox("No se pudo abrir Chrome.`n`nRevisa CHROME_PATH en la configuración.",
               "Gemini Quick Open", "Iconx")
        OcultarTooltip()
        return
    }

    EnfocarChrome(true)
    OcultarTooltip()
}

; Abrir Gemini en una pestaña nueva de la ventana de Chrome
; que ya tengas abierta. Si no hay ninguna ventana de Chrome,
; se abre una nueva automáticamente.
AbrirGeminiPestanaNueva() {
    MostrarTooltip("Abriendo Gemini (pestaña nueva)...")

    try {
        Run(CHROME_PATH " " GEMINI_URL)
    } catch {
        MsgBox("No se pudo abrir Chrome.`n`nRevisa CHROME_PATH en la configuración.",
               "Gemini Quick Open", "Iconx")
        OcultarTooltip()
        return
    }

    EnfocarChrome(false)
    OcultarTooltip()
}

; ─────────────────────────────────────────────────────────────────
;  HELPERS
; ─────────────────────────────────────────────────────────────────

; Traer Chrome al frente.
;   nuevaVentana=true  → espera a que aparezca una ventana NUEVA
;                         (comparando las que ya existían antes).
;   nuevaVentana=false → activa la ventana de Chrome que ya existe.
EnfocarChrome(nuevaVentana := false) {
    if nuevaVentana {
        ; Capturar las ventanas de Chrome que ya existen
        previas := Map()
        for hwnd in WinGetList("ahk_class Chrome_WidgetWin_1")
            previas[hwnd] := true

        ; Esperar hasta 5 s (50 × 100 ms) a que aparezca una nueva
        hwndNuevo := 0
        Loop 50 {
            Sleep(100)
            for hwnd in WinGetList("ahk_class Chrome_WidgetWin_1") {
                if !previas.Has(hwnd) {
                    hwndNuevo := hwnd
                    break
                }
            }
            if hwndNuevo
                break
        }

        if hwndNuevo {
            ActivarVentana(hwndNuevo)
            return
        }
    }

    ; Fallback / pestaña nueva: activar la última ventana de Chrome
    WinWait("ahk_class Chrome_WidgetWin_1", , 5)
    hwnd := WinExist("ahk_class Chrome_WidgetWin_1")
    if hwnd
        ActivarVentana(hwnd)
}

; Activar una ventana y traerla al frente de forma robusta.
; Windows bloquea SetForegroundWindow si el script no es la ventana
; activa, así que usamos AttachThreadInput como truco para forzarlo.
ActivarVentana(hwnd) {
    ; Restaurar si está minimizada
    if WinGetMinMax("ahk_id " hwnd) = -1
        WinRestore("ahk_id " hwnd)

    ; Intentar activación normal primero
    WinActivate("ahk_id " hwnd)
    Sleep(150)

    if WinActive("ahk_id " hwnd)
        return

    ; Si no se activó, forzar con AttachThreadInput.
    ; Este truco "engaña" a Windows para que permita el cambio
    ; de foreground desde un script.
    fgHwnd := DllCall("GetForegroundWindow", "ptr")
    fgThread := DllCall("GetWindowThreadProcessId", "ptr", fgHwnd, "ptr", 0, "uint")
    myThread := DllCall("GetCurrentThreadId", "uint")

    DllCall("AttachThreadInput", "uint", fgThread, "uint", myThread, "int", 1)
    DllCall("SetForegroundWindow", "ptr", hwnd)
    DllCall("AttachThreadInput", "uint", fgThread, "uint", myThread, "int", 0)
    DllCall("BringWindowToTop", "ptr", hwnd)

    WinActivate("ahk_id " hwnd)
    WinWaitActive("ahk_id " hwnd, , 2)
}

MostrarTooltip(texto) {
    ToolTip(texto)
    SetTimer(() => OcultarTooltip(), -2000)
}

OcultarTooltip() {
    ToolTip()
}