osascript -e 'tell application "OpenVPN Connect" to launch'
sleep 2
osascript -e 'tell application "System Events" to tell process "OpenVPN Connect" to set visible to false'