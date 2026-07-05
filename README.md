# avicdro-ahk-scripts

Colección personal de scripts de **AutoHotkey v2** para automatizar tareas del día a día en Windows. Cada script resuelve un problema concreto de forma simple y directa.

> ⚡ Filosofía: scripts pequeños, útiles y sin dependencias externas (salvo las que ya tengas corriendo localmente).

---

## 📑 Índice

| # | Script | Descripción | Atajos |
|---|--------|-------------|--------|
| 1 | [ai-suite-ollama.ahk](ai-suite-ollama.ahk) | Suite de IA con Ollama: corregir, traducir, resumir y generar respuestas | `CapsLock+G/T/R/Enter/V/H` |

---

## 🚀 Cómo usar

1. Instala [AutoHotkey v2](https://www.autohotkey.com/).
2. Descarga el script que te interese.
3. Haz doble clic para ejecutarlo (aparecerá un icono en la bandeja del sistema).
4. Selecciona texto en cualquier aplicación y pulsa el atajo correspondiente.

---

## ⌨️ Atajos — ai-suite-ollama.ahk

Todos los atajos usan **CapsLock** como tecla modificadora (las mayúsculas quedan desactivadas automáticamente):

| Atajo | Función | Comportamiento |
|-------|---------|---------------|
| `CapsLock + G` | Corregir ortografía | Pega el resultado reemplazando el texto |
| `CapsLock + T` | Traducir | Muestra ventana con la traducción |
| `CapsLock + R` | Resumir | Muestra ventana con el resumen |
| `CapsLock + Enter` | Generar respuesta | Muestra ventana con la respuesta |
| `CapsLock + V` | Ver historial | Recupera textos originales de correcciones |
| `CapsLock + H` | Ayuda | Muestra todos los atajos |

### Contexto opcional

Escribe `[instrucciones]` al inicio del texto seleccionado:

- `[francés] hola mundo` → traduce al francés
- `[5 viñetas] texto largo...` → resume en 5 viñetas
- `[Tono formal] hola, te escribo...` → corrige con ese tono

---

## 🛠️ Requisitos por script

### ai-suite-ollama.ahk
- [Ollama](https://ollama.com/) corriendo en local (`ollama serve`)
- Al menos un modelo descargado (recomendado: `gemma4`, `qwen3.5` o `deepseek-v4-flash`)

---

## 📜 Licencia

[MIT](LICENSE)
