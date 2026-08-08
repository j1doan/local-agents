#Requires AutoHotkey v2.0
#SingleInstance Force

; Copilot key = Win + Shift + F23 -> launch llama-server.exe in router mode.
; Suppresses the key events so Windows/Copilot/Start never react.
; If the server is already up on :8080, just open the browser.

*<+<#F23:: {
    if (IsServerUp()) {
        Run 'cmd.exe /c start http://127.0.0.1:8080'
        return
    }
    Run 'cmd.exe /k wsl.exe -i -c "cd /d/llamacpp-bXXXXX/localhost && ./llamacpp.sh"', 'D:\llamacpp-b10250'
    Sleep 10000
    Run 'cmd.exe /c start http://127.0.0.1:8080'
}

IsServerUp() {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "http://127.0.0.1:8080/models", false)
        whr.SetTimeouts(1500, 1500, 1500, 1500)
        whr.Send()
        return whr.Status = 200
    }
    return false
}