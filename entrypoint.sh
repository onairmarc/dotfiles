source "$DF_ROOT_DIRECTORY/.autoloader/autoloader.sh"

if [ "$OSTYPE" != "msys" ]; then
  source "$DF_AUTOLOADER_DIRECTORY/mac.sh"
else
  source "$DF_AUTOLOADER_DIRECTORY/windows.sh"
fi