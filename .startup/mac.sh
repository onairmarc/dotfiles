osascript -e 'tell application "OpenVPN Connect" to launch'
sleep 2
osascript -e '
tell application "System Events"
    tell process "OpenVPN Connect"
        set closeButton to (first button of window 1 whose subrole is "AXCloseButton")
        set {x, y} to position of closeButton
        set {w, h} to size of closeButton
    end tell
end tell
set clickX to (x + (w / 2)) as integer
set clickY to (y + (h / 2)) as integer
do shell script "cliclick c:" & clickX & "," & clickY & " w:100"'